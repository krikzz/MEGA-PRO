
`include "defs.v"

module sst_controller(
	
	input clk,
	input sms_mode,
	input [`BW_MAP_IN-1:0]mapin,
	output [7:0]pi_din,
	output sst_act_smd,
	output sst_act_sms
);
	
	`include "map_in.v"
	
	assign pi_din[7:0] = sms_mode ? pi_din_sms : pi_din_smd;
	
	wire [7:0]pi_din_smd, pi_din_sms;

`ifdef CFG_SST_SMD	
	
	sst_controller_smd sst_inst_smd(
		.clk(clk),
		.on(sms_mode == 0),
		.mapin(mapin),
		.pi_din(pi_din_smd),
		.sst_act_out(sst_act_smd)
	);

`endif
	
`ifdef CFG_SST_SMS	

	sst_controller_sms sst_inst_sms(
		.clk(clk),
		.on(sms_mode == 1),
		.mapin(mapin),
		.pi_din(pi_din_sms),
		.sst_act_out(sst_act_sms)
	);
	
`endif	

endmodule

//***************************************************************************** smd controller

module sst_controller_smd(
	
	input clk,
	input on,
	input [`BW_MAP_IN-1:0]mapin,
	output [7:0]pi_din,
	output sst_act_out
);

	`include "sys_cfg.v"
	`include "map_in.v"
	`include "mdbus.v"
	`include "pi_bus.v"
	
	parameter SS_INGAME = 0;
	parameter SS_BACKUP = 1;
	parameter SS_RECOVR = 2;
	
	assign sst_act_out = ss_state != 0;
	assign pi_din[7:0] = 
	pi_addr[7:6] == 0 ? vdp_val[7:0] : 
	pi_addr[7:0] == 8'h7f ? joy_keys[7:0] :
	8'hff;
	
	
	wire joy_act = joy_val != 0 & (joy_val == ss_key_save | joy_val == ss_key_load | joy_val == ss_key_menu);
	wire irq_act = !as & !oe & cpu_addr[23:0] == 24'h78;
	wire sst_req = joy_act & irq_act & !joy_lock;
	wire sst_ack = ss_state == SS_BACKUP & !we_lo & !we_hi & cpu_addr == 0;
	
	reg ss_ack, joy_lock;
	reg [1:0]ss_state;
	reg [7:0]joy_keys;
	
	always @(negedge clk)
	if(map_rst | sys_rst | !ctrl_ss_on | !on)
	begin
		ss_state <= SS_INGAME;
	end
		else
	begin
		
		if(ss_state == SS_INGAME & joy_act == 0)joy_lock <= 0;
		
		if(ss_state == SS_INGAME & sst_req)
		begin
			joy_keys <= joy_val;
			joy_lock <= 1;//prevent quick save/load looping
		end
		
		if(ss_state == SS_INGAME & sst_req)ss_state <= SS_BACKUP;
		if(ss_state == SS_BACKUP & sst_ack)ss_state <= SS_RECOVR;
		if(ss_state == SS_RECOVR & irq_act)ss_state <= SS_INGAME;
		
	end
	
	wire [7:0]joy_val;
	joy_sniff_smd joy_sniff(
		.clk(clk),
		.mapin(mapin),
		.joy_port(0),
		.joy_val(joy_val)
	);
	
	wire [7:0]vdp_val;
	vdp_sniff_smd(
		.clk(clk),
		.mapin(mapin),
		.sniff_on(ss_state != SS_BACKUP), 
		.reg_addr(pi_addr[5:0]),
		.reg_val(vdp_val)
	);
		
endmodule


module vdp_sniff_smd(

	input clk,
	input [`BW_MAP_IN-1:0]mapin,
	input sniff_on, 
	input [5:0]reg_addr,
	output [7:0]reg_val
);

	`include "map_in.v"
	`include "mdbus.v"
	
	assign reg_val[7:0] = reg_addr[0] == 0 ? vdp_rd_data[15:8] : vdp_rd_data[7:0];
	
	
	wire vdp_reg_ce = cpu_addr[23:0] == 24'hC00004 & cpu_data[15:13] == 3'b100 &  !as;
	wire vdp_reg_we = vdp_reg_ce & (!we_lo | !we_hi) & sniff_on;//ss_state != SS_BACKUP;
	
	wire [15:0]vdp_rd_data;
	wire [4:0]vdp_rd_addr = reg_addr[5:1];
	
	wire [15:0]vdp_wr_data = map_rst ? 0 : cpu_data[15:0];
	wire [4:0]vdp_wr_addr = map_rst ? addr_ctr : cpu_data[12:8];
	wire vdp_wr = map_rst ? 1 : vdp_reg_we_edge;
	
	/*
	ram_dp16 ram_inst(
		.din(vdp_wr_data),
		.dout(vdp_rd_data),
		.we(vdp_wr), 
		.clk(clk),
		.addr_w(vdp_wr_addr),
		.addr_r(vdp_rd_addr)
	);*/
	
	ram_dp16 ram_inst(
	
		.din_a(vdp_wr_data), 
		.addr_a(vdp_wr_addr), 
		.we_a(vdp_wr), 
		.clk_a(clk), 
		
		.addr_b(vdp_rd_addr), 
		.dout_b(vdp_rd_data), 
		.clk_b(clk)
	);
	
	reg [5:0]addr_ctr;
	always @(negedge clk)addr_ctr <= addr_ctr + 1;
	
	
	wire vdp_reg_we_edge;
	sync_edge eep_sync(.clk(clk), .ce(vdp_reg_we), .sync(vdp_reg_we_edge));
	
endmodule



module joy_sniff_smd(

	input clk,
	input [`BW_MAP_IN-1:0]mapin,
	input joy_port,
	output reg [7:0]joy_val
);

	`include "map_in.v"
	`include "mdbus.v"
	
	wire joy_ce = !as & cpu_addr == 24'hA10002;
	wire joy_we = joy_ce & !we_lo;
	wire joy_oe = joy_ce & !oe;
	wire sel_edge = sel != sel_st;
	wire oe_edge  = joy_oe != joy_oe_st;
	wire irq_act = !as & !oe & cpu_addr[23:0] == 24'h78;
	
	reg cpu_oe_st;
	reg joy_oe_st;
	reg sel, sel_st;
	reg [7:0]dat_st;
	reg [7:0]delay;
	reg [1:0]oe_latch;
	
	always @(negedge clk)
	begin
		
		joy_oe_st <= joy_oe;
		sel_st <= sel;
		cpu_oe_st <= oe;
						
		
		if(we_edge)sel <= cpu_data[6];
		if(joy_oe)dat_st[7:0] <= cpu_data[7:0] ^ 8'hff;
		
		if(irq_act)oe_latch <= 0;
			else
		if(oe_edge & joy_oe == 0 & oe_latch != 2'b11)
		begin
		
			if(sel == 1)joy_val[5:0] <= dat_st[5:0];
				else
			if(sel == 0)joy_val[7:6] <= dat_st[5:4];
			
			oe_latch[sel] <= 1;
				
		end
		
	end
	
	
	
	wire we_edge;
	sync_edge eep_sync(.clk(clk), .ce(joy_we), .sync(we_edge));
	
endmodule 

//***************************************************************************** sms controller
//*****************************************************************************
//*****************************************************************************
//*****************************************************************************

module sst_controller_sms(
	
	input clk,
	input on,
	input [`BW_MAP_IN-1:0]mapin,
	output [7:0]pi_din,
	output sst_act_out
);
	
	`include "sys_cfg.v"
	`include "map_in.v"
	`include "mdbus.v"
	`include "pi_bus.v"
	
	parameter SS_INGAME = 0;
	parameter SS_BACKUP = 1;
	parameter SS_RECOVR = 2;
	
	assign sst_act_out = ss_state != 0;
	assign pi_din[7:0] = vdp_val[7:0];
	
	wire [15:0]sms_addr = cpu_addr[16:1];
	wire sms_ce = !cpu_addr[18];
	wire irq_oe = sms_ce & !oe & sms_addr == 16'h0038;
	
	wire joy_act = joy_val != 0 & joy_val == ss_key_menu;
	wire irq_act = irq_oe_st[3:0] == 4'b0111;//sms_ce & !oe & sms_addr == 16'h0038;
	wire sst_req = joy_act & irq_act;
	wire sst_ack = ss_state == SS_BACKUP & we_sync & sms_addr == 16'h008F & cpu_data[7:0] == 0;
	
	reg ss_ack;
	reg [1:0]ss_state;
	
	always @(negedge clk)
	if(map_rst | sys_rst | !ctrl_ss_on | !on)
	begin
		ss_state <= SS_INGAME;
	end
		else
	begin
		
		if(ss_state == SS_INGAME & sst_req)ss_state <= SS_BACKUP;
		if(ss_state == SS_BACKUP & sst_ack)ss_state <= SS_RECOVR;
		if(ss_state == SS_RECOVR & irq_act)ss_state <= SS_INGAME;
		
	end
	
	
	reg [7:0]irq_oe_st;
	always @(negedge clk)
	begin
		irq_oe_st[7:0] <= {irq_oe_st[6:0], irq_oe};
	end
	
	wire [7:0]joy_val;
	joy_sniff_sms joy_sniff(
		.clk(clk),
		.mapin(mapin),
		.joy_port(0),
		.joy_val(joy_val)
	);
	
	wire [7:0]vdp_val;
	vdp_sniff_sms(
		.clk(clk),
		.mapin(mapin),
		.sniff_on(ss_state != SS_BACKUP), 
		.reg_addr(pi_addr[6:0]),
		.reg_val(vdp_val)
	);
	
	wire we_sync;
	sync_edge sync_inst(
		.clk(clk),
		.ce(!we_lo & sms_ce),
		.sync(we_sync)
	);
	
endmodule



module joy_sniff_sms(
	input clk,
	input [`BW_MAP_IN-1:0]mapin,
	input joy_port,
	output reg [7:0]joy_val
);

	`include "map_in.v"
	`include "mdbus.v"
	`include "sys_cfg.v"
	
	wire [15:0]sms_addr = cpu_addr[16:1];
	wire io_ce = !cpu_addr[19];
	//wire joy_ce = io_ce & sms_addr[7:0] == 8'hDC;//fix me. mirroring req
	wire joy_ce = io_ce & sms_addr[7:6] == 2'b11 & sms_addr[0] == 0;
	wire joy_oe = joy_ce & !oe;
	wire joy_oe_edge = joy_oe_st[2:0] == (mcfg_ms_msg ? 3'b011 : 3'b100);
	
	reg[3:0]joy_oe_st;
	
	always @(negedge clk)
	begin
	
		joy_oe_st[3:0] <= {joy_oe_st[2:0], joy_oe};
		//if(joy_oe_st[2:0] == 3'b100)joy_val[7:0] <= {2'b11, cpu_data[5:0]} ^ 8'hff;
		if(joy_oe_edge)joy_val[7:0] <= {2'b11, cpu_data[5:0]} ^ 8'hff;
		
	end
	
	
endmodule 


module vdp_sniff_sms(

	input clk,
	input [`BW_MAP_IN-1:0]mapin,
	input sniff_on, 
	input [6:0]reg_addr,
	output [7:0]reg_val
);

	`include "map_in.v"
	`include "mdbus.v"
	
	assign reg_val[7:0] = reg_addr < 80 ? vdp_rd_data[7:0] : 8'hff;
	
	wire [15:0]sms_addr = cpu_addr[16:1];
	
	wire io_ce = !cpu_addr[19];
	wire io_oe = io_ce & !oe;
	wire io_we = io_ce & !we_lo;
	wire dat_ce = sms_addr[7:6] == 2'b10 & sms_addr[0] == 0 & (io_oe | io_we);
	wire cnt_ce = sms_addr[7:6] == 2'b10 & sms_addr[0] == 1 & (io_oe | io_we);
	wire io_we_sync = io_we_st[3:0] == 4'b0111;
	
		
	reg cnt_sync;
	reg [7:0]vdp_cnt;
	reg [5:0]vdp_addr;
	reg pal_we_on;
	reg vdp_reg_we;
	reg addr_inc;
	reg [3:0]io_we_st;
	
	always @(negedge clk)
	begin
	
		io_we_st[3:0] <= {io_we_st[2:0], io_we};
	
		if(vdp_reg_we)vdp_reg_we <= 0;
		addr_inc <= io_we_sync & dat_ce;
		if(addr_inc)vdp_addr <= vdp_addr + 1;
	
		if(dat_ce)cnt_sync <= 0;
		if(cnt_ce & io_oe)cnt_sync <= 0;
		if(cnt_ce & io_we_sync)cnt_sync <= !cnt_sync;
		
		if(cnt_ce & io_we_sync & cnt_sync == 0)
		begin
			vdp_cnt[7:0] <= cpu_data[7:0];
		end
			else
		if(cnt_ce & io_we_sync & cnt_sync == 1)
		begin
			pal_we_on  <= cpu_data[7:6] == 2'b11;
			vdp_reg_we <= cpu_data[7:6] == 2'b10;
			vdp_addr[5:0] <= vdp_cnt[5:0];
		end

	end
	
	wire dat_we = dat_ce & io_we_sync;
	
	wire [7:0]vdp_rd_data;
	wire [6:0]vdp_rd_addr = reg_addr[6:0];
	
	wire [7:0]vdp_wr_data = map_rst ? 0 : pal_we_on ? cpu_data[7:0] : vdp_cnt[7:0];
	wire [6:0]vdp_wr_addr = map_rst ? addr_ctr : pal_we_on ? {1'b0, vdp_addr[5:0]} : {3'b100, cpu_data[3:0]};
	wire vdp_wr = map_rst ? 1 : (pal_we_on ? dat_we : vdp_reg_we) & sniff_on;
	

	ram_dp8 ram_inst(
	
		.din_a(vdp_wr_data), 
		.addr_a(vdp_wr_addr), 
		.we_a(vdp_wr), 
		.clk_a(clk), 
		
		.addr_b(vdp_rd_addr), 
		.dout_b(vdp_rd_data), 
		.clk_b(clk)
	);
	
	reg [6:0]addr_ctr;
	always @(negedge clk)addr_ctr <= addr_ctr + 1;
	
endmodule

//*******************************************************************************************************************
//*******************************************************************************************************************
//*******************************************************************************************************************
//*******************************************************************************************************************


module map_sys_sms(

	output [`BW_MAP_OUT-1:0]mapout,
	input [`BW_MAP_IN-1:0]mapin,
	input clk
);
	
	`include "mapio.v"
	`include "sys_cfg.v"

	//assign mcu_mode = sst_act;
	assign dtack = 1;
	assign mask_off = 1;
	assign sms_mode = 1;
	assign led_r = sst_act;
//*************************************************************************************
	assign map_oe = (rom_area | ram_area | slot_area) & !oe;
	assign map_do[15:0] = 
	!sms_addr[0] ? {mem_out[15:8], mem_out[15:8]} : 
						{mem_out[7:0],  mem_out[7:0]};
	
	wire [15:0]mem_out = 
	slot_area ? {slot[7:0], slot[7:0]} : 
	rom_area | ram_bank[4] == 0 ? mem_do[`ROM1] : 
	mem_do[`BRAM];
	
	assign mem_oe[`ROM1] = (rom_area | ram_area) & !oe;
	assign mem_we_hi[`ROM1] = ram_area & !we_lo & sms_addr[0] == 0 & ram_bank[4] == 0;
	assign mem_we_lo[`ROM1] = ram_area & !we_lo & sms_addr[0] == 1 & ram_bank[4] == 0;
	assign mem_addr[`ROM1][22:0] = rom_area ? rom_addr : ram_addr;
	assign mem_di[`ROM1][15:0] = {cpu_data[7:0], cpu_data[7:0]};
	
	assign mem_oe[`BRAM] = ram_area & !oe;
	assign mem_we_hi[`BRAM] = ram_area & !we_lo & sms_addr[0] == 0 & ram_bank[4] == 1;
	assign mem_we_lo[`BRAM] = ram_area & !we_lo & sms_addr[0] == 1 & ram_bank[4] == 1;
	assign mem_addr[`BRAM][22:0] = ram_addr;
	assign mem_di[`BRAM][15:0] = {cpu_data[7:0], cpu_data[7:0]};

	
	wire [15:0]sms_addr = cpu_addr[16:1];
	wire sms_ce = !cpu_addr[18];
	wire rom_area = sms_ce & sms_addr[15] == 0;
	wire ram_area = sms_ce & {sms_addr[15:14], 14'd0} == 16'h8000;
	wire slot_area = sms_ce & sms_addr[15:0] == 16'h0090;
	
	wire [22:0]rom_addr = {4'hF, 5'b01111, sms_addr[13:0]};//last 16K in OS core
	wire [22:0]ram_addr = {4'hE, 3'b000, ram_bank[2:0], sms_addr[12:0]};
	wire [4:0]ram_bank = sms_addr[13] == 0 ? bank_reg[0] : bank_reg[1];
	reg [4:0]bank_reg[2];
	reg [7:0]slot;
	
	always @(negedge clk)
	if(map_rst)
	begin
		slot <= 0;
	end
		else
	if(we_sync)
	begin
		if(slot_area)slot[7:0] <= cpu_data[7:0];
		if(sms_addr[15:0] == 16'h0088)bank_reg[0][4:0] <= cpu_data[4:0];
		if(sms_addr[15:0] == 16'h0089)bank_reg[1][4:0] <= cpu_data[4:0];
		if(sms_addr[15:0] == 16'h008A)
		begin
			if(cpu_data[0])bank_reg[0][2:0] <= bank_reg[0][2:0] + 1;
			if(cpu_data[1])bank_reg[1][2:0] <= bank_reg[1][2:0] + 1;
		end
	end
	
	wire we_sync;
	sync_edge sync_inst(
		.clk(clk),
		.ce(!we_lo & sms_ce),
		.sync(we_sync)
	);
	

endmodule

