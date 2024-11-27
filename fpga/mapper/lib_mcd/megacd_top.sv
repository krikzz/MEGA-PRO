 
 
module megacd_top(

	input  MapIn mai,

	output led_r,
	output led_g,
	output mcu_sync,
	output mcu_rst,
	output mcd_act,
	output mcu_mode,
	output mcd_oe,
	output [15:0]mcd_do,
	output [7:0]pi_di,
	output DacBus dac,
	
	//system memory io
	input  [15:0]rom0_do,
	input  [15:0]rom1_do,
	input  [15:0]sram_do,
	input  [15:0]bram_do,
	output MemCtrl rom0,
	output MemCtrl rom1,
	output MemCtrl sram,
	output MemCtrl bram,
	
	
	//mapper memory io
	input  MemCtrl	rom0_map,//make is sync for mcd_memory_x ? (no)
	input  MemCtrl	bram_map,//make is sync for mcd_memory_x ? (no)
	output [15:0]rom0_do_map,
	output [15:0]bram_do_map
);

	
	MemBus rom0_bus(rom0, rom0_do);
	MemBus rom1_bus(rom1, rom1_do);
	MemBus sram_bus(sram, sram_do);
	MemBus bram_bus(bram, bram_do);
	
//************************************************************************************* cd key
	assign mcd_oe = mcd_act & (cd_key_oe | mcd_oe_int);
	assign mcd_do = cd_key_oe ? cd_key_val : mcd_do_int;
	
	wire cd_key_oe;
	wire [15:0]cd_key_val;
	
	cd_key cd_key_inst(
	
		.clk(mai.clk),
		.cpu(mai.cpu),
		.key_val(cd_key_val),
		.key_oe(cd_key_oe)
	);
//************************************************************************************* mcd core
	assign mcd_act 		= mai.cfg.fea_mcd & !mai.map_rst;
	assign mcu_mode		= mcd_act;
	
	McdIO  cdio;
	MemIO #(.DW(16), .AW(17), .RO(1)) mem_bios();
	MemIO #(.DW(16), .AW(19), .RO(0)) mem_prg();
	MemIO #(.DW(8),  .AW(13), .RO(0)) mem_bram();
	MemIO #(.DW(8),  .AW(16), .RO(0)) mem_pcm();
	MemIO_WR mem_wrm0();
	MemIO_WR mem_wrm1();
	
	
	wire [15:0]mcd_do_int;
	wire mcd_oe_int;

	mcd_core mcd_inst(
		
		//inputs
		.clk(mai.clk),
		.cpu(mai.cpu),
		.cdio(cdio),
		.map_rst(!mcd_act),
		.slave_mode(slave_mode),
		.mcd_on(mcd_act),
		
		//outputs
		.mcd_do(mcd_do_int),
		.mcd_oe(mcd_oe_int),
		.cdio_di(pi_di),
		.dac(dac),
		.mcu_sync(mcu_sync),
		.mcu_rst(mcu_rst),
		.led_r(led_r), 
		.led_g(led_g),
		
		//memory
		.mem_bios(mem_bios),
		.mem_prg(mem_prg),
		.mem_wrm0(mem_wrm0),
		.mem_wrm1(mem_wrm1),
		.mem_bram(mem_bram),
		.mem_pcm(mem_pcm)
	);
//************************************************************************************* mcd interfacing with mcu
	mcd_io(

		.clk(mai.clk),
		.pi(mai.pi),
		.cdio(cdio)
	);
	
`ifdef MCD_MASTER	
//************************************************************************************* master mode memory
	MemIO #(.DW(16),  .AW(18), .RO(0)) mem_rcrt();
	
	
	assign bram_do_map 			= mem_rcrt.dato[15:0];
	assign mem_rcrt.dati[15:0] = bram_map.dati[15:0];
	assign mem_rcrt.addr[17:0]	= bram_map.addr[17:0];
	
	assign mem_rcrt.oe			= bram_map.oe;
	assign mem_rcrt.we_lo		= bram_map.we_lo;
	assign mem_rcrt.we_hi		= bram_map.we_hi;
	
	wire slave_mode = 0;
	
	mcd_memory_master mcd_mem_inst(
	
		.clk(mai.clk),
	
		.mem_prg(mem_prg),
		.mem_wrm0(mem_wrm0),
		.mem_wrm1(mem_wrm1),
		.mem_pcm(mem_pcm),
		.mem_bios(mem_bios),
		.mem_bram(mem_bram),
		
		.mem_rcrt(mem_rcrt),
	
		.rom0(rom0_bus),
		.rom1(rom1_bus),
		.sram(sram_bus),
		.bram(bram_bus)
	);
`else
//************************************************************************************* slave mode memory
	MemIO #(.DW(16),  .AW(23), .RO(0)) mem_cart_rom();
	MemIO #(.DW(16),  .AW(18), .RO(0)) mem_cart_brm();
	
	
	assign rom0_do_map 					= mem_cart_rom.dato[15:0];
	assign mem_cart_rom.dati[15:0] 	= rom0_map.dati[15:0];
	assign mem_cart_rom.addr[22:0]	= rom0_map.addr[22:0];
	
	assign mem_cart_rom.oe				= rom0_map.oe;
	assign mem_cart_rom.we_lo			= rom0_map.we_lo;
	assign mem_cart_rom.we_hi			= rom0_map.we_hi;
	
	
	assign bram_do_map 					= mem_cart_brm.dato[15:0];
	assign mem_cart_brm.dati[15:0] 	= bram_map.dati[15:0];
	assign mem_cart_brm.addr[17:0]	= bram_map.addr[17:0];
	
	assign mem_cart_brm.oe				= bram_map.oe;
	assign mem_cart_brm.we_lo			= bram_map.we_lo;
	assign mem_cart_brm.we_hi			= bram_map.we_hi;
	
	wire slave_mode = 1;
	
	mcd_memory_slave mcd_mem_inst(
	
		.clk(mai.clk),
	
		.mem_prg(mem_prg),
		.mem_wrm0(mem_wrm0),
		.mem_wrm1(mem_wrm1),
		.mem_pcm(mem_pcm),
		.mem_bios(mem_bios),
		.mem_bram(mem_bram),
		
		.mem_cart_rom(mem_cart_rom),
		.mem_cart_brm(mem_cart_brm),
	
		.rom0(rom0_bus),
		.rom1(rom1_bus),
		.sram(sram_bus),
		.bram(bram_bus)
	);
`endif
 
endmodule
 