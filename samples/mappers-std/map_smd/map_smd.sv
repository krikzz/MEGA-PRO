

module map_smd(
	input  MapIn mai,
	output MapOut mao
);

	CpuBus cpu;
	assign cpu = mai.cpu;
	
	BramIO brm_off;
	BramIO brmx;
	BramIO srm;
	BramIO eep;
//************************************************************************************* config	
	assign mao.dtack 		= map_10m_xt & !cpu.as;// ? 0 : 1;
	assign mao.mask_off 	= 0;

	MemBus rom0(mao.rom0, mai.rom0_do);
	MemBus rom1(mao.rom1, mai.rom1_do);
	MemBus bram(mao.bram, mai.bram_do);
//************************************************************************************* mapper logic

	assign rom0.addr[22:0]		= cpu.addr[22:0];
	assign rom0.oe					= rom_ce[0] & !cpu.oe;
	
	assign rom1.addr[22:0]		= cpu.addr[22:0];
	assign rom1.oe					= rom_ce[1] & !cpu.oe;
	
	
	assign mao.map_oe 			= rom_ce[1:0] != 0 & !cpu.oe;
	
	assign mao.map_do[15:0]	= 
	brm_bus_oe   	? brm_bus_do[15:0] :
	rom_ce[1] 		? rom1.dato[15:0] :
						  rom0.dato[15:0];
	
	
	wire [1:0]rom_ce;
	assign rom_ce[0] 	= map_10m_on ? !cpu.ce_hi : !cpu.ce_lo;
	assign rom_ce[1] 	= map_10m_xt;
	
	wire map_10m_on 	= mai.cfg.map_idx == `MAP_10M;
	wire map_10m_xt 	= map_10m_on & cpu.addr[23:21] == 3'b100;
	

	assign mao.led_r = srm.led | eep.led;
	//assign mao.led_g	= 1;
//************************************************************************************* bram mappin
	wire brm_bus_oe 			= eep.bus_oe | srm.bus_oe;
	wire [15:0]brm_bus_do	= eep.bus_oe ? eep.dato : srm.dato;
	
	assign brmx = 
	eep.ce ? eep : 
	srm.ce ? srm : 
	brm_off;
	
	assign bram.dati[15:0] 	= brmx.dati[15:0];
	assign bram.addr[18:0] 	= brmx.addr[18:0];
	assign bram.oe				= brmx.oe;
	assign bram.we_lo			= brmx.we_lo;
	assign bram.we_hi			= brmx.we_hi;
	
	assign brm_off = '{default:0};

//************************************************************************************* sram
	
	bram_srm_smd srm_inst(
		
		.mai(mai),
		.brm_oe(srm.bus_oe),
		.brm_do(srm.dato[15:0]),
		
		.mem_do(bram.dato[15:0]),
		.mem_di(srm.dati[15:0]),
		.mem_addr(srm.addr[18:0]),
		.mem_ce(srm.ce),
		.mem_oe(srm.oe), 
		.mem_we_lo(srm.we_lo), 
		.mem_we_hi(srm.we_hi),
		.led(srm.led)
	);
//************************************************************************************* eeprom 24x
	
	bram_eep24x eep24x_inst(
		
		.mai(mai),
		.brm_oe(eep.bus_oe),
		.brm_do(eep.dato[15:0]),
		
		.mem_do(bram.dato[15:0]),
		.mem_di(eep.dati[15:0]),
		.mem_addr(eep.addr[18:0]),
		.mem_ce(eep.ce),
		.mem_oe(eep.oe), 
		.mem_we_lo(eep.we_lo), 
		.mem_we_hi(eep.we_hi),
		.led(eep.led)
	);

endmodule



