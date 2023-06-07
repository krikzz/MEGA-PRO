

module ram_cart(//256k

	input MapIn mai,
	input cart_on,
	input size,
	
	output [15:0]cart_dout,
	output cart_oe,
	
	input  [15:0]mem_dout,
	output [15:0]mem_din,
	output [17:0]mem_addr,
	output mem_oe, mem_we_lo, mem_we_hi, mem_ce
);

	CpuBus cpu;
	assign cpu 	= mai.cpu;
	
	wire clk		= mai.clk;
	
	wire [15:0]id 				= size == 0 ? 16'h0404 : 16'h0505;
	assign mem_addr[17:0] 	= size == 0 ? mem_addr_16[16:0] : mem_addr_16[17:0];
	
	assign cart_dout[15:0] 	= id_oe ? id : {8'h00, mem_dout_8[7:0]};//256K cart
	assign cart_oe 			= id_oe | mem_oe;
	
	wire mem_we 		= cart_on & ram_area & !cpu.we_lo & wp_off;//mem_we_st[0] & !mem_we_st[8];//160ns limiter
	assign mem_ce 		= cart_on & ram_area;
	assign mem_oe 		= cart_on & ram_area & !cpu.oe;
	wire id_oe 			= id_area & !cpu.oe;
	
	
	wire cart_ce 		= !cpu.ce_hi & cart_on;
	wire id_area  		= cpu.addr[23:20] == 4'b0100 & cart_ce;
	wire ram_area 		= cpu.addr[23:20] == 4'b0110 & cart_ce;
	wire reg_area 		= cpu.addr[23:20] == 4'b0111 & cart_ce;
	wire mem_we_int 	= cart_on & ram_area & !cpu.we_lo & wp_off;
	
	reg wp_off;
	//reg [8:0]mem_we_st;
	
	always @(negedge clk)
	if(mai.map_rst)
	begin
		wp_off <= 0;
	end
		else
	if(!mai.sst.act)
	begin		
		if(reg_we_sync)wp_off <= cpu.data[0];
	end

	wire [17:0]mem_addr_16;
	wire [7:0]mem_dout_8;
	
	mem_8_to_16 ramcart16(
	
		.dout_16(mem_dout),//i
		.din_16(mem_din),
		.addr_16(mem_addr_16),
		.we_lo_16(mem_we_lo), 
		.we_hi_16(mem_we_hi),
	
		.dout_8(mem_dout_8),//o
		.din_8(cpu.data[7:0]),
		.addr_8(cpu.addr[18:1]),
		.oe_8(mem_oe), 
		.we_8(mem_we)
	);
	
	
	wire reg_we_sync;
	
	sync_edge sync_inst(
		.clk(clk),
		.ce(reg_area & !cpu.we_lo),
		.sync(reg_we_sync)
	);
	
	
endmodule
