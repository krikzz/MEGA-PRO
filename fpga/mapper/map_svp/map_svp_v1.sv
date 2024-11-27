

module map_svp(

	input  MapIn mai,
	output MapOut mout
);
	
	wire clk   = mai.clk;
	
	CpuBus cpu;
	
	always @(posedge clk)
	begin
		cpu <= mai.cpu;
	end
//************************************************************************************* config	
	assign mout.mask_off 	= 1;
	assign mout.dtack			= !svp_dtack;

	MemBus svp_rom(mout.rom0, mai.rom0_do);
//*************************************************************************************
	
	
	assign mout.map_do[15:0]	= svp_dout[15:0];
	
	assign svp_rom.we_lo 		= svp_mem_we;
	assign svp_rom.we_hi			= svp_mem_we;
	
	
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
		
		.ram_do(svp_rom.dato[15:0]),
		.ram_di(svp_rom.dati[15:0]),
		.ram_addr(svp_rom.addr[21:1]),
		//.ram_ce(svp_ram_ce), 
		.ram_oe(svp_rom.oe), 
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
	
	input [15:0]ram_do,
	output reg[15:0]ram_di,
	output [21:1]ram_addr,
	output ram_ce,
	output reg ram_oe, ram_we
	
);
	

	assign dout 				= svp_reg_ce ? svp_do : gen_mem_di;
	assign dtak 				= !svp_reg_ce;
	//assign bus_oe 			= (svp_reg_ce | !ce_lo) & !oe;
	assign bus_oe 				= (svp_reg_ce | abus[23:22] == 0) & !oe;
	
	assign ram_addr 			= gen_access ? ram_addr_sel : ram_addr_st;
	
	assign ram_ce 				= ram_oe | ram_we;

	parameter MC_IDLE 		= 0;
	parameter MC_GEN_ACCESS = 1;
   parameter MC_SVP_READ 	= 2;
	parameter MC_SVP_WRITE 	= 3;
					
	
	reg [15:0]dma_buff;
	reg [15:0]ram_buff;
	reg [21:1]ram_addr_st;
	reg [1:0]mstate;
	reg [2:0]delay;
	
	reg  dram_rmw;
		
	reg cpu_we_req, cpu_oe_req, vdp_oe_req;	
	reg [7:0]cpu_oe_st;
	reg [7:0]cpu_we_st;
	
	
	wire [15:0]gen_mem_di = as ? dma_buff : gen_access ? ram_do : ram_buff;
	
	//wire cpu_oe = !ce_hi & !ce_lo & !oe;
	//wire cpu_we = !ce_hi & !ce_lo & !we_lo;
	
	wire cpu_oe 		= abus[23:22] == 0 & !oe;
	wire cpu_we 		= abus[23:22] == 0 & !we_lo;
	
	wire cpu_oe_sync 	= cpu_oe_st[2:0] == 3'b001;
	wire cpu_we_sync 	= cpu_we_st[3:1] == 3'b001;
	
	wire gen_cycle 	= cpu_we_req | cpu_oe_req | vdp_oe_req | cpu_oe_sync | cpu_we_sync;
	wire gen_access 	= mstate == MC_GEN_ACCESS;
		
	always @(posedge clk)
	begin
		cpu_oe_st[7:0] <= {cpu_oe_st[6:0], cpu_oe};
		cpu_we_st[7:0] <= {cpu_we_st[6:0], cpu_we};
		if(cpu_oe_sync)dma_buff[15:0] <= ram_buff;
	end
	
	wire ce_rom = !abus[21];
	wire ce_cel1 = abus[23:16] == 8'h39;
	wire ce_cel2 = abus[23:16] == 8'h3A;
	wire ce_dram = {abus[23:17], 1'b0} == 8'h30;
	
	
	
	wire [21:1]ram_addr_sel = 
	ce_rom ?  {1'b0,abus[20:1]} : 
	ce_cel1 ? {5'b10000,1'b0,abus[15:13],abus[6:2],abus[12:7],abus[1]} : 
	ce_cel2 ? {5'b10000,1'b0,abus[15:12],abus[5:2],abus[11:6],abus[1]} : {5'b10000,abus[16:1]};
	
	
	
	always @(posedge clk, negedge rst)
	if (!rst) 
	begin
		mstate 			<= MC_IDLE;
		dram_rmw 		<= 0;
		svp_rom_ack 	<= svp_rom_req;
		svp_dram_ack 	<= svp_dram_req;
		ram_oe 			<= 0;
		ram_we 			<= 0;
	end
		else
	begin
			
			if(mstate == MC_IDLE)
			begin
				cpu_we_req <= 0;
				cpu_oe_req <= 0;
				vdp_oe_req <= 0;
			end
				else
			begin
				if(cpu_we_sync)cpu_we_req <= 1;
				if(cpu_oe_sync)cpu_oe_req <= 1;
			end
			
			if(delay == 0 & mstate != MC_IDLE)mstate <= MC_IDLE;
			
			
			if(delay > 1 & gen_cycle & !gen_access)
			begin
				delay 	<= 0;
				ram_oe 	<= 0;
				ram_we 	<= 0;
				mstate 	<= MC_IDLE;
			end
				else
			if(delay)delay <= delay - 1;
				else
			case(mstate)
				MC_IDLE: begin
					if (gen_cycle) begin
						
						delay 		<= 3;
						ram_addr_st <= ram_addr_sel;						
						ram_di 		<= din;
						ram_oe 		<= !(cpu_we_sync | cpu_we_req);
						ram_we 		<= (cpu_we_sync | cpu_we_req) & !ce_rom;
						mstate 		<= MC_GEN_ACCESS;
						//if(ce_rom | ce_cel1 | ce_cel2 | ce_dram)mstate <= MC_GEN_ACCESS;
					end
						else//SVP ROM 
					if (svp_rom_req != svp_rom_ack) 
					begin
						delay 		<= 3;
						ram_addr_st <= {3'b000,svp_rom_a};
						ram_oe 		<= 1;
						ram_we 		<= 0;
						mstate 		<= MC_SVP_READ;
					end
						else//SVP DRAM RD
					if (svp_dram_req != svp_dram_ack)
					begin
						delay 		<= 3;
						ram_addr_st <= {5'b10000,svp_dram_a};
						ram_di 		<= svp_dram_do;
						ram_oe 		<= !dram_rmw;
						ram_we 		<= dram_rmw;
						mstate 		<= dram_rmw ? MC_SVP_WRITE : MC_SVP_READ;
					end
					
				end
				
				MC_GEN_ACCESS: begin
					
					ram_buff 		<= ram_do;
					ram_oe 			<= 0;
					ram_we 			<= 0;

				end
				
				MC_SVP_READ: begin
				
					svp_mem_di 		<= ram_do;
					dram_rmw 		<= svp_dram_we;
					ram_oe 			<= 0;
					ram_we 			<= 0;
					
					if (!svp_dram_we) 
					begin
						svp_rom_ack 	<= svp_rom_req;
						svp_dram_ack 	<= svp_dram_req;
					end

				end
				
				MC_SVP_WRITE: begin
				
					svp_dram_ack 	<= svp_dram_req;
					dram_rmw 		<= 0;
					ram_oe 			<= 0;
					ram_we 			<= 0;					
				end
			
			endcase;
		end
	
	
	wire svp_oe_sync = svp_reg_oe_st[4:2] == 3'b001;
	wire svp_we_sync = svp_reg_we_st[4:2] == 3'b001;
	
	
	wire svp_reg_ce = abus[23:8] == 16'hA150;
	wire svp_reg_oe = svp_reg_ce & !oe;
	wire svp_reg_we = svp_reg_ce & !we_lo;
	
	
	reg [7:0]svp_reg_oe_st;
	reg [7:0]svp_reg_we_st;
		
	always @(posedge clk)
	begin		
		svp_reg_oe_st[7:0] <= {svp_reg_oe_st[6:0], svp_reg_oe};
		svp_reg_we_st[7:0] <= {svp_reg_we_st[6:0], svp_reg_we};
	end

	
	
	wire [15:0] svp_do;
	wire        svp_dtack_n;
	
	wire [20:1] svp_rom_a;
	wire        svp_rom_req;
	reg         svp_rom_ack;
	
	wire [16:1] svp_dram_a;
	wire [15:0] svp_dram_do;
	wire        svp_dram_we;
	wire        svp_dram_req;
	reg         svp_dram_ack;
	
	reg  [15:0] svp_mem_di;
	
	
	
	SVP svp_inst(
	
		.CLK(!clk),
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
		.ROM_DI(svp_mem_di),
		.ROM_REQ(svp_rom_req),
		.ROM_ACK(svp_rom_ack),
		
		.DRAM_A(svp_dram_a),
		.DRAM_DI(svp_mem_di),
		.DRAM_DO(svp_dram_do),
		.DRAM_WE(svp_dram_we),
		.DRAM_REQ(svp_dram_req),
		.DRAM_ACK(svp_dram_ack)
	);
	
endmodule
