

module map_svp(

	input  MapIn mai,
	output MapOut mout
);
	
	wire clk   = mai.clk;
	
	CpuBus cpu;
	
	always @(negedge clk)
	begin
		cpu <= mai.cpu;
	end
//************************************************************************************* config	
	assign mout.mask_off 	= 1;
	assign mout.dtack			= !svp_dtack;

	MemBus svp_rom(mout.rom0, mai.rom0_do);
	MemBus svp_ram(mout.rom1, mai.rom1_do);
//*************************************************************************************
	
	parameter ROM_DELAY			= 3;
	parameter RAM_DELAY			= 3;
	
	assign mout.map_do[15:0]	= svp_dout[15:0];
	
	assign svp_ram.we_lo 		= svp_mem_we;
	assign svp_ram.we_hi			= svp_mem_we;
	
	
	wire [15:0]svp_dout;
	wire svp_mem_we;
	wire svp_rst = !(mai.sys_rst | mai.map_rst);
	wire svp_dtack;
		
	svp_core svp_inst(

		.clk(clk),
		
		.dout(svp_dout),
		.din(cpu.data),
		.abus(cpu.addr[23:1]),
		.ce_lo(cpu.ce_lo), 
		.ce_hi(cpu.ce_hi), 
		.oe(cpu.oe), 
		.we_lo(cpu.we_lo), 
		.as(cpu.as), 
		.rst(svp_rst),//warning!
		.dtak(svp_dtack), 
		.bus_oe(mout.map_oe),
		
		.rom_delay(ROM_DELAY),
		.rom_do(svp_rom.dato[15:0]),
		.rom_addr(svp_rom.addr[21:1]),
		.rom_oe(svp_rom.oe), 
		
		.ram_delay(RAM_DELAY),
		.ram_do(svp_ram.dato[15:0]),
		.ram_di(svp_ram.dati[15:0]),
		.ram_addr(svp_ram.addr[16:1]),
		.ram_oe(svp_ram.oe), 
		.ram_we(svp_mem_we)
	
	);
	
endmodule




module svp_core(

	input clk,
	
	output [15:0]dout,
	input [15:0]din,
	input [23:1]abus,
	input ce_lo, ce_hi, oe, we_lo, as, rst,
	output dtak, bus_oe,
	
	input [2:0]rom_delay,
	input [15:0]rom_do,
	output [21:0]rom_addr,
	output rom_oe,
	
	input [2:0]ram_delay,
	input [15:0]ram_do,
	output [15:0]ram_di,
	output [21:1]ram_addr,
	output ram_ce,
	output ram_oe, ram_we
	
);
	
	assign dout[15:0] = 
	svp_reg_ce    ? svp_do : 
	abus[21] == 0 ? rom_do_smd :
	ram_do_smd;
	
	assign dtak = !svp_reg_ce;
	assign bus_oe = (svp_reg_ce | cart_ce) & !oe;
	
	wire cart_ce    = abus[23:22] == 0;
	
	
//************************************************************************************* svp core	
	wire svp_oe_sync = svp_reg_oe_st[4:2] == 3'b001;
	wire svp_we_sync = svp_reg_we_st[4:2] == 3'b001;
	
	wire svp_reg_ce = abus[23:4] == 20'hA1500;
	wire svp_reg_oe = svp_reg_ce & !oe;
	wire svp_reg_we = svp_reg_ce & !we_lo;
	
	
	reg [7:0]svp_reg_oe_st;
	reg [7:0]svp_reg_we_st;
		
	always @(negedge clk)
	begin		
		svp_reg_oe_st[7:0] <= {svp_reg_oe_st[6:0], svp_reg_oe};
		svp_reg_we_st[7:0] <= {svp_reg_we_st[6:0], svp_reg_we};
	end
	
	
	wire [15:0] svp_do;
	wire        svp_dtack_n;
	
	wire [20:1] svp_rom_a;
	wire        svp_rom_req;
	wire         svp_rom_ack;
	
	wire [16:1] svp_dram_a;
	wire [15:0] svp_dram_do;
	wire        svp_dram_we;
	wire        svp_dram_req;
	wire        svp_dram_ack;

	
	SVP svp_inst(
	
		.CLK(clk),
		.CE(1),
		.RST_N(rst),
		.ENABLE(1),
		
		.BUS_A(abus),
		.BUS_DI(din),
		.BUS_DO(svp_do),
		.BUS_AS_N(as),
		.BUS_OE_N(!svp_oe_sync),
		.BUS_LWR_N(!svp_we_sync),
		.BUS_DTACK_N(svp_dtack_n),
		
		.ROM_A(svp_rom_a),
		.ROM_DI(rom_do_svp),
		.ROM_REQ(svp_rom_req),
		.ROM_ACK(svp_rom_ack),
		
		.DRAM_A(svp_dram_a),
		.DRAM_DI(ram_do_svp),
		.DRAM_DO(svp_dram_do),
		.DRAM_WE(svp_dram_we),
		.DRAM_REQ(svp_dram_req),
		.DRAM_ACK(svp_dram_ack)
	);
	

//************************************************************************************* rom	
	wire rom_oe_smd = abus[23:21] == 0 & (!oe | !as);
	wire rom_oe_svp = svp_rom_req != svp_rom_ack;
	
	wire [15:0]rom_do_smd;
	wire [15:0]rom_do_svp;
	
	mem_dp_svp rom_dp(

		.clk(clk),
		.rst(!rst),
		.mem_delay(rom_delay),
		
		.mem_do(rom_do),
		.mem_addr(rom_addr),
		.mem_oe(rom_oe),
		
		.mem_do_a(rom_do_smd),
		.mem_addr_a(abus[20:1]),
		.mem_oe_a(rom_oe_smd),
		.mem_as_a(as),
		
		.mem_do_b(rom_do_svp),
		.mem_addr_b(svp_rom_a[20:1]),
		.mem_oe_b(rom_oe_svp),
		.mem_req_b(svp_rom_req),
		.mem_ack_b(svp_rom_ack)
	);
//************************************************************************************* ram	
	wire ce_cel1 = abus[23:16] == 8'h39;
	wire ce_cel2 = abus[23:16] == 8'h3A;
	
	wire ram_ce_smd = abus[23:20] == 3;
	wire ram_oe_smd = ram_ce_smd & !oe;
	wire ram_we_smd = ram_ce_smd & !we_lo;
	
	wire ram_oe_svp = svp_dram_we == 1 & svp_dram_req != svp_dram_ack;
	wire ram_we_svp = svp_dram_we == 0 & svp_dram_req != svp_dram_ack;
	
	wire [15:0]ram_do_smd;
	wire [15:0]ram_do_svp;
	
	wire [16:1]ram_addr_smd = 
	ce_cel1 ? {1'b0,abus[15:13],abus[6:2],abus[12:7],abus[1]} : 
	ce_cel2 ? {1'b0,abus[15:12],abus[5:2],abus[11:6],abus[1]} : abus[16:1];
	
	mem_dp_svp ram_dp(

		.clk(clk),
		.rst(!rst),
		.mem_delay(ram_delay),
		
		.mem_do(ram_do),
		.mem_di(ram_di),
		.mem_addr(ram_addr),
		.mem_we(ram_we), 
		.mem_oe(ram_oe),
		
		.mem_do_a(ram_do_smd),
		.mem_di_a(din),
		.mem_addr_a(ram_addr_smd),
		.mem_we_a(ram_we_smd), 
		.mem_oe_a(ram_oe_smd),
		.mem_as_a(as),
		
		.mem_do_b(ram_do_svp),
		.mem_di_b(svp_dram_do),
		.mem_addr_b(svp_dram_a),
		.mem_we_b(ram_oe_svp), 
		.mem_oe_b(ram_we_svp),
		.mem_req_b(svp_dram_req),
		.mem_ack_b(svp_dram_ack)
	);
		

endmodule



module mem_dp_svp(

	input clk,
	input rst,
	input [2:0]mem_delay,
	
	input [15:0]mem_do,
	output reg [15:0]mem_di,
	output reg [21:1]mem_addr,
	output reg mem_we, mem_oe,
	
	output [15:0]mem_do_a,
	input [15:0]mem_di_a,
	input [21:1]mem_addr_a,
	input mem_we_a, mem_oe_a,
	input mem_as_a,
	
	output reg[15:0]mem_do_b,
	input [15:0]mem_di_b,
	input [21:1]mem_addr_b,
	input mem_we_b, mem_oe_b,
	input mem_req_b,
	output reg mem_ack_b
);
	
	parameter IDLE	= 0;
	parameter RW_A	= 1;
	parameter RD_B	= 2;
	parameter WR_B	= 3;
	
	assign mem_do_a = !mem_as_a ? mem_do_a_cpu : mem_do_a_dma;
	
	wire [1:0]mem_req, mem_req_edge;
	assign mem_req[0] = mem_we_a | mem_oe_a;
	assign mem_req[1] = (mem_we_b | mem_oe_b) & mem_req_b != mem_ack_b;
	assign mem_req_edge[0] = mem_req[0] & !mem_req_st[0];
	assign mem_req_edge[1] = mem_req[1] & !mem_req_st[1];
	
	reg [2:0]delay;
	reg [1:0]mem_busy;
	reg [1:0]mem_req_st;
	reg [2:0]state;
	reg mem_wrb;
	reg [15:0]mem_do_a_cpu;
	reg [15:0]mem_do_a_dma;

	always @(negedge clk)
	if(rst)
	begin
		state <= IDLE;
		mem_we <= 0;
		mem_oe <= 0;
		mem_req_st <= 0;
		mem_busy <= 0;
		mem_wrb <= 0;
		mem_ack_b <= mem_req_b;
	end
		else
	begin
		
		mem_req_st[1:0] <= mem_req[1:0];
		if(mem_req_edge[0])mem_busy[0] <= 1;
		if(mem_req_edge[1])mem_busy[1] <= 1;
		
		//if(delay == 0 & mstate != MC_IDLE)mstate <= MC_IDLE;
		
		if(delay > 1 & mem_busy[0] & state != RW_A)
		begin
			state <= 0;
			delay <= 0;
			mem_oe <= 0;
			mem_we <= 0;
		end
			else
		if(delay)delay <= delay - 1;
			else
		case(state)
			IDLE:begin
			
				if(mem_busy[0])
				begin
					mem_di[15:0] <= mem_di_a[15:0];
					mem_addr[21:1] <= mem_addr_a[21:1];
					mem_oe <= mem_oe_a;
					mem_we <= mem_we_a;
					mem_do_a_dma[15:0] <= mem_do_a_cpu[15:0];
					delay <= mem_delay;
					state <= RW_A;
				end
					else
				if(mem_busy[1])
				begin
					mem_di[15:0] <= mem_di_b[15:0];
					mem_addr[21:1] <= mem_addr_b[21:1];
					mem_oe <= !mem_wrb;
					mem_we <= mem_wrb;
					delay <= mem_delay;
					state <= mem_wrb ? WR_B : RD_B;
				end
				
			end
			RW_A:begin
				mem_do_a_cpu[15:0] <= mem_do[15:0];
				mem_oe <= 0;
				mem_we <= 0;
				mem_busy[0] <= 0;
				state <= 0;
			end
			RD_B:begin
				mem_do_b[15:0] <= mem_do[15:0];
				mem_oe <= 0;
				mem_we <= 0;
				mem_wrb <= mem_we_b;
				if(!mem_we_b)mem_busy[1] <= 0;
				if(!mem_we_b)mem_ack_b <= mem_req_b;
				state <= 0;
			end
			WR_B:begin
				mem_oe <= 0;
				mem_we <= 0;
				mem_wrb <= 0;
				mem_busy[1] <= 0;
				mem_ack_b <= mem_req_b;
				state <= 0;
			end
		endcase
		
	end

endmodule








