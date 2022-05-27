


module top(

	inout [15:0]data,
	input [23:1]addr,
	input as, cas, ce_lo, ce_hi, clk50, vclk, eclk, oe, rst, we_lo, we_hi, 
	output cart, dtak, hrst,  
	output [3:0]sms,
	
	output dat_dir, dat_oe,
	
	output spi_miso,
	input  spi_mosi, spi_sck,
	input spi_ss,
	
	output mcu_fifo_rxf, mcu_mode, mcu_sync, mcu_rst,
	input mcu_busy,
		
	inout [15:0]ram0_data,
	output [21:0]ram0_addr,
	output ram0_oe, ram0_we, ram0_ub, ram0_lb, ram0_ce,
	
	inout [15:0]ram1_data,
	output [21:0]ram1_addr,
	output ram1_oe, ram1_we, ram1_ub, ram1_lb, ram1_ce,
	
	inout [15:0]ram2_data,
	output [17:0]ram2_addr,
	output ram2_oe, ram2_we, ram2_ub, ram2_lb, ram2_ce,
	
	inout [15:0]ram3_data,
	output [17:0]ram3_addr,
	output ram3_oe, ram3_we, ram3_ub, ram3_lb, 
		
	inout [3:0]xbus,
	
	input gpclk,
	inout [4:0]gpio,
	
	output dac_mclk, dac_lrck, dac_sclk, dac_sdin,
	
	output mkey_oe, mkey_we, led_r, led_g,
	input btn

);


	
	//`include "pi_bus.v"
	//`include "sys_cfg.v"
	
	EDBus ed();
	DmaBus dma_io;

//************************************************************************************* gpio port 
	assign gpio[0] = ed.map.gp_dir[0] == 0 ? ed.map.gp_o[0] : 1'bz;
	assign gpio[1] = ed.map.gp_dir[1] == 0 ? ed.map.gp_o[1] : 1'bz;
	assign gpio[2] = ed.map.gp_dir[2] == 0 ? ed.map.gp_o[2] : 1'bz;
	assign gpio[3] = ed.map.gp_dir[3] == 0 ? ed.map.gp_o[3] : 1'bz;
	assign gpio[4] = ed.map.gp_dir[4] == 0 ? ed.map.gp_o[4] : 1'bz;
	assign ed.gp_i[4:0] = gpio[4:0];
//************************************************************************************* ext bus
	
	assign led_r 		= ed.map.led_r | dma_io.mem_req;
	assign led_g 		= ed.map.led_g;
	assign cart 		= ed.map.cart;
	assign dtak 		= ed.map.dtack == 0 ? 0 : 1'bz;
	assign mcu_rst 	= ed.map.mcu_rst;
	assign mcu_sync 	= ed.map.mcu_sync;
	assign mcu_mode 	= !ed.map.mcu_mode;
	assign dac_mclk 	= ed.map.dac.mclk;
	assign dac_lrck 	= ed.map.dac.lrck;
	assign dac_sclk 	= ed.map.dac.sclk;
	assign dac_sdin 	= ed.map.dac.sdin;

	
	assign data[15:0] = 
	dat_dir == 0	? 16'hzzzz : 
	base_io_oe 		? base_io_do[15:0] :
	cheats_oe 		? cheats_do[15:0] :
	ed.map.map_oe 	? ed.map.map_do[15:0] : 
	16'h0000;
	
	
	mem_ctrl ram0(
	
		.data(ram0_data[15:0]),
		.addr(ram0_addr[21:0]),
		.ce(ram0_ce), 
		.oe(ram0_oe),
		.we(ram0_we), 
		.ub(ram0_ub), 
		.lb(ram0_lb),
		.mem(ed.map.rom0),
		.msk_on(!ed.map.mask_off),
		.msk(ed.cfg.rom_msk),
		.dma_req(dma_io.req_rom0),
		.dma(dma_io),
	);
	
	mem_ctrl ram1(
	
		.data(ram1_data[15:0]),
		.addr(ram1_addr[21:0]),
		.ce(ram1_ce), 
		.oe(ram1_oe), 
		.we(ram1_we), 
		.ub(ram1_ub), 
		.lb(ram1_lb),
		.mem(ed.map.rom1),
		.msk_on(0),
		.msk('1),
		.dma_req(dma_io.req_rom1),
		.dma(dma_io),
	);
	
	mem_ctrl ram2(
	
		.data(ram2_data[15:0]),
		.addr(ram2_addr[17:0]),
		.ce(ram2_ce), 
		.oe(ram2_oe), 
		.we(ram2_we), 
		.ub(ram2_ub), 
		.lb(ram2_lb),
		.mem(ed.map.sram),
		.msk_on(0),
		.msk('1),
		.dma_req(dma_io.req_sram),
		.dma(dma_io),
	);
	
	mem_ctrl ram3(
	
		.data(ram3_data[15:0]),
		.addr(ram3_addr[17:0]),
		.oe(ram3_oe), 
		.we(ram3_we), 
		.ub(ram3_ub), 
		.lb(ram3_lb),
		.mem(ed.map.bram),
		.msk_on(!ed.map.mask_off),
		.msk(ed.cfg.brm_msk),
		.dma_req(dma_io.req_bram),
		.dma(dma_io),
	);
	

	
	bus_ctrl bus_ctrl_inst(
		.clk(ed.clk),
		.sys_rst(ed.sys_rst),
		.bus_oe(cheats_oe | base_io_oe | ed.map.map_oe),
		.dat_dir(dat_dir), 
		.dat_oe(dat_oe)
	);
	
//************************************************************************************* ed bus
	assign ed.rom0_do[15:0] = ram0_data[15:0];
	assign ed.rom1_do[15:0] = ram1_data[15:0];
	assign ed.sram_do[15:0] = ram2_data[15:0];
	assign ed.bram_do[15:0] = ram3_data[15:0];
	
	assign ed.clk 			= clk50;
	assign ed.gp_i[4:0]	= gpio[4:0];
	assign ed.gp_ck		= gpclk;
	assign ed.map_rst 	= map_idx == 0 | !ed.cfg.ct_gmode | rst_hold;
	
	assign ed.cpu.oe_as 	= oe;
	
	always_ff @(negedge clk50)
	begin
		
		ed.cpu.data[15:0]	<= data[15:0];
		ed.cpu.addr[23:1] <= addr[23:1];
		ed.cpu.as 			<= as;
		ed.cpu.oe 			<= oe;
		ed.cpu.we_hi 		<= we_hi;
		ed.cpu.we_lo 		<= we_lo;
		ed.cpu.ce_hi 		<= ce_hi;
		ed.cpu.ce_lo 		<= ce_lo;
		ed.cpu.tim 			<= {addr[23:8], 8'd0} == 24'hA13000 & !as ? 0 : 1;
		ed.cpu.vclk 		<= vclk;
		
		ed.btn 				<= btn;
		
	end
//************************************************************************************* mappers	

	
	wire [7:0]map_idx = ed.cfg.map_idx[7:0];
	
	assign ed.map = 
	ed.map_rst	? mout_sys :
	ed.sst.act  ? mout_sst :
					  mout_hub;
	
	
	MapOut mout_sys;
	map_sys map_sys_inst(ed, mout_sys);
	
	MapOut mout_hub;
	map_hub map_hub_inst(ed, mout_hub);

	
//************************************************************************************* base io
	wire [7:0]pi_di_bio;
	wire [15:0]base_io_do;
	wire base_io_oe;
	
	
	base_io base_io_inst(
	
		.mcu_busy(mcu_busy),
		.pi_di(pi_di_bio),
		.dato(base_io_do),
		.io_oe(base_io_oe),
		.pi_fifo_rxf(mcu_fifo_rxf),
		.ed(ed)
	);
	
//************************************************************************************* pi
	wire [7:0]pi_di = 
	
	ed.pi.map.dst_mem ? dma_io.pi_di : 
	ed.pi.map.ce_cfg  ? pi_di_cfg : 
	ed.pi.map.ce_fifo	? pi_di_bio :
	ed.pi.map.dst_map ? mout_hub.pi_di[7:0] : 
	ed.pi.map.ce_sst 	? pi_di_sst :
	8'hff;
	
	
	pi_io pi_inst(
	
		.ed(ed),
		.dati(pi_di),
		.miso(spi_miso), 
		.mosi(spi_mosi), 
		.ss(spi_ss), 
		.spi_clk(spi_sck) 
	);

	
	pi_io_map pi_map_inst(ed);
	
//************************************************************************************* rst ctrl
	wire rst_hold;
	
	rst_ctrl rst_inst(
	
		.clk(ed.clk),
		.rst(rst),
		.btn(ed.btn),
		.sms_mode(ed.map.sms_mode),
		.x32_mode(ed.map.x32_mode),
		.hrst(hrst),
		.sys_rst(ed.sys_rst),
		.map_idx(map_idx),
		.rst_hold(rst_hold),
		.ctrl_rst_off(ed.cfg.ct_rst_off),
		
		.dbus(data[15:0]),
		.abus(addr[23:1]),
		.rom_oe(!ce_hi & !oe & !as)
	);
		
//************************************************************************************* save states controller		
	MapOut mout_sst;
	MapOut mout_sys_sms;
	
	assign mout_sst = sst_act_sms ? mout_sys_sms : mout_sys;

	wire sst_act_smd, sst_act_sms;
	wire [7:0]pi_di_sst;
	

	
`ifdef CFG_SST_SMS
	`define 	CFG_SST
`elsif CFG_SST_SMD
	`define 	CFG_SST
`endif	
	
	
`ifdef CFG_SST

	sst_controller sst_inst(
	
		.ed(ed),
		.sms_mode(ed.map.sms_mode),
		.sst_di(mout_hub.sst_di),
		.pi_di(pi_di_sst),
		.sst_act_smd(sst_act_smd),
		.sst_act_sms(sst_act_sms)
	);
	
`endif

	
`ifdef CFG_SST_SMS	

	map_sys_sms sys_inst_sms(ed, mout_sys_sms);
	
`endif	

//************************************************************************************* cheats
	wire [15:0]cheats_do;
	wire cheats_oe;
	wire cheats_on = ed.cfg.ct_gg_on & !ed.map_rst & !ed.sst.act & !ed.map.sms_mode;

`ifdef CFG_CHEATS
	
	cheats cheats_inst(
	
		.ed(ed),
		.cheats_on(cheats_on),
		.cheats_do(cheats_do),
		.cheats_oe(cheats_oe)
	);

`endif	
//************************************************************************************* var	

	assign {sms[3], sms[1:0]} 	= ed.map.sms_mode ? 3'b001 : 3'bzzz;
	assign sms[2] 					= ed.map.sms_mode & btn ? 1'b0 : 1'bz;

	
	mkey_ctrl mkey_inst(
	
		.ed(ed),
		.mkey_oe_n(mkey_oe), 
		.mkey_we(mkey_we)
		
	);
	
	

	wire [7:0]pi_di_cfg;
	sys_cfg cfg_inst(
	
		.ed(ed),
		.pi_di(pi_di_cfg)
	);
	

	
	dma dma_inst(ed, dma_io);

	
endmodule




