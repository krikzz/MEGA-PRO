

module mcd_memory_slave(
	
	input clk,
	
	MemIO 	mem_prg,
	MemIO_WR mem_wrm0,
	MemIO_WR mem_wrm1,
	MemIO   	mem_pcm,
	MemIO   	mem_bios,
	MemIO   	mem_bram,
	
	MemIO   	mem_cart_rom,
	MemIO   	mem_cart_brm,
	
	MemBus rom0,
	MemBus rom1,
	MemBus sram,
	MemBus bram
);

	
	
//********************************************************** wram		
	wram_dp wram_inst(
		
		.clk(clk),
		
		.dout(sram.dato[15:0]),
		.din(sram.dati[15:0]),
		.addr(sram.addr[18:1]),
		.oe(sram.oe), 
		.we_lo(sram.we_lo),
		.we_hi(sram.we_hi),
		
		
		.din_a(mem_wrm0.dati),
		.dout_a(mem_wrm0.dato),
		.addr_a({1'b0, mem_wrm0.addr[16:1]}),
		.mask_a(mem_wrm0.mask),
		.mode_a(mem_wrm0.mode),
		
		.din_b(mem_wrm1.dati),
		.dout_b(mem_wrm1.dato),
		.addr_b({1'b1, mem_wrm1.addr[16:1]}),
		.mask_b(mem_wrm1.mask),
		.mode_b(mem_wrm1.mode)
		
	);
	

//********************************************************** prg	
	assign mem_prg.dato[15:0] 	= rom1.dato[15:0];
	assign rom1.dati[15:0] 		= mem_prg.dati[15:0];
	assign rom1.addr[18:0]		= mem_prg.addr[18:0];
	assign rom1.oe					= mem_prg.oe;
	assign rom1.we_lo				= mem_prg.we_lo;
	assign rom1.we_hi				= mem_prg.we_hi;
	
//********************************************************** rom
	assign mem_cart_rom.dato 	= rom0.dato[15:0];
	assign rom0.dati[15:0] 		= mem_cart_rom.dati[15:0];
	assign rom0.addr[22:0]		= mem_cart_rom.addr[22:0];
	assign rom0.oe					= mem_cart_rom.oe;
	assign rom0.we_lo				= mem_cart_rom.we;
	assign rom0.we_hi				= mem_cart_rom.we;
//********************************************************** bram
	ram_bram bram_inst(

		.din(mem_bram.dati),
		.dout(mem_bram.dato),
		.addr(mem_bram.addr[12:0]),
		.we(mem_bram.we),
		.clk(clk)
	);	
//**********************************************************cart bram bus sync
	MemIO #(.DW(16),  .AW(18), .RO(0)) mem_cart_brm_s();
	
	assign mem_cart_brm_s.dati	= mem_cart_brm.dati;
	assign mem_cart_brm_s.addr = mem_cart_brm.addr;
	
	reg cart_we_ack;//extra delay for wr ops is required
	
	always @(negedge clk)
	begin
		cart_we_ack				<= mem_cart_brm.we_lo | mem_cart_brm.we_hi;
		//mem_cart_brm_s.dati 		<= mem_cart_brm.dati;
		//mem_cart_brm_s.addr 		<= mem_cart_brm.addr;
		mem_cart_brm_s.oe 	<= mem_cart_brm.oe;
		mem_cart_brm_s.we_lo <= mem_cart_brm.we_lo & cart_we_ack;
		mem_cart_brm_s.we_hi	<= mem_cart_brm.we_hi & cart_we_ack;
	end
//**********************************************************

	
	MemIO #(.DW(16),  .AW(19), .RO(0)) mem_main();
	
	assign mem_bios.dato 		=  mem_main.dato;
	assign mem_cart_brm.dato 	= 	mem_main.dato;
	
	//256K 	cart bram
	//64K		pcm ram
	//64K 	unused
	//128K 	bios
	assign mem_main.dati[15:0] 	= mem_bios.oe ? 0 : mem_cart_brm_s.dati;
	assign mem_main.addr[18:0] 	= mem_bios.oe ? (mem_bios.addr[16:0] | 'h60000) : (mem_cart_brm_s.addr[17:0] | 'h00000);
	assign mem_main.oe 				= mem_bios.oe ? mem_bios.oe : mem_cart_brm_s.oe;
	assign mem_main.we_lo 			= mem_bios.oe ? 0 : mem_cart_brm_s.we_lo;
	assign mem_main.we_hi 			= mem_bios.oe ? 0 : mem_cart_brm_s.we_hi;
	
	
	MemIO #(.DW(16),  .AW(16), .RO(0)) pcm16();
	
	mem_8_to_16_mio(.mem8(mem_pcm), .mem16(pcm16));
	
	ram_dp_60 bios_db_bram(
		
		.clk(clk),
		
		.dout(bram.dato[15:0]),
		.din(bram.dati[15:0]),
		.addr(bram.addr[22:0]),
		.oe(bram.oe), 
		.we_lo(bram.we_lo), 
		.we_hi(bram.we_hi),
		
		//cart bram and bios
		.din_a(mem_main.dati),
		.dout_a(mem_main.dato),
		.addr_a(mem_main.addr),
		.oe_a(mem_main.oe),
		.we_lo_a(mem_main.we_lo),
		.we_hi_a(mem_main.we_hi),
		
		//pcm
		.din_b(pcm16.dati),
		.dout_b(pcm16.dato),
		.addr_b(pcm16.addr[15:0] | 'h40000),//map pcm to upper 256K
		.oe_b(pcm16.oe), 
		.we_lo_b(pcm16.we_lo),
		.we_hi_b(pcm16.we_hi)
	);
	
	
endmodule

//**************************************************************************************
//**************************************************************************************
//**************************************************************************************
//**************************************************************************************
//**************************************************************************************

module mcd_memory_master(
	
	input clk,
	
	MemIO 	mem_prg,
	MemIO_WR mem_wrm0,
	MemIO_WR mem_wrm1,
	MemIO   	mem_pcm,
	MemIO   	mem_bios,
	MemIO   	mem_bram,
	
	MemIO   	mem_rcrt,
	
	MemBus rom0,
	MemBus rom1,
	MemBus sram,
	MemBus bram
);

	
	
//********************************************************** wram		
	wram_dp wram_inst(
		
		.clk(clk),
		
		.dout(sram.dato[15:0]),
		.din(sram.dati[15:0]),
		.addr(sram.addr[18:1]),
		.oe(sram.oe), 
		.we_lo(sram.we_lo),
		.we_hi(sram.we_hi),
		
		
		.din_a(mem_wrm0.dati),
		.dout_a(mem_wrm0.dato),
		.addr_a({1'b0, mem_wrm0.addr[16:1]}),
		.mask_a(mem_wrm0.mask),
		.mode_a(mem_wrm0.mode),
		
		.din_b(mem_wrm1.dati),
		.dout_b(mem_wrm1.dato),
		.addr_b({1'b1, mem_wrm1.addr[16:1]}),
		.mask_b(mem_wrm1.mask),
		.mode_b(mem_wrm1.mode)
		
	);
	

//********************************************************** prg	
	assign mem_prg.dato[15:0] 	= rom1.dato[15:0];
	assign rom1.dati[15:0] 		= mem_prg.dati[15:0];
	assign rom1.addr[18:0]		= mem_prg.addr[18:0];
	assign rom1.oe					= mem_prg.oe;
	assign rom1.we_lo				= mem_prg.we_lo;
	assign rom1.we_hi				= mem_prg.we_hi;	

	
//********************************************************** pcm
	assign mem_pcm.dato[7:0] 	= rom0.dato[7:0];
	assign rom0.dati[7:0] 		= mem_pcm.dati[7:0];
	assign rom0.addr[16:1]		= mem_pcm.addr[15:0];
	assign rom0.oe					= mem_pcm.oe;
	assign rom0.we_lo				= mem_pcm.we;
	assign rom0.we_hi				= mem_pcm.we;
	
//**********************************************************ram cart bus sync 
	MemIO #(.DW(16),  .AW(18), .RO(0)) mem_rcrt_s();

	assign mem_rcrt_s.dati	= mem_rcrt.dati;
	assign mem_rcrt_s.addr 	= mem_rcrt.addr;
	
	reg cart_we_ack;//extra delay for wr ops is required
	
	always @(negedge clk)
	begin
		cart_we_ack			<= mem_rcrt.we_lo | mem_rcrt.we_hi;
		//mem_rcrt_s.dati 	<= mem_rcrt.dati;
		//mem_rcrt_s.addr 	<= mem_rcrt.addr;
		mem_rcrt_s.oe 		<= mem_rcrt.oe;
		mem_rcrt_s.we_lo 	<= mem_rcrt.we_lo & cart_we_ack;
		mem_rcrt_s.we_hi 	<= mem_rcrt.we_hi & cart_we_ack;
	end
//**********************************************************

	
	MemIO #(.DW(16),  .AW(19), .RO(0)) mem_main();
	
	assign mem_bios.dato 	=  mem_main.dato;
	assign mem_rcrt.dato 	= 	mem_main.dato;
	
	//256K 	ram cart
	//8K		cd-bram
	//120K 	unused
	//128K 	bios
	assign mem_main.dati[15:0] 	= mem_bios.oe ? 0 : mem_rcrt_s.dati;
	assign mem_main.addr[18:0] 	= mem_bios.oe ? {2'b11, mem_bios.addr[16:0]} : {1'b0, mem_rcrt_s.addr[17:0]};
	assign mem_main.oe 				= mem_bios.oe ? mem_bios.oe : mem_rcrt_s.oe;
	assign mem_main.we_lo 			= mem_bios.oe ? 0 : mem_rcrt_s.we_lo;
	assign mem_main.we_hi 			= mem_bios.oe ? 0 : mem_rcrt_s.we_hi;
	
	
	MemIO #(.DW(16),  .AW(13), .RO(0)) bram16();
	
	mem_8_to_16_mio(.mem8(mem_bram), .mem16(bram16));
	
	ram_dp_60 bios_db_bram(
		
		.clk(clk),
		
		.dout(bram.dato[15:0]),
		.din(bram.dati[15:0]),
		.addr(bram.addr[22:0]),
		.oe(bram.oe), 
		.we_lo(bram.we_lo), 
		.we_hi(bram.we_hi),
		
		//cart bram and bios
		.din_a(mem_main.dati),
		.dout_a(mem_main.dato),
		.addr_a(mem_main.addr),
		.oe_a(mem_main.oe),
		.we_lo_a(mem_main.we_lo),
		.we_hi_a(mem_main.we_hi),
		
		//cd bram
		.din_b(bram16.dati),
		.dout_b(bram16.dato),
		.addr_b(bram16.addr[12:0] | 'h40000),//map bram to upper 256K
		.oe_b(bram16.oe), 
		.we_lo_b(bram16.we_lo),
		.we_hi_b(bram16.we_hi)
	);
	
endmodule


//**************************************************************************************
//**************************************************************************************
//**************************************************************************************
//**************************************************************************************
//**************************************************************************************

module mem_8_to_16_mio(
	MemIO mem16,
	MemIO mem8
);

	mem_8_to_16 bram16(
	
		.dout_16(mem16.dato),
		.din_16(mem16.dati),
		.addr_16(mem16.addr),
		.oe_16(mem16.oe), 
		.we_lo_16(mem16.we_lo), 
		.we_hi_16(mem16.we_hi),
	
		.dout_8(mem8.dato),
		.din_8(mem8.dati),
		.addr_8(mem8.addr),
		.oe_8(mem8.oe), 
		.we_8(mem8.we)
	);
	
endmodule


module ram_dp_60(
	
	input clk,
	
	input [15:0]dout,
	output [15:0]din,
	output [22:0]addr,
	output reg oe, we_lo, we_hi,
	
	input [15:0]din_a,
	output reg [15:0]dout_a,
	input [22:0]addr_a,
	input oe_a, we_lo_a, we_hi_a,
	
	input [15:0]din_b,
	output reg [15:0]dout_b,
	input [22:0]addr_b,
	input oe_b, we_lo_b, we_hi_b

);
	parameter MEM_A 	= 0;
	parameter MEM_B 	= 1;
	
	
	assign addr 		=  mem_sw == MEM_A ? addr_a : addr_b;
	assign din 			=  mem_sw == MEM_A ? din_a  : din_b;
	
	wire rw_a 			= (prior == MEM_A & mem_req_a) | (prior == MEM_B & mem_req_a & !mem_req_b);
	wire rw_b 			= (prior == MEM_B & mem_req_b) | (prior == MEM_A & mem_req_b & !mem_req_a);
	
	reg mem_ack_a, mem_ack_b;
	reg [2:0]delay;
	reg mem_sw;
	reg prior;
	
	always @(negedge clk)
	begin
		
		if(delay)delay 			<= delay - 1;
		if(mem_ack_a)mem_ack_a 	<= 0;
		if(mem_ack_b)mem_ack_b 	<= 0;
		
		if(delay == 0 & (we_lo | we_hi))
		begin
			we_lo <= 0;
			we_hi <= 0;
		end
		
		if(delay == 0 & oe)
		begin
			if(mem_sw == MEM_A)dout_a <= dout;
			if(mem_sw == MEM_B)dout_b <= dout;
		end
		
				
		if(rw_a & delay == 0 & !we_lo & !we_hi)
		begin
			mem_ack_a 	<= 1;
			oe 			<= oe_a;
			we_lo 		<= we_lo_a;
			we_hi 		<= we_hi_a;
			mem_sw 		<= MEM_A;
			prior 		<= MEM_B;
			delay 		<= 2;
		end
		
		if(rw_b & delay == 0 & !we_lo & !we_hi)
		begin
			mem_ack_b 	<= 1;
			oe 			<= oe_b;
			we_lo 		<= we_lo_b;
			we_hi 		<= we_hi_b;
			mem_sw 		<= MEM_B;
			prior 		<= MEM_A;
			delay 		<= 2;
		end
		
		
	end
	

	wire mem_req_a, mem_req_b;
	
	mem_req req_a(
		.clk(clk),
		.req(oe_a | we_lo_a | we_hi_a),
		.ack(mem_ack_a), 
		.req_pend(mem_req_a)
	);
	
	mem_req req_b(
		.clk(clk),
		.req(oe_b | we_lo_b | we_hi_b),
		.ack(mem_ack_b), 
		.req_pend(mem_req_b)
	);
	
endmodule



module mem_req(
	input clk,
	input req, 
	input ack, 
	output req_pend
);

	assign req_pend = (pend | req_edge) & !ack;
	
	wire req_edge = req & !req_st;
	
	reg req_st;
	reg pend;
	
	always @(negedge clk)
	begin
	
		req_st <= req;
		
		if(ack)pend <= 0;
			else
		if(req_edge)pend <= 1;
		
	end
	
endmodule




module wram_dp(

	input clk,
	
	input [15:0]dout,
	output [15:0]din,
	output reg [17:0]addr,
	output oe, we_lo, we_hi,
	
	input [15:0]din_a,
	output reg [15:0]dout_a,
	input [17:0]addr_a,
	input [3:0]mask_a,
	input [2:0]mode_a,
	
	input [15:0]din_b,
	output reg [15:0]dout_b,
	input [17:0]addr_b,
	input [3:0]mask_b,
	input [2:0]mode_b
	
);

	assign oe = ram_oe;
	assign we_lo = ram_we;//& !clk;
	assign we_hi = ram_we;// & !clk;

	assign din[15:0] = dbuf[15:0];
	
	reg ram_oe, ram_we;
	reg [15:0]dbuf;
	
	reg [3:0]mask_st;
	reg [2:0]mode_st;
	
	
	wire [3:0]mod_msk;
	assign mod_msk[3] = mode_st == 0 | !mask_st[3] ? mask_st[3] : mode_st[0] ? dout[15:12] == 0 : dbuf[15:12] != 0;
	assign mod_msk[2] = mode_st == 0 | !mask_st[2] ? mask_st[2] : mode_st[0] ? dout[11:8] == 0 : dbuf[11:8] != 0;
	assign mod_msk[1] = mode_st == 0 | !mask_st[1] ? mask_st[1] : mode_st[0] ? dout[7:4] == 0 : dbuf[7:4] != 0;
	assign mod_msk[0] = mode_st == 0 | !mask_st[0] ? mask_st[0] : mode_st[0] ? dout[3:0] == 0 : dbuf[3:0] != 0;
	
	reg [1:0]state;
	
	
	always @(negedge clk)
	begin
		
		
		case(state)
			0:begin
				ram_we <= 0;
				if(ram_we == 0)
				begin
					ram_oe 		<= 1;
					addr[17:0] 	<= addr_a[17:0];
					dbuf[15:0] 	<= din_a[15:0];
					mask_st 		<= mask_a;
					mode_st 		<= mode_a;
					state 		<= state + 1;
				end
			end
			1:begin
				ram_we			<= mask_st != 0;// & mask_st == mask_a & mode_st == mode_a;
				ram_oe 			<= 0;
				dout_a[15:0] 	<= dout[15:0];
				if(mod_msk[3] == 0)dbuf[15:12]	<= dout[15:12];
				if(mod_msk[2] == 0)dbuf[11:8] 	<=  dout[11:8];
				if(mod_msk[1] == 0)dbuf[7:4] 		<= dout[7:4];
				if(mod_msk[0] == 0)dbuf[3:0] 		<= dout[3:0];
				state 									<= state + 1;
			end
			2:begin
				ram_we <= 0;
				if(ram_we == 0)
				begin
					ram_oe 		<= 1;
					addr[17:0] 	<= addr_b[17:0];
					dbuf[15:0] 	<= din_b[15:0];
					mask_st 		<= mask_b;
					mode_st 		<= mode_b;
					state 		<= state + 1;
				end
			end
			3:begin
				ram_we <= mask_st != 0;// & mask_st == mask_b & mode_st == mode_b;
				ram_oe <= 0;
				dout_b[15:0] <= dout[15:0];
				if(mod_msk[3] == 0)dbuf[15:12] 	<= dout[15:12];
				if(mod_msk[2] == 0)dbuf[11:8] 	<=  dout[11:8];
				if(mod_msk[1] == 0)dbuf[7:4] 		<= dout[7:4];
				if(mod_msk[0] == 0)dbuf[3:0] 		<= dout[3:0];
				state 									<= state + 1;
			end
		endcase
		
	end

endmodule
