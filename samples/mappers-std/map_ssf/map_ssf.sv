

module map_ssf(

	input  MapIn mai,
	output MapOut mout
);
	
	wire clk = mai.clk;
	
	CpuBus cpu;
	assign cpu = mai.cpu;
	
	SSTBus sst;
	assign sst = mai.sst;
//************************************************************************************* config	
	assign mout.mask_off 	= 1;

	MemBus rom0(mout.rom0, mai.rom0_do);
	MemBus rom1(mout.rom1, mai.rom1_do);
	MemBus bram(mout.bram, mai.bram_do);
//************************************************************************************* save state
	assign mout.sst_di[7:0] = 
	sst.addr  < 8 ? ssf_bank[sst.addr[2:0]]: 
	sst.addr == 8 ? ssf_ctrl : 
	8'hff;	
//*************************************************************************************
	
	assign rom0.dati[15:0] 	= cpu.data[15:0];
	assign rom0.addr[22:0] 	= rom_addr[22:0];
	assign rom0.oe 			= rom_ce & !cpu_oe & mem_ce == 0;
	assign rom0.we_lo 		= rom_ce & !cpu.we_lo & mem_ce == 0 & wr_on;
	assign rom0.we_hi			= rom_ce & !cpu.we_hi & mem_ce == 0 & wr_on;
	
	assign rom1.dati[15:0] 	= cpu.data[15:0];
	assign rom1.addr[22:0] 	= rom_addr[22:0];
	assign rom1.oe 			= rom_ce & !cpu_oe & mem_ce == 1;
	assign rom1.we_lo 		= rom_ce & !cpu.we_lo & mem_ce == 1 & wr_on;
	assign rom1.we_hi 		= rom_ce & !cpu.we_hi & mem_ce == 1 & wr_on;
	
	assign bram.dati[15:0] 	= cpu.data[15:0];
	assign bram.addr[22:0] 	= rom_addr[22:0];
	assign bram.oe 			= rom_ce & !cpu_oe & mem_ce == 2;
	assign bram.we_lo 		= rom_ce & !cpu.we_lo & mem_ce == 2 & wr_on;
	assign bram.we_hi 		= rom_ce & !cpu.we_hi & mem_ce == 2 & wr_on;
	

	
	assign mout.map_oe 		= rom_ce & !cpu_oe;
	assign mout.map_do[15:0] = 
	mem_ce == 0 ? rom0.dato[15:0] : 
	mem_ce == 1 ? rom1.dato[15:0] : 
					  bram.dato[15:0];
	
	wire cpu_oe 			= cpu.oe;
	wire rom_ce 			= !cpu.ce_lo;
	
	wire [1:0]mem_ce = 
	rom_addr[23] == 0 			 ? 0 :
	rom_addr[23:19] != 5'b11111 ? 1 :
											2;
	
	wire [23:0]rom_addr 	= {ssf_bank[cpu.addr[21:19]][4:0], cpu.addr[18:0]};
	wire ssf_regs_ce 		= !cpu.tim & {cpu.addr[7:4], 4'd0} == 8'hF0;
	
	
	
	assign cart 			= ssf_ctrl[0];
	assign led_r 			= ssf_ctrl[1];
	wire wr_on 				= ssf_ctrl[2];
	
	reg [4:0]ssf_bank[8];
	reg [3:0]ssf_ctrl;
	
	always @(negedge clk)
	if(mai.map_rst)
	begin
		
		ssf_bank[0] <= 0;
		ssf_bank[1] <= 1;
		ssf_bank[2] <= 2;
		ssf_bank[3] <= 3;
		ssf_bank[4] <= 4;
		ssf_bank[5] <= 5;
		ssf_bank[6] <= 6;
		ssf_bank[7] <= 7;
		
		ssf_ctrl 	<= 0;
	end
		else
	if(sst.act)
	begin
		if(sst.we_map & sst.addr  < 8)ssf_bank[sst.addr[2:0]]	<= sst.dato;
		if(sst.we_map & sst.addr == 8)ssf_ctrl 					<= sst.dato;
	end
		else
	if(ssf_regs_we)
	begin
		
		if(cpu.addr[3:0] == 0 & cpu.data[15])
		begin
			ssf_bank[0][4:0] 	<= cpu.data[4:0];
			ssf_ctrl[3:0] 		<= cpu.data[14:11];
		end
		
		if(cpu.addr[3:0] != 0)ssf_bank[cpu.addr[3:1]][4:0] <= cpu.data[4:0];
		
	end
	
	wire ssf_regs_we;
	sync_edge sync_inst(.clk(clk), .ce(ssf_regs_ce & !cpu.we_lo), .sync(ssf_regs_we));
	
	
endmodule


