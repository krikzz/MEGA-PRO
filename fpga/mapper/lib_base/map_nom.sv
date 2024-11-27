


module map_nom(
	
	input  MapIn mai,
	output MapOut mao
);
	
	wire clk   = mai.clk;
	
	CpuBus cpu;
	assign cpu = mai.cpu;
//************************************************************************************* config	
	assign mao.mask_off 			= 1;
	assign mao.map_nsp			= 1;//unsupported mapper detection

	MemBus rom(mao.rom0, mai.rom0_do);
//************************************************************************************* mapper logic
	assign rom.dati[15:0]		= 0;
	assign rom.addr[22:0]		= cpu.addr[22:0];
	assign rom.oe					= !cpu.ce_lo & !cpu.oe;
	
	assign mao.map_oe 			= rom.oe;
	assign mao.map_do[15:0]		= rom.dato[15:0];
	assign mao.led_r 				= ctr[25];
	
	
	reg [25:0]ctr;
	
	always @(posedge clk)
	begin
		ctr <= ctr + 1;
	end
	
endmodule

