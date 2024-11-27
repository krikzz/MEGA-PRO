


module map_sys(
	input  MapIn mai,
	output MapOut mao
);
	

	CpuBus cpu;
	assign cpu 	= mai.cpu;
	wire clk		= mai.clk;
//************************************************************************************* config
	assign mao.mask_off 	= 1;
	
`ifdef HWC_ROM1_OFF
	MemBus rom(mao.rom0, mai.rom0_do);
`elsif HWC_ROM1_ON
	MemBus rom(mao.rom1, mai.rom1_do);
`else
	"undefined hardware config"
`endif		
//*************************************************************************************
	
	assign rom.dati[15:0]	= cpu.data[15:0];
	assign rom.addr[22:0]	= ibuf_ce ? {4'hE, cpu.addr[18:0]} : {4'hF, cpu.addr[18:0]};
	assign rom.oe				= mem_ce & !cpu.oe;
	assign rom.we_lo			= (ram_ce | ibuf_ce) & !cpu.we_lo;
	assign rom.we_hi			= (ram_ce | ibuf_ce) & !cpu.we_hi;
	
	
	assign mao.map_oe 		= mem_ce & !cpu.oe;
	assign mao.map_do			= rom.dato[15:0];	
	assign mao.led_r 			= mai.sst.act;
	
	
	wire cart_ce 	= !cpu.ce_lo & !mai.sys_rst;
	wire mem_ce 	= cart_ce & (rom_ce | ram_ce | ibuf_ce);
	wire rom_ce  	= cart_ce & cpu.addr[23:18] == 0;//256K
	wire ram_ce  	= cart_ce & cpu.addr[23:18] == 1;//256K
	wire ibuf_ce 	= cart_ce & cpu.addr[23:19] == 1;//512K io buffer. mostly for save states

endmodule
