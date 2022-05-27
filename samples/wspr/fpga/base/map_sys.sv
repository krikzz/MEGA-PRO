


module map_sys(
	EDBus ed,
	output MapOut mout
);
	

	CpuBus cpu;
	assign cpu = ed.cpu;
	wire clk		= ed.clk;
//************************************************************************************* config
	assign mout.dtack 		= 1;
	assign mout.mask_off 	= 1;

	MemBus rom(mout.rom1, ed.rom1_do);
//*************************************************************************************
	
	assign rom.dati[15:0]	= cpu.data[15:0];
	assign rom.addr[22:0]	= ibuf_ce ? {4'hE, cpu.addr[18:0]} : {4'hF, cpu.addr[18:0]};
	assign rom.oe				= mem_ce & !cpu.oe;
	assign rom.we_lo			= (ram_ce | ibuf_ce) & !cpu.we_lo;
	assign rom.we_hi			= (ram_ce | ibuf_ce) & !cpu.we_hi;
	
	
	assign mout.map_oe 		= mem_ce & !cpu.oe;
	assign mout.map_do		= rom.dato[15:0];	
	assign mout.led_r 		= ed.sst.act;
	
	
	wire cart_ce = !cpu.ce_lo & !ed.sys_rst;
	wire mem_ce  = cart_ce & (rom_ce | ram_ce | ibuf_ce);
	wire rom_ce  = cart_ce & cpu.addr[23:18] == 0;//256K
	wire ram_ce  = cart_ce & cpu.addr[23:18] == 1;//256K
	wire ibuf_ce = cart_ce & cpu.addr[23:19] == 1;//512K io buffer. mostly for save states
//************************************************************************************* dac mute
	assign mout.dac.mclk = ctr[1];
	assign mout.dac.sclk = 1;
	assign mout.dac.lrck = ctr[9];
	assign mout.dac.sdin = 0;
	
	reg [15:0]ctr;
	reg mute_req;
	
	always @(negedge clk)
	begin
		
		if(ed.cfg.ct_gmode)
		begin
			mute_req <= ed.map.snd_use;
		end
		
		if(mute_req)ctr <= ctr + 1;
			else
		ctr <= 0;	
		
	end
	

endmodule



