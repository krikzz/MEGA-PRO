 
//************************************************************************************* mem_ctrl

module mem_ctrl(
	
	output [15:0]data,
	output [21:0]addr,
	output ce, oe, we, ub, lb,
	input MemCtrl mem,
	input msk_on,
	input [9:0]msk,
	input DmaBus dma,
	input dma_req

);
	
	wire [22:0]mask 	= msk_on  ? {msk[9:0], 13'h1fff} : '1;
	
	wire mem_oe 		= dma_req ? dma.oe 	 		: mem.oe;
	wire mem_we_lo 	= dma_req ? dma.we_lo 		: mem.we_lo;
	wire mem_we_hi 	= dma_req ? dma.we_hi		: mem.we_hi;
	wire [15:0]mem_di = dma_req ? dma.data[15:0] : mem.dati[15:0];
	wire [22:0]mem_ad = dma_req ? dma.addr[22:0] : mem.addr[22:0] & mask[22:0];
	
	assign data[15:0] = mem_oe ? 16'hzzzz : mem_di[15:0];
	assign addr[21:0] = mem_ad[22:1];
	assign ce 			= !(mem_oe | mem_we_lo | mem_we_hi);
	assign oe 			= !mem_oe;
	assign we 			= !(mem_we_lo | mem_we_hi);
	assign ub 			= !(mem_we_hi | mem_oe);
	assign lb 			= !(mem_we_lo | mem_oe);

endmodule


//************************************************************************************* sync_edge
module sync_edge(
	input clk, ce, 
	output sync
);

	assign sync = ce_st[2:0] == 3'b011;

	reg [3:0]ce_st;
	
	always @(negedge clk)
	begin
		ce_st[3:0] <= {ce_st[2:0], ce};
	end

endmodule

//************************************************************************************* ram_dp8

module ram_dp8(

	input clk_a,
	input [7:0]din_a,
	input [15:0]addr_a,
	input we_a, 
	output reg [7:0]dout_a,
	
	input clk_b,
	input [7:0]din_b,
	input [15:0]addr_b,
	input we_b, 
	output reg [7:0]dout_b
	
);	
	reg [7:0]ram[65536];
	
	always @(negedge clk_a)
	begin
		dout_a <= we_a ? din_a : ram[addr_a];
		if(we_a)ram[addr_a] <= din_a;
	end
	
	always @(negedge clk_b)
	begin
		dout_b <= we_b ? din_b : ram[addr_b];
		if(we_b)ram[addr_b] <= din_b;
	end
	
endmodule

module ram_dp16(

	input clk_a,
	input [15:0]din_a,
	input [15:0]addr_a, 
	input we_a,
	output reg [15:0]dout_a,
	
	input clk_b,
	input [15:0]din_b,
	input [15:0] addr_b,
	input we_b,
	output reg [15:0]dout_b
);
	
	reg [15:0]ram[65536];
	
	always @(negedge clk_a)
	begin
		dout_a <= we_a ? din_a : ram[addr_a];
		if(we_a)ram[addr_a] <= din_a;
	end
	
	always @(negedge clk_b)
	begin
		dout_b <= we_b ? din_b : ram[addr_b];
		if(we_b)ram[addr_b] <= din_b;
	end
	
endmodule

//************************************************************************************* rst_ctrl

module rst_ctrl(

	input clk,
	input rst,
	input btn,
	input sms_mode,
	input x32_mode,
	output hrst,
	output sys_rst,
	input [7:0]map_idx,
	output reg rst_hold,
	input ctrl_rst_off,
	input [15:0]dbus,
	input [23:1]abus,
	input rom_oe
);
	
	
	assign hrst 	= rst_act | ext_rst ? 0 : 1'bz ;
	assign sys_rst = rst_lock ? 0 : sms_mode ? !addr20_st : (rst_st[1:0] == 2'b11 & !soft_reset);

	
	wire rst_req 	= (sms_mode_st[0] != sms_mode_st[1]) | (x32_mode_st[1:0] == 2'b10);
	wire rst_act 	= rst_ct == 1;
	wire rst_lock 	= rst_ct != 0;
	wire rst_off 	= ctrl_rst_off & !ext_rst & !ext_rst_hold;

	
	reg [1:0]sms_mode_st;
	reg [1:0]x32_mode_st;
	reg [2:0]rst_ct;
	reg [22:0]delay;
	reg [2:0]rst_st;
	reg addr20_st;
	reg ext_rst, ext_rst_hold;
	
	reg soft_reset;
	reg [1:0]rst_opcode;
	reg [7:0]rom_oe_st;
	
	always @(negedge clk)
	begin
		
		rst_st[2:0] <= {rst_st[1:0], !rst};
		addr20_st <= abus[20];
		
		sms_mode_st[1:0] <= {sms_mode_st[0], sms_mode};
		x32_mode_st[1:0] <= {x32_mode_st[0], x32_mode};
		
		if(rst_ct == 0 | rst_req)delay <= 1;
			else
		delay <= delay + 1;
		
		if(rst_req)rst_ct <= 1;
			else
		if(rst_ct != 0 & delay == 0)rst_ct <= rst_ct + 1;
		
		
		if(sys_rst & !rst_off)rst_hold <= 1;
			else
		if(map_idx == 0 | rst_off)rst_hold <= 0;
		
		
		ext_rst <= btn & map_idx != 0 & !sms_mode;
		
		if(map_idx == 0)ext_rst_hold <= 0;
			else
		if(ext_rst)ext_rst_hold <= 1;
		
		
//******************************************************************** soft reset detection
		rom_oe_st[7:0] <= {rom_oe_st[6:0], rom_oe};
		
		if(rst_st[2:0] == 3'b001)soft_reset <= rst_opcode[1:0] == 2'b10;
			else
		if(rst_st[2:0] == 3'b110)soft_reset <= 0;
		
		if(rom_oe_st[5:3] == 3'b011)
		begin
			 rst_opcode[1:0] = {rst_opcode[0], dbus[15:0] == 16'h4E70};
		end
		
	end

endmodule

//************************************************************************************* mem_16_to_8

module mem_8_to_16(
	
	input  [15:0]dout_16,
	output [15:0]din_16,
	output [22:0]addr_16,
	output oe_16, we_lo_16, we_hi_16,
	
	
	output [15:0]dout_8,
	input  [15:0]din_8,
	input  [22:0]addr_8,
	input  oe_8, we_8
	
);


	assign oe_16 = oe_8;
	assign we_hi_16 = we_8 & addr_8[0] == 0;
	assign we_lo_16 = we_8 & addr_8[0] == 1;
	
	assign addr_16[22:1] = addr_8[22:1];
	assign din_16[15:0] = {din_8[7:0], din_8[7:0]};
	assign dout_8[7:0] = addr_8[0] == 0 ? dout_16[15:8] : dout_16[7:0];

endmodule

//************************************************************************************* mkey_ctrl
module mkey_ctrl(
	
	input  MapIn mai,
	output mkey_oe_n, mkey_we
);
	
	CpuBus cpu;
	assign cpu			= mai.cpu;
	
	assign mkey_oe_n 	= !(mkey_ce & mkey_on & !cpu.oe);
	assign mkey_we 	=  mkey_ce & !cpu.we_lo & mai.map_rst;
	
	wire mkey_ce 		= !cpu.as & cpu.addr[23:0] == 24'hA10000;
	
	reg mkey_on;
	
	always @(negedge mai.clk)
	begin
		if(mkey_we_edge)mkey_on <= cpu.data[0];
	end
	
	
	wire mkey_we_edge;
	
	sync_edge ce_edge_inst(
	
		.clk(mai.clk),
		.ce(mkey_we),
		.sync(mkey_we_edge)
	);
	
endmodule

//************************************************************************************* bus_ctrl

module bus_ctrl(

	input clk,
	input sys_rst,
	input bus_oe,
	
	output dat_dir, 
	output dat_oe
);


	assign dat_oe  = 0;
	assign dat_dir = bus_oe & bus_ok == 2'b11 ? 1 : 0;

	
	wire rst_edge = sys_rst & !sys_rst_st;
	
	reg sys_rst_st;
	reg [1:0]bus_ok;//bus_ok prewent hangs due undefined system state right after fpga_init
	
	always @(negedge clk)
	begin
	
		sys_rst_st <= sys_rst;
		
		if(rst_edge)bus_ok <= 0;
			else
		bus_ok[1:0] <= {bus_ok[0], 1'b1};
		
	end
	

endmodule

//************************************************************************************* clock divider

module clk_dvp(

	input clk,
	input rst,
	input [31:0]ck_base,
	input [31:0]ck_targ,
	
	output reg ck_out
);

	
	parameter CLK_INC = 64'h20000;
	
	wire [31:0]ratio 	= ck_base * CLK_INC / ck_targ;
	
	reg [31:0]clk_ctr;
		
	always @(negedge clk)
	if(rst)
	begin
		clk_ctr	<= 0;
		ck_out	<= 0;
	end
		else
	begin
		
		if(clk_ctr >= (ratio-CLK_INC))
		begin
			clk_ctr	<= clk_ctr - (ratio-CLK_INC);
			ck_out 	<= 1;
		end
			else
		begin
			clk_ctr 	<= clk_ctr + CLK_INC;
			ck_out 	<= 0;
		end
		
	end
	

endmodule
