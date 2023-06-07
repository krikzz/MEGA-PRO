
`include "defs.v"

module base_io(
	input clk,
	input [`BW_PI_BUS-1:0]pi_bus,
	output [`BW_SYS_CFG-1:0]sys_cfg,
	output [7:0]pi_din,
	input [`BW_MDBUS-1:0]mdbus,
	output [15:0]base_io_do,
	output base_io_oe,
	input mcu_busy,
	input sms_mode,
	output pi_fifo_rxf
);

	`include "pi_bus.v"
	`include "mdbus.v"
	`include "sys_cfg.v"

	assign pi_din[7:0] = 
	pi_ce_cfg ? scfg[pi_addr[2:0]][7:0] :
	pi_ce_fifo ? fifo_do_b[7:0] : 
	8'hff;

//****************************************************************************************************************** cpu regs
	wire cpu_ce_baio_smd = !tim & {cpu_addr[7:4], 4'd0} == 8'hD0 & !sys_rst;
	wire [3:0]io_addr_smd = {cpu_addr[3:1], 1'b0};
	wire [15:0]base_io_do_smd = regs_st[15:0];
	
	wire cpu_ce_baio_sms = !cpu_addr[18] & {cpu_addr[16:5], 4'd0} == 16'h0080 & sms_unlock;
	wire [3:0]io_addr_sms = {cpu_addr[4:2], 1'b0};
	wire [15:0]base_io_do_sms = cpu_addr[1] == 1 ? regs_st[15:8] : regs_st[7:0];
//*****
	assign base_io_oe = cpu_ce_baio & !oe;

	assign base_io_do[15:0] = sms_mode ? base_io_do_sms : base_io_do_smd;
	wire [3:0]io_addr = sms_mode ? io_addr_sms : io_addr_smd;	
	wire cpu_ce_baio = sms_mode ? cpu_ce_baio_sms : cpu_ce_baio_smd;
	
	wire [15:0]status = {8'h55, 4'hA, strobe, fpg_busy_flag, mcu_busy_flag, !ctrl_gmode};
//*****

	wire cpu_ce_fifo_data = io_addr == 4'h0;
	wire cpu_ce_fifo_stat = io_addr == 4'h2;
	wire cpu_ce_sys_stat  = io_addr == 4'h4;
	wire cpu_ce_timer     = io_addr == 4'h6;

	wire tick_1ms = timer_1ms == 16'd49999;

	reg strobe;
	reg [15:0]timer_1ms;
	reg [15:0]timer;
	reg mcu_busy_flag, fpg_busy_flag;//mcu flag resets when cmd complete, fpg flag resets after fpga reconfig
	reg [15:0]regs_st;
	reg sms_unlock;

	always @(negedge clk)
	begin
		
		if(base_io_oe_sync)
		begin
			regs_st[15:0] <= 
			cpu_ce_fifo_data ? fifo_do_a[7:0] :
			cpu_ce_fifo_stat ? fifo_status[15:0] : 
			cpu_ce_timer ? timer[15:0] : 
			cpu_ce_sys_stat ? status[15:0] :
			16'hffff;
		end
		
		timer_1ms <= tick_1ms ? 0 : timer_1ms + 1;
		if(tick_1ms)timer <= timer + 1;
		
		if(base_io_oe_sync & cpu_ce_sys_stat)strobe <= !strobe;
		
		if(base_io_we_sync & cpu_ce_sys_stat){fpg_busy_flag, mcu_busy_flag} <= cpu_data[2:1];
			else
		if(!mcu_busy)mcu_busy_flag <= 0;
		
		if(sms_mode == 0)sms_unlock <= 0;
			else
		if(base_io_key_sync & cpu_addr[16:1] == 16'h008F)sms_unlock <= cpu_data[7:0] == 8'h2A;//unlock io for sms mode. also used for sst ack in map_sys_sms
		
	end

	wire base_io_we_sync, base_io_oe_sync, base_io_key_sync;

	sync_edge sync_inst_we(
		.clk(clk),
		.ce(cpu_ce_baio & !we_lo),
		.sync(base_io_we_sync)
	);

	sync_edge sync_inst_oe(
		.clk(clk),
		.ce(cpu_ce_baio & !oe),
		.sync(base_io_oe_sync)
	);
	
	sync_edge sync_inst_key(
		.clk(clk),
		.ce(!cpu_addr[18] & !we_lo),
		.sync(base_io_key_sync)
	);
//****************************************************************************************************************** fifo				
	wire [15:0]fifo_status = {fifo_rxf, pi_fifo_rxf, 3'd0, fifo_rd_len[10:0]};

	//wire pi_fifo_rxf;
	wire pi_fifo_we = pi_ce_fifo & pi_we;
	wire pi_fifo_oe = pi_ce_fifo & pi_oe;

	wire [10:0]fifo_rd_len;
	wire fifo_rxf;
	wire fifo_oe = cpu_ce_baio & cpu_ce_fifo_data & !oe;
	wire fifo_we = cpu_ce_baio & cpu_ce_fifo_data & base_io_we_sync;

	wire [7:0]fifo_do_a;
	fifo fifo_a(
		.di(pi_do),
		.do(fifo_do_a),
		.oe(fifo_oe),
		.we(pi_fifo_we),
		.fifo_empty(fifo_rxf),
		.rd_len(fifo_rd_len),
		.clk(clk)
	);//arm to moto

	wire [7:0]fifo_do_b;
	fifo fifo_b(
		.di(cpu_data), 
		.do(fifo_do_b), 
		.oe(pi_fifo_oe), 
		.we(fifo_we), 
		.fifo_empty(pi_fifo_rxf),
		.clk(clk)
	);//moto to arm

//****************************************************************************************************************** sys cfg	

	reg [7:0]scfg[8];
	assign sys_cfg[`BW_SYS_CFG-1:0] = {scfg[7],scfg[6],scfg[5],scfg[4],scfg[3],scfg[2],scfg[1],scfg[0]};

	always @(negedge pi_clk)
	begin
	if(pi_ce_cfg & pi_we)scfg[pi_addr[2:0]][7:0] <= pi_do[7:0];
	end

	
	
endmodule


//******************************************************************************************************************
module fifo
(di, do, oe, we, fifo_empty, rd_len, clk);

	input [7:0]di;
	output [7:0]do;
	input oe, we, clk;
	output fifo_empty;
	output [10:0]rd_len;
	
	assign fifo_empty = we_addr == oe_addr;
	assign rd_len[10:0] = we_addr - oe_addr;
	
	reg [10:0]we_addr;
	reg [10:0]oe_addr;
	reg [1:0]oe_st, we_st;	
	
	wire oe_sync = oe_st[1:0] == 2'b10;
	wire we_sync = we_st[1:0] == 2'b10;	
	
	always @(negedge clk)
	begin
	
		oe_st[1:0] <= {oe_st[0], (oe & !fifo_empty)};
		we_st[1:0] <= {we_st[0], we};
		
		if(oe_sync)oe_addr <= oe_addr + 1;
		if(we_sync)we_addr <= we_addr + 1;
	end
	
	
	
	ram_dp8 fifo_ram(
		.din_a(di), 
		.addr_a(we_addr), 
		.we_a(we), 
		.clk_a(clk), 
		.addr_b(oe_addr), 
		.dout_b(do), 
		.clk_b(clk)
	);

	
endmodule

//******************************************************************************************************************
module sync_edge(
	input clk, ce, 
	output sync
);

	assign sync = ce_st[2:0] == 3'b011;

	reg [3:0]ce_st;
	
	always @(negedge clk)
	begin
		ce_st[3:0] <= {ce_st[2:0], ce};
	end

endmodule


module ram_dp8
(din_a, addr_a, we_a, dout_a, clk_a, din_b, addr_b, we_b, dout_b, clk_b);

	input [7:0]din_a, din_b;
	input [15:0]addr_a, addr_b;
	input we_a, we_b, clk_a, clk_b;
	output reg [7:0]dout_a, dout_b;

	
	reg [7:0]ram[65536];
	
	always @(negedge clk_a)
	begin
		dout_a <= we_a ? din_a : ram[addr_a];
		if(we_a)ram[addr_a] <= din_a;
	end
	
	always @(negedge clk_b)
	begin
		dout_b <= we_b ? din_b : ram[addr_b];
		if(we_b)ram[addr_b] <= din_b;
	end
	
endmodule

module ram_dp16
(din_a, addr_a, we_a, dout_a, clk_a, din_b, addr_b, we_b, dout_b, clk_b);

	input [15:0]din_a, din_b;
	input [15:0]addr_a, addr_b;
	input we_a, we_b, clk_a, clk_b;
	output reg [15:0]dout_a, dout_b;

	
	reg [15:0]ram[65536];
	
	always @(negedge clk_a)
	begin
		dout_a <= we_a ? din_a : ram[addr_a];
		if(we_a)ram[addr_a] <= din_a;
	end
	
	always @(negedge clk_b)
	begin
		dout_b <= we_b ? din_b : ram[addr_b];
		if(we_b)ram[addr_b] <= din_b;
	end
	
endmodule


module rst_ctrl(
	input clk,
	input rst,
	input btn,
	input sms_mode,
	input x32_mode,
	output hrst,
	output sys_rst,
	input [7:0]map_idx,
	output reg rst_hold,
	input ctrl_rst_off,
	input [15:0]dbus,
	input [23:1]abus,
	input rom_oe
);
	
	
	assign hrst = rst_act | ext_rst ? 0 : 1'bz ;
	assign sys_rst = rst_lock ? 0 : sms_mode ? !addr20_st : (rst_st[1:0] == 2'b11 & !soft_reset);

	
	wire rst_req = (sms_mode_st[0] != sms_mode_st[1]) | (x32_mode_st[1:0] == 2'b10);
	wire rst_act = rst_ct == 1;
	wire rst_lock = rst_ct != 0;
	wire rst_off = ctrl_rst_off & !ext_rst & !ext_rst_hold;

	
	reg [1:0]sms_mode_st;
	reg [1:0]x32_mode_st;
	reg [2:0]rst_ct;
	reg [22:0]delay;
	reg [2:0]rst_st;
	reg addr20_st;
	reg ext_rst, ext_rst_hold;
	
	reg soft_reset;
	reg [1:0]rst_opcode;
	reg [7:0]rom_oe_st;
	
	always @(negedge clk)
	begin
		
		rst_st[2:0] <= {rst_st[1:0], !rst};
		addr20_st <= abus[20];
		
		sms_mode_st[1:0] <= {sms_mode_st[0], sms_mode};
		x32_mode_st[1:0] <= {x32_mode_st[0], x32_mode};
		
		if(rst_ct == 0 | rst_req)delay <= 1;
			else
		delay <= delay + 1;
		
		if(rst_req)rst_ct <= 1;
			else
		if(rst_ct != 0 & delay == 0)rst_ct <= rst_ct + 1;
		
		
		if(sys_rst & !rst_off)rst_hold <= 1;
			else
		if(map_idx == 0 | rst_off)rst_hold <= 0;
		
		
		ext_rst <= btn & map_idx != 0 & !sms_mode;
		
		if(map_idx == 0)ext_rst_hold <= 0;
			else
		if(ext_rst)ext_rst_hold <= 1;
		
		
//************************************************************************************* soft reset detection
		rom_oe_st[7:0] <= {rom_oe_st[6:0], rom_oe};
		
		if(rst_st[2:0] == 3'b001)soft_reset <= rst_opcode[1:0] == 2'b10;
			else
		if(rst_st[2:0] == 3'b110)soft_reset <= 0;
		
		if(rom_oe_st[5:3] == 3'b011)
		begin
			 rst_opcode[1:0] = {rst_opcode[0], dbus[15:0] == 16'h4E70};
		end
		
	end

endmodule


module mem_16_to_8(
	
	input [15:0]dout_16,
	output [15:0]din_16,
	output [22:0]addr_16,
	output oe_16, we_lo_16, we_hi_16,
	
	
	output [15:0]dout_8,
	input [15:0]din_8,
	input [22:0]addr_8,
	input oe_8, we_8
	
);


	assign oe_16 = oe_8;
	assign we_hi_16 = we_8 & addr_8[0] == 0;
	assign we_lo_16 = we_8 & addr_8[0] == 1;
	
	assign addr_16[22:1] = addr_8[22:1];
	assign din_16[15:0] = {din_8[7:0], din_8[7:0]};
	assign dout_8[7:0] = addr_8[0] == 0 ? dout_16[15:8] : dout_16[7:0];

endmodule

module mkey_ctrl(
	input clk,
	input [`BW_MDBUS-1:0]mdbus,
	output mkey_oe_n, mkey_we
);

	`include "mdbus.v"

	assign mkey_oe_n = !(mkey_ce & mkey_on & !oe);
	assign mkey_we =  mkey_ce & !we_lo & map_rst;
	
	wire mkey_ce = !as & cpu_addr[23:0] == 24'hA10000;
	
	reg mkey_on;
	
	always @(negedge clk)
	begin
		if(mkey_we_edge)mkey_on <= cpu_data[0];
	end
	
	wire mkey_we_edge;
	sync_edge ce_edge_inst(
		.clk(clk),
		.ce(mkey_we),
		.sync(mkey_we_edge)
	);
	
endmodule

module bus_ctrl(

	input clk,
	input sys_rst,
	input bus_oe,
	
	output dat_dir, 
	output dat_oe
);


	assign dat_oe  = 0;
	assign dat_dir = bus_oe & bus_ok == 2'b11 ? 1 : 0;

	
	wire rst_edge = sys_rst & !sys_rst_st;
	
	reg sys_rst_st;
	reg [1:0]bus_ok;//bus_ok prewent hangs due undefined system state right after fpga_init
	
	always @(negedge clk)
	begin
	
		sys_rst_st <= sys_rst;
		
		if(rst_edge)bus_ok <= 0;
			else
		bus_ok[1:0] <= {bus_ok[0], 1'b1};
		
	end
	

endmodule

