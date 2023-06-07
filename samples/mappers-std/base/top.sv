


module top(

	inout  [15:0]data,
	input  [23:1]addr,
	input  as, cas, ce_lo, ce_hi, clk50, vclk, eclk, oe, rst, we_lo, we_hi, 
	output cart, dtak, hrst,  
	output [3:0]sms,
	
	output dat_dir, dat_oe,
	
	output spi_miso,
	input  spi_mosi, spi_sck,
	input  spi_ss,
	
	output mcu_fifo_rxf, mcu_mode, mcu_sync, mcu_rst,
	input  mcu_busy,
		
	inout  [15:0]ram0_data,
	output [21:0]ram0_addr,
	output ram0_oe, ram0_we, ram0_ub, ram0_lb, ram0_ce,
	
	inout  [15:0]ram1_data,
	output [21:0]ram1_addr,
	output ram1_oe, ram1_we, ram1_ub, ram1_lb, ram1_ce,
	
	inout  [15:0]ram2_data,
	output [17:0]ram2_addr,
	output ram2_oe, ram2_we, ram2_ub, ram2_lb, ram2_ce,
	
	inout  [15:0]ram3_data,
	output [17:0]ram3_addr,
	output ram3_oe, ram3_we, ram3_ub, ram3_lb, 
		
	inout  [3:0]xbus,
	
	input  gpclk,
	inout  [4:0]gpio,
	
	output dac_mclk, dac_lrck, dac_sclk, dac_sdin,
	
	output mkey_oe, mkey_we, led_r, led_g,
	input  btn

);
	
	CpuBus cpu;
	PiBus  pi;
	SysCfg cfg;
	
	MapIn  mai;
	MapOut mao;
	
	DmaBus dma;
	DacBus dac;
	
	MemCtrl	rom0_ctrl;
	MemCtrl	rom1_ctrl;
	MemCtrl	sram_ctrl;
	MemCtrl	bram_ctrl;
//*************************************************************************************	
	wire  [15:0]rom0_do 			= ram0_data[15:0];
	wire  [15:0]rom1_do			= ram1_data[15:0];
	wire  [15:0]sram_do			= ram2_data[15:0];
	wire  [15:0]bram_do			= ram3_data[15:0];
		
	assign cpu.data[15:0]		= data[15:0];
	assign cpu.addr[23:1] 		= addr[23:1];
	assign cpu.as 					= as;
	assign cpu.oe 					= oe;
	assign cpu.we_hi 				= we_hi;
	assign cpu.we_lo 				= we_lo;
	assign cpu.ce_hi 				= ce_hi;
	assign cpu.ce_lo 				= ce_lo;
	assign cpu.tim 				= {addr[23:8], 8'd0} == 24'hA13000 & !as ? 0 : 1;
	assign cpu.vclk 				= vclk;
//************************************************************************************* bus controls
	assign mcu_rst 	= mcd_mcu_rst;
	assign mcu_sync 	= mcd_mcu_sync;
	assign mcu_mode 	= !(mcd_mcu_mode | mdp_mcu_mode);//keep mcu in master mode
	assign xbus[0]		= !mdp_act;//exit from mcd-cdd handler
	
	assign sms[1:0]	= cfg.ct_sms ? 'b01 : 'bzz;
	assign sms[2] 		= cfg.ct_sms & btn ? 1'b0 : 1'bz;
	assign sms[3]		= cfg.ct_sms ? '0   : 'bz;
	
		
	assign data[15:0] = 
	dat_dir == 0	? 16'hzzzz : 
	base_io_oe 		? base_io_do[15:0] :
	cheats_oe 		? cheats_do[15:0] :
	mdp_oe			? mdp_data[15:0] :
	mcd_oe			? mcd_do :
	mao.map_oe 		? mao.map_do[15:0] : 
	16'h0000;
	
	
	mem_ctrl ram0(
	
		.data(ram0_data[15:0]),
		.addr(ram0_addr[21:0]),
		.ce(ram0_ce), 
		.oe(ram0_oe),
		.we(ram0_we), 
		.ub(ram0_ub), 
		.lb(ram0_lb),
		.mem(rom0_ctrl),
		.msk_on(!mask_off),
		.msk(cfg.rom_msk),
		.dma_req(dma.req_rom0),
		.dma(dma),
	);
	
	mem_ctrl ram1(
	
		.data(ram1_data[15:0]),
		.addr(ram1_addr[21:0]),
		.ce(ram1_ce), 
		.oe(ram1_oe), 
		.we(ram1_we), 
		.ub(ram1_ub), 
		.lb(ram1_lb),
		.mem(rom1_ctrl),
		.msk_on(0),
		.msk('1),
		.dma_req(dma.req_rom1),
		.dma(dma),
	);
	
	mem_ctrl ram2(
	
		.data(ram2_data[15:0]),
		.addr(ram2_addr[17:0]),
		.ce(ram2_ce), 
		.oe(ram2_oe), 
		.we(ram2_we), 
		.ub(ram2_ub), 
		.lb(ram2_lb),
		.mem(sram_ctrl),
		.msk_on(0),
		.msk('1),
		.dma_req(dma.req_sram),
		.dma(dma),
	);
	
	mem_ctrl ram3(
	
		.data(ram3_data[15:0]),
		.addr(ram3_addr[17:0]),
		.oe(ram3_oe), 
		.we(ram3_we), 
		.ub(ram3_ub), 
		.lb(ram3_lb),
		.mem(bram_ctrl),
		.msk_on(!(mask_off | mcd_act)),//always used by cd hardware (bios + pcm or cd-bram)
		.msk(cfg.brm_msk),
		.dma_req(dma.req_bram),
		.dma(dma),
	);
	

	
	bus_ctrl bus_ctrl_inst(
		.clk(mai.clk),
		.sys_rst(mai.sys_rst),
		.bus_oe(cheats_oe | base_io_oe | mao.map_oe | mdp_oe | mcd_oe),
		.dat_dir(dat_dir), 
		.dat_oe(dat_oe)
	);
	
//************************************************************************************* map in
	assign mai.cpu					= cpu;
	assign mai.clk					= clk50;
	assign mai.btn					= btn;
	assign mai.gp_i[4:0]			= gpio[4:0];
	assign mai.gp_ck				= gpclk;
	assign mai.sys_rst			= sys_rst;
	assign mai.map_rst			= map_idx == 0 | !cfg.ct_gmode | rst_hold;
	
	assign mai.rom0_do[15:0] 	= mcd_act ? rom0_do_mcd : rom0_do[15:0];//for dual port memory
	assign mai.rom1_do[15:0] 	= rom1_do[15:0];//this not available in mcd mode
	assign mai.sram_do[15:0] 	= sram_do[15:0];//this not available in mcd mode
	assign mai.bram_do[15:0] 	= mcd_act ? bram_do_mcd : bram_do[15:0];//for dual port memory
	
	
	assign mai.cfg					= cfg;
	assign mai.pi					= pi;
//************************************************************************************* map out	
	assign gpio[0] 	= mao.gp_dir[0] == 0 ? mao.gp_o[0] : 1'bz;
	assign gpio[1] 	= mao.gp_dir[1] == 0 ? mao.gp_o[1] : 1'bz;
	assign gpio[2] 	= mao.gp_dir[2] == 0 ? mao.gp_o[2] : 1'bz;
	assign gpio[3] 	= mao.gp_dir[3] == 0 ? mao.gp_o[3] : 1'bz;
	assign gpio[4] 	= mao.gp_dir[4] == 0 ? mao.gp_o[4] : 1'bz;
	
	assign led_r 		= mao.led_r | mcd_led_r | dma.mem_req;
	assign led_g 		= mao.led_g | mcd_led_g;
	assign cart 		= mao.cart;
	assign dtak 		= mao.dtack ? 0 : 1'bz;
	assign dac			= mdp_act ? mdp_dac : mcd_act ? mcd_dac : mao.dac;
	
	wire mask_off		= mao.mask_off;//also forced for mega-cd? (only for bram)
	
	assign rom0_ctrl	= mcd_act ? rom0_mcd : mao.rom0;
	assign rom1_ctrl 	= mcd_act ? rom1_mcd : mao.rom1;
	assign sram_ctrl 	= mcd_act ? sram_mcd : mao.sram;
	assign bram_ctrl	= mcd_act ? bram_mcd : mao.bram;

//************************************************************************************* mappers	
	wire [7:0]map_idx = cfg.map_idx[7:0];
	
	assign mao 	= 
	mai.map_rst		? mout_sys :
	mai.sst.act  	? mout_sst :
						  mout_hub;
	
	
	MapOut mout_sys;
	map_sys map_sys_inst(mai, mout_sys);
	
	MapOut mout_hub;
	map_hub map_hub_inst(mai, mout_hub);

	
	wire [7:0]map_status = {4'hA, 3'b0, mout_hub.map_nsp};
//************************************************************************************* base io
	wire [7:0]pi_di_bio;
	wire [15:0]base_io_do;
	wire base_io_oe;
	
	
	base_io base_io_inst(
		
		.mai(mai),
		.mcu_busy(mcu_busy),
		.pi_di(pi_di_bio),
		.dato(base_io_do),
		.io_oe(base_io_oe),
		.pi_fifo_rxf(mcu_fifo_rxf)
	);
	
//************************************************************************************* pi
	wire [7:0]pi_di = 
	pi.map.dst_mem ? dma.pi_di : 
	pi.map.ce_cfg  ? pi_di_cfg : 
	pi.map.ce_fifo	? pi_di_bio :
	pi.map.dst_map ? mout_hub.pi_di[7:0] :
	pi.map.ce_mcd  ? pi_di_mcd :
	pi.map.ce_sst 	? pi_di_sst :
	pi.map.ce_mdp	? pi_di_mdp :
	pi.map.ce_mst	? map_status :
	8'hff;
	
	
	pi_io pi_inst(
		
		.clk(mai.clk),
		.dati(pi_di),
		.mosi(spi_mosi),
		.ss(spi_ss),
		.spi_clk(spi_sck),
		.miso(spi_miso),
		.pi(pi)
	);
//************************************************************************************* dma
	dmaio dma_inst(
		
		.pi(pi),
		.rom0_do(rom0_do),
		.rom1_do(rom1_do),
		.sram_do(sram_do),
		.bram_do(bram_do),
		.dma(dma)
	);	
//************************************************************************************* sys cfg	
	wire [7:0]pi_di_cfg;
	
	sys_cfg cfg_inst(
			
		.mai(mai),
		.cfg(cfg),
		.pi_di(pi_di_cfg)
	);

//************************************************************************************* megakey	
	mkey_ctrl mkey_inst(
		
		.mai(mai),
		.mkey_oe_n(mkey_oe), 
		.mkey_we(mkey_we)
	);
//************************************************************************************* rst ctrl
	wire rst_hold;
	wire sys_rst;
	
	rst_ctrl rst_inst(
	
		.clk(mai.clk),
		.rst(rst),
		.btn(mai.btn),
		.sms_mode(cfg.ct_sms),
		.x32_mode(cfg.ct_32x),
		.hrst(hrst),
		.sys_rst(sys_rst),
		.map_idx(map_idx),
		.rst_hold(rst_hold),
		.ctrl_rst_off(cfg.ct_rst_off),
		
		.dbus(data[15:0]),
		.abus(addr[23:1]),
		.rom_oe(!ce_hi & !oe & !as)
	);
//xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx various optional extensions begins here
//xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
//xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
//xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx		
//************************************************************************************* save states controller		
	MapOut mout_sst;
	MapOut mout_sys_sms;
	
	assign mout_sst = sst_act_sms ? mout_sys_sms : mout_sys;

	wire sst_act_smd, sst_act_sms;
	wire [7:0]pi_di_sst;
	

	
`ifdef USE_SST_SMS
	`define 	USE_SST
`elsif USE_SST_SMD
	`define 	USE_SST
`endif	
	
	
`ifdef USE_SST

	sst_controller sst_inst(
	
		.mai(mai),
		.sst_di(mout_hub.sst_di),
		
		.sst(mai.sst),
		.pi_di(pi_di_sst),
		.sst_act_smd(sst_act_smd),
		.sst_act_sms(sst_act_sms)
	);
	
`endif

	
`ifdef USE_SST_SMS	

	map_sys_sms sys_inst_sms(mai, mout_sys_sms);
	
`endif	

//************************************************************************************* cheats
	wire [15:0]cheats_do;
	wire cheats_oe;

`ifdef USE_CHEATS
	
	cheats cheats_inst(
		
		.mai(mai),
		.cheats_do(cheats_do),
		.cheats_oe(cheats_oe)
	);

`endif
//************************************************************************************* audio	
`ifdef USE_AUDIO

	audio_ed audio_inst(
	
		.clk(mai.clk),
		.rst(mai.map_rst | mai.sst.act),
		.dac(dac),
		
		.mclk(dac_mclk),
		.lrck(dac_lrck),
		.sclk(dac_sclk),
		.sdin(dac_sdin)
	 );
	 
`endif
//************************************************************************************* mdp
	DacBus mdp_dac;
	wire mdp_oe;
	wire [15:0]mdp_data;
	wire [7:0]pi_di_mdp;
	wire mdp_act;
	wire mdp_mcu_mode;
	
`ifdef USE_MDP
		
	mdp mdp_inst(
	
		.mai(mai),

		.mdp_oe(mdp_oe),
		.mdp_data(mdp_data),
		.pi_di(pi_di_mdp),
		.mdp_act(mdp_act),
		.mcu_mode(mdp_mcu_mode),
		.dac(mdp_dac),
	);
	
`endif
//************************************************************************************* mega-cd	
	DacBus mcd_dac;
	wire mcd_act;
	wire mcd_mcu_mode;
	wire mcd_mcu_sync;
	wire mcd_mcu_rst;
	wire mcd_led_r;
	wire mcd_led_g;
	wire [7:0]pi_di_mcd;
	wire [15:0]mcd_do;
	wire mcd_oe;
	
	wire [15:0]rom0_do_mcd;
	wire [15:0]bram_do_mcd;
	
	MemCtrl rom0_mcd;
	MemCtrl rom1_mcd;
	MemCtrl sram_mcd;
	MemCtrl bram_mcd;

`ifdef USE_MCD	
	megacd_top megacd_inst(

		.mai(mai),

		.led_r(mcd_led_r),
		.led_g(mcd_led_g),
		.mcu_sync(mcd_mcu_sync),
		.mcu_rst(mcd_mcu_rst),
		.mcd_act(mcd_act),
		.mcu_mode(mcd_mcu_mode),
		.mcd_oe(mcd_oe),
		.mcd_do(mcd_do),
		.pi_di(pi_di_mcd),
		.dac(mcd_dac),
		
		//system memory io
		.rom0_do(rom0_do),
		.rom1_do(rom1_do),
		.sram_do(sram_do),
		.bram_do(bram_do),
		.rom0(rom0_mcd),
		.rom1(rom1_mcd),
		.sram(sram_mcd),
		.bram(bram_mcd),
		
		
		//mapper memory io
		.rom0_map(mao.rom0),
		.bram_map(mao.bram),
		.rom0_do_map(rom0_do_mcd),
		.bram_do_map(bram_do_mcd)
	);
`endif

endmodule


