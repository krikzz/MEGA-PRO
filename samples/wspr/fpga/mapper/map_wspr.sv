
module map_wspr(
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
	MemBus ram(mout.bram, ed.bram_do);
//************************************************************************************* mapper logic
	assign rom.dati[15:0]		= 0;
	assign rom.addr[22:0]		= cpu.addr[22:0];
	assign rom.oe					= cpu.addr[21] == 0 & !cpu.ce_lo & !cpu.oe_as;
	
	assign ram.dati[15:0]		= cpu.data;
	assign ram.addr[22:0]		= cpu.addr[22:0];
	assign ram.oe					= cpu.addr[21] == 1 & !cpu.ce_lo & !cpu.oe_as;
	assign ram.we_lo				= cpu.addr[21] == 1 & !cpu.ce_lo & !cpu.we_lo;
	assign ram.we_hi				= cpu.addr[21] == 1 & !cpu.ce_lo & !cpu.we_hi;
	
	assign mout.map_oe 			= rom.oe | ram.oe;
	assign mout.map_do[15:0]	= rom.oe ? rom.dato[15:0] : ram.dato[15:0];
	

	assign mout.led_g = ctrl_tdx_on;
	
//************************************************************************************* host control registers
	wire reg_ce			= !cpu.tim & {cpu.addr[7:4], 4'd0} == 8'hF0;
	wire reg_we 		= reg_ce & !cpu.we_lo;
	wire reg_we_edge 	= reg_we_st[2:0] == 'b011;
		
	
	reg [31:0]reg_finc;
	reg [31:0]reg_frat;
	reg [15:0]reg_fsks;
	reg [15:0]reg_txpo;
	reg [15:0]reg_data;
	reg [15:0]reg_ctrl;
	
	reg [2:0]reg_we_st;
	
	always @(negedge clk)
	begin
		
		reg_we_st[2:0] <={reg_we_st[1:0], reg_we};
		
		if(reg_we_edge)
		case(cpu.addr[3:0])
			'h0:reg_frat[31:16]	<= cpu.data;
			'h2:reg_frat[15:0] 	<= cpu.data;
			'h4:reg_finc[31:16]	<= cpu.data;
			'h6:reg_finc[15:0] 	<= cpu.data;
			'h8:reg_fsks[15:0] 	<= cpu.data;
			'hA:reg_txpo[15:0] 	<= cpu.data;
			'hC:reg_data[15:0] 	<= cpu.data;
			'hE:reg_ctrl[15:0] 	<= cpu.data;
		endcase
		
	end
	
	
	wire ctrl_tdx_on 			= reg_ctrl[0];
	assign mout.gp_dir[4:0] = reg_txpo[4:0];
//************************************************************************************* modulator
	reg [7:0]wspr_addr;
	reg [31:0]rctr;
	reg [25:0]tctr;
	reg [7:0]sctr;
	
	always @(negedge clk)
	if(!ctrl_tdx_on)
	begin
		sctr 			<= 0;
		tctr 			<= 0;
		rctr 			<= 0;
		wspr_addr 	<= 0;
	end
		else
	begin
	
		if(tctr == 49999999)
		begin
			sctr <= sctr == 119 ? 0 : sctr + 1;
			tctr <= 0;
		end
			else
		begin
			tctr <= tctr + 1;
		end
		
		if(tctr == 0 & sctr == 0)
		begin
			rctr 			<= 0;
			wspr_addr 	<= 0;
		end
			else
		if(rctr == 34133332)//1.4648Hz
		begin
			rctr 			<= 0;
			wspr_addr 	<= wspr_addr + 1;
		end
			else
		begin
			rctr 			<= rctr + 1;
		end
		
	end
	

	wire [1:0]tone;
	
	ram_wspr wspr_data(

		.clk_a(clk),
		.dati_a(reg_data[7:0]),
		.addr_a(reg_data[15:8]),
		.we_a(1),
		
		.clk_b(clk),
		.dato_b(tone),
		.addr_b(wspr_addr),
	);
	
	/*
	wspr_rom wspr_rom_inst(

		.clk(clk),
		.addr(wspr_addr),
		.dout(tone)
	);*/
	
	
	wire [15:0]fshift[4];
	assign fshift[0] = 0;//0*3;
	assign fshift[1] = reg_fsks;//18*3;
	assign fshift[2] = reg_fsks*2;//37*3;
	assign fshift[3] = reg_fsks*3;//55*3;
	
	reg [31:0]ratio_mod;
	
	always @(negedge clk)
	begin
		ratio_mod <= reg_frat - fshift[tone];
	end
	
//************************************************************************************* freq generator	
	wire rfbase;
	pll0 (
		.inclk0(clk),//50mhz in
		.c0(rfbase)//150mhz out
	);
	
	
	wire rfck;
	
	freq_ctr freq_ctr_inst(

		.clk(rfbase),
		.halt(!ctrl_tdx_on),
		.ck_inc(reg_finc),
		.ck_ratio(ratio_mod),
		
		.clk_out(rfck)
	);

	
	assign mout.gp_o[0] = rfck;
	assign mout.gp_o[1] = rfck;
	assign mout.gp_o[2] = rfck;
	assign mout.gp_o[3] = rfck;
	assign mout.gp_o[4] = rfck;
	
	
endmodule

module wspr_rom (

	input  clk,
	input  [7:0]addr,
	output [7:0]dout
);
  

	assign dout[7:0] = rgb_int[7:0];
	
	reg [7:0]rom[256];
	reg [7:0]rgb_int;
	
	initial
	begin
		$readmemh("wspr_new.txt", rom);
	end
	
	always @(negedge clk)
	begin
		rgb_int[7:0] <= rom[addr][7:0];
	end

endmodule


module freq_ctr(

	input clk,
	input halt,
	input [31:0]ck_inc,
	input [31:0]ck_ratio,
	
	output reg clk_out
);
	
	reg [31:0]ck_inc_st[3];
	reg [31:0]ck_ratio_st[3];
	reg halt_st;
	
	
	always @(negedge clk)
	begin
		
		halt_st 				<= halt;
		
		ck_inc_st[0] 		<= ck_inc;
		ck_ratio_st[0] 	<= ck_ratio;
		
		ck_inc_st[1] 		<= ck_inc_st[0];
		ck_ratio_st[1] 	<= ck_ratio_st[0];
		
		if(ck_inc_st[0] == ck_inc_st[1])
		begin
			ck_inc_st[2]	<= ck_inc_st[1];
		end
		
		if(ck_ratio_st[0] == ck_ratio_st[1])
		begin
			ck_ratio_st[2]	<= ck_ratio_st[1];
		end
		
	end
	
	
	reg clk_int;
	reg [31:0]clk_ctr;

	always @(negedge clk)
	if(halt_st)
	begin
			clk_ctr	<= 0;	
	end
		else
	begin
				
		if(clk_ctr >= ck_ratio_st[2])
		begin
			clk_ctr	<= clk_ctr - ck_ratio_st[2];
			clk_int 	<= !clk_int;
		end
			else
		begin
			clk_ctr 	<= clk_ctr + ck_inc_st[2];
		end
		
	end

	always @(negedge clk)
	begin
		clk_out		 <= clk_int;
	end
	

endmodule


module ram_wspr(

	input  clk_a,
	input  [7:0]dati_a,
	output reg[7:0]dato_a,
	input  [15:0]addr_a,
	input  we_a,
	
	input  clk_b,
	input  [7:0]dati_b,
	output reg[7:0]dato_b,
	input  [15:0]addr_b,
	input  we_b
);

	
	reg [7:0]ram[65536];
	
	always @(negedge clk_a)
	begin
	
		dato_a <= we_a ? dati_a : ram[addr_a];
		
		if(we_a)
		begin
			ram[addr_a] <= dati_a;
		end
		
	end
	
	always @(negedge clk_b)
	begin
	
		dato_b <= we_b ? dati_b : ram[addr_b];
		
		if(we_b)
		begin
			ram[addr_b] <= dati_b;
		end
		
	end
	
endmodule
