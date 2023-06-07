



module base_io(

	input  MapIn mai,
	input  mcu_busy,
	
	output [7:0]pi_di,
	output [15:0]dato,
	output io_oe, 
	output pi_fifo_rxf
);

	
	
	wire [15:0]cpu_data  = mai.cpu.data[15:0];
	wire [23:0]cpu_addr  = mai.cpu.addr[23:0];
	wire we_lo 				= mai.cpu.we_lo;
	wire oe 					= mai.cpu.oe;
	wire tim 				= mai.cpu.tim;
	wire sys_rst			= mai.sys_rst;
	wire clk					= mai.clk;
	wire sms_mode 			= mai.cfg.ct_sms;
	
	wire pi_ce_cfg 		= mai.pi.map.ce_cfg;
	wire pi_ce_fifo		= mai.pi.map.ce_fifo;
	wire pi_we 				= mai.pi.we;
	wire pi_oe 				= mai.pi.oe;
	wire pi_clk 			= mai.pi.clk;
	
	wire [31:0]pi_addr 	= mai.pi.addr[31:0];
	wire [7:0]pi_do		= mai.pi.dato[7:0];
	
	assign pi_di[7:0] 	= fifo_do_b[7:0];
	
//****************************************************************************************************************** cpu regs
	BaioDriver drv_smd;
	assign drv_smd.ce				= !tim & {cpu_addr[7:4], 4'd0} == 8'hD0 & !sys_rst;
	assign drv_smd.addr[3:0]	= {cpu_addr[3:1], 1'b0};
	assign drv_smd.data[15:0]	= regs_st[15:0];
	assign drv_smd.oe				= !oe;
	assign drv_smd.we				= !we_lo;
	
	BaioDriver drv_sms;
	assign drv_sms.ce				= !cpu_addr[18] & {cpu_addr[16:5], 4'd0} == 16'h0080 & sms_unlock;
	assign drv_sms.addr[3:0]	= {cpu_addr[4:2], 1'b0};
	assign drv_sms.data[15:0]	= cpu_addr[1] == 1 ? regs_st[15:8] : regs_st[7:0];
	assign drv_sms.oe				= !oe;
	assign drv_sms.we				= !we_lo;
//*****
	BaioDriver drv;
	assign drv					= sms_mode ? drv_sms : drv_smd;
	
	assign io_oe				= drv.ce & drv.oe;//fix me if will use internal drv source
	assign dato[15:0] 		= drv.data[15:0];
	
	wire [15:0]status 		= {8'h55, 4'hA, strobe, fpg_busy_flag, mcu_busy_flag, !mai.cfg.ct_gmode};
//*****

	wire cpu_ce_fifo_data = drv.addr == 4'h0;
	wire cpu_ce_fifo_stat = drv.addr == 4'h2;
	wire cpu_ce_sys_stat  = drv.addr == 4'h4;
	wire cpu_ce_timer     = drv.addr == 4'h6;

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
			cpu_ce_fifo_data 	? fifo_do_a[7:0] :
			cpu_ce_fifo_stat 	? fifo_status[15:0] : 
			cpu_ce_timer 		? timer[15:0] : 
			cpu_ce_sys_stat 	? status[15:0] :
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
		.ce(drv.ce & drv.we),
		.sync(base_io_we_sync)
	);

	sync_edge sync_inst_oe(
		.clk(clk),
		.ce(drv.ce & drv.oe),
		.sync(base_io_oe_sync)
	);
	
	sync_edge sync_inst_key(
		.clk(clk),
		.ce(!cpu_addr[18] & drv.we),
		.sync(base_io_key_sync)
	);
//****************************************************************************************************************** fifo				
	wire [15:0]fifo_status = {fifo_rxf, pi_fifo_rxf, 3'd0, fifo_rd_len[10:0]};


	wire pi_fifo_we = pi_ce_fifo & pi_we;
	wire pi_fifo_oe = pi_ce_fifo & pi_oe;

	wire [10:0]fifo_rd_len;
	wire fifo_rxf;
	wire fifo_oe = drv.ce & cpu_ce_fifo_data & !oe;
	wire fifo_we = drv.ce & cpu_ce_fifo_data & base_io_we_sync;

	wire [7:0]fifo_do_a;
	fifo fifo_a(
		.dti(pi_do),
		.dto(fifo_do_a),
		.oe(fifo_oe),
		.we(pi_fifo_we),
		.fifo_empty(fifo_rxf),
		.rd_len(fifo_rd_len),
		.clk(clk)
	);//arm to moto

	wire [7:0]fifo_do_b;
	fifo fifo_b(
		.dti(cpu_data), 
		.dto(fifo_do_b), 
		.oe(pi_fifo_oe), 
		.we(fifo_we), 
		.fifo_empty(pi_fifo_rxf),
		.clk(clk)
	);//moto to arm

		
	
endmodule


//******************************************************************************************************************
module fifo
(dti, dto, oe, we, fifo_empty, rd_len, clk);

	input [7:0]dti;
	output [7:0]dto;
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
		.din_a(dti), 
		.addr_a(we_addr), 
		.we_a(we), 
		.clk_a(clk), 
		.addr_b(oe_addr), 
		.dout_b(dto), 
		.clk_b(clk)
	);

	
endmodule


