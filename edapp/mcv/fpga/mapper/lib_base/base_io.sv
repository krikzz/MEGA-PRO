



module base_io(

	input  MapIn mai,
	input  mcu_busy,
	
	output [7:0]pi_di,
	output [15:0]dato,
	output io_oe, 
	output pi_fifo_rxf,
	output MemCtrl	mio_mem,
	output [3:0]mio_ce
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
	assign drv_smd.data[15:0]	= reg_val[15:0];
	assign drv_smd.oe				= !oe;
	assign drv_smd.we				= !we_lo;
	
	BaioDriver drv_sms;
	assign drv_sms.ce				= !cpu_addr[18] & {cpu_addr[16:5], 4'd0} == 16'h0080 & sms_unlock;
	assign drv_sms.addr[3:0]	= {cpu_addr[4:2], 1'b0};
	assign drv_sms.data[15:0]	= cpu_addr[1] == 1 ? reg_val[15:8] : reg_val[7:0];
	assign drv_sms.oe				= !oe;
	assign drv_sms.we				= !we_lo;
//*****
	BaioDriver drv;
	assign drv					= sms_mode ? drv_sms : drv_smd;
	
	assign io_oe				= drv.ce & drv.oe;//fix me if will use internal drv source
	assign dato[15:0] 		= drv.data[15:0];
	
	wire [15:0]status 		= {8'h55, 4'hA, strobe, fpg_busy_flag, mcu_busy_flag, !mai.cfg.ct_gmode};
//*****

	wire cpu_ce_fifo_data 	= drv.addr == 4'h0;
	wire cpu_ce_fifo_stat 	= drv.addr == 4'h2;
	wire cpu_ce_sys_stat  	= drv.addr == 4'h4;
	wire cpu_ce_timer     	= drv.addr == 4'h6;
	wire cpu_ce_mdat			= drv.addr == 4'h8;
	wire cpu_ce_madr			= drv.addr == 4'hA;
	

	wire tick_1ms 				= timer_1ms == 16'd49999;
	wire [15:0]reg_val		= cpu_ce_mdat ? mio_dato : regs_st;
	
	reg strobe;
	reg [15:0]timer_1ms;
	reg [15:0]timer;
	reg mcu_busy_flag, fpg_busy_flag;//mcu flag resets when cmd complete, fpg flag resets after fpga reconfig
	reg [15:0]regs_st;
	reg sms_unlock;

	always @(posedge clk)
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
		
		if(tick_1ms)
		begin
			timer <= timer + 1;
		end
		
		if(base_io_oe_sync & cpu_ce_sys_stat)
		begin
			strobe <= !strobe;
		end
		
		if(base_io_we_sync & cpu_ce_sys_stat)
		begin
			{fpg_busy_flag, mcu_busy_flag} <= cpu_data[2:1];
		end
			else
		if(!mcu_busy)
		begin
			mcu_busy_flag <= 0;
		end
		
		if(sms_mode == 0)
		begin
			sms_unlock <= 0;
		end
			else
		if(base_io_key_sync & cpu_addr[16:1] == 16'h008F)
		begin
			sms_unlock <= cpu_data[7:0] == 8'h2A;//unlock io for sms mode. also used for sst ack in map_sys_sms
		end
		
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
	wire fifo_oe = drv.ce & cpu_ce_fifo_data & base_io_oe_sync;//!oe; (fix for sms sst crash)
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
		.dti(cpu_data[7:0]), 
		.dto(fifo_do_b), 
		.oe(pi_fifo_oe), 
		.we(fifo_we), 
		.fifo_empty(pi_fifo_rxf),
		.clk(clk)
	);//moto to arm
//************************************************************************************* momory io (mem access via REG_MEM_DATA/REG_MEM_ADDR)
	wire [7:0]mio_dato;
	
	mem_io mem_io_inst(
	
		.clk(mai.clk),
		.dati(cpu_data[7:0]),
		.oe(drv.oe),
		.we(drv.we),
		.ce_data(cpu_ce_mdat & drv.ce),
		.ce_addr(cpu_ce_madr & drv.ce),
		
		.mem0_dato(mai.rom0_do),
		.mem1_dato(mai.rom1_do),
		.mem2_dato(mai.sram_do),
		.mem3_dato(mai.bram_do),
		
		.mem(mio_mem),
		.mem_ce(mio_ce),
		.dato(mio_dato)
	);
	
endmodule


//****************************************************************************************************************** fifo
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
	
	always @(posedge clk)
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

//****************************************************************************** mem io
module mem_io(
	
	input  clk,
	input  [7:0]dati,
	input  oe,
	input  we,
	input  ce_data,
	input  ce_addr,
	
	input  [15:0]mem0_dato,
	input  [15:0]mem1_dato,
	input  [15:0]mem2_dato,
	input  [15:0]mem3_dato,
	
	output MemCtrl mem,
	output [3:0]mem_ce,
	output [7:0]dato
);
	
	assign mem.dati	= {dati[7:0], dati[7:0]};
	assign mem.addr	= addr;
	assign mem.oe		= ce_data & oe;
	assign mem.we_lo	= ce_data & we & addr[31] & addr[0] == 1;
	assign mem.we_hi	= ce_data & we & addr[31] & addr[0] == 0;

`ifdef HWC_ROM1_OFF
	assign mem_ce[0]	= ce_data & addr[29:23] <= 'h01;//mirrored to 16M area
`elsif HWC_ROM1_ON
	assign mem_ce[0]	= ce_data & addr[29:23] == 'h00;
	assign mem_ce[1]	= ce_data & addr[29:23] == 'h01;
`else
	"undefined hardware config"
`endif
	assign mem_ce[2]	= ce_data & addr[29:23] == 'h02 & addr[19] == 0;
	assign mem_ce[3]	= ce_data & addr[29:23] == 'h02 & addr[19] == 1;
	assign dato 		= addr[0] == 0 ? mem_dato[15:8] : mem_dato[7:0];
	
	wire [15:0]mem_dato	=
	mem_ce[0] ? mem0_dato : 
	mem_ce[1] ? mem1_dato : 
	mem_ce[2] ? mem2_dato : mem3_dato;
	
	reg [31:0]addr;
	
	always @(posedge clk)
	if(addr_wr_pe)
	begin
		addr[31:0]	<= {dati[7:0], addr[31:8]};
	end
		else
	if(mem_rw_end)
	begin
		addr[30:0]	<= addr[30:0] + 1;
	end
	
	
	wire mem_rw			= ce_data & (oe | we);
	wire mem_rw_end;
	
	edge_dtk edge_mem_rw(

		.clk(clk),
		.sync_mode(1),
		.sig_i(mem_rw),
		.sig_ne(mem_rw_end)
	);
	
	wire addr_wr		= ce_addr & we;
	wire addr_wr_pe;
	
	edge_dtk edge_addr_wr(

		.clk(clk),
		.sync_mode(1),
		.sig_i(addr_wr),
		.sig_pe(addr_wr_pe)
	);
	
endmodule

