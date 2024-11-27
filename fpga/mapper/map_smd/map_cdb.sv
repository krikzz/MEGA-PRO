

module map_cdb(

	input  MapIn mai,
	output MapOut mao
);
	

	CpuBus cpu;
	assign cpu 	= mai.cpu;
	wire clk		= mai.clk;
//************************************************************************************* config		
	assign mao.cart 		= bios_ce ? 0 : 1;
	assign mao.mask_off 	= 0;
	
	
	MemBus rom(mao.rom0, mai.rom0_do);
	MemBus brm(mao.bram, mai.bram_do);
//*************************************************************************************


	assign rom.addr[22:0] 	= cpu.addr[22:0];
	assign rom.oe 				= mao.map_oe;
	
	assign mao.map_oe 		= (bios_ce | bram_oe) & !cpu.oe;
	
	assign mao.map_do[15:0] = 
	bram_oe ? bram_do[15:0] :
				 rom.dato[15:0];

	wire bios_ce 				= cpu.addr[23:17] == 0 & !hint_ce & !cpu.oe;
	wire hint_ce 				= {cpu.addr[16:2], 2'd0} == 17'h70 & !cpu.as;
	
	
	wire [15:0]bram_do;
	wire bram_oe;

`ifdef HWC_RAMCART128
	wire rcart_size	= 0;
`elsif HWC_RAMCART256
	wire rcart_size	= 1;
`else
	"undefined hardware config"
`endif	

	
	ram_cart ram_cart_inst(


		.mai(mai),
		.cart_on(1),
		.size(rcart_size),
		
		.cart_dout(bram_do[15:0]),
		.cart_oe(bram_oe),
		
		.mem_dout(brm.dato[15:0]),
		.mem_din(brm.dati[15:0]),
		.mem_addr(brm.addr[17:0]),
		.mem_oe(brm.oe), 
		.mem_we_lo(brm.we_lo), 
		.mem_we_hi(brm.we_hi)
		
	);


endmodule

