
module map_mcd(

	input  MapIn mai,
	output MapOut mao
);
	

	CpuBus cpu;
	assign cpu 	= mai.cpu;
	wire clk		= mai.clk;
//************************************************************************************* config			
	assign mao.dtack 			= cpu.addr == 'hc00022 & !cpu.as;//fix for sonic megamix
	assign mao.mask_off 		= 1;
	assign mao.cart			= 0;//will broke compatibility wit cdx if 1
	
	MemBus brm(mao.bram, mai.bram_do);
//*************************************************************************************
	assign mao.map_oe 		= bram_oe & !cpu.oe;
	assign mao.map_do[15:0] = bram_do[15:0];

	
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
		.cart_on(mai.cfg.brm_msk != 0),
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

