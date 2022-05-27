


module map_nom(
	
	EDBus ed,
	output MapOut mout
);
	
	wire clk   = ed.clk;
	
	CpuBus cpu;
	assign cpu = ed.cpu;
//************************************************************************************* config	
	assign mout.dtack 		= 1;
	assign mout.mask_off 	= 1;

	MemBus rom(mout.rom0, ed.rom0_do);
//************************************************************************************* pi-io
	assign mout.pi_di[7:0]		= `MAP_MOD_NSP;//mapper not supported
//************************************************************************************* mapper logic
	assign rom.dati[15:0]		= 0;
	assign rom.addr[22:0]		= cpu.addr[22:0];
	assign rom.oe					= !cpu.ce_lo & !cpu.oe_as;
	
	assign mout.map_oe 			= rom.oe;
	assign mout.map_do[15:0]	= rom.dato[15:0];
	assign mout.led_r 			= ctr[25];
	
	
	reg [25:0]ctr;
	
	always @(negedge clk)
	begin
		ctr <= ctr + 1;
	end
	
endmodule

