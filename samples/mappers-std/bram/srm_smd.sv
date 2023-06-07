

module bram_srm_smd(

	input  MapIn mai,
	output brm_oe,
	output [15:0]brm_do,
	
	input  [15:0]mem_do,
	output [15:0]mem_di,
	output [18:0]mem_addr,
	output mem_ce, mem_oe, mem_we_lo, mem_we_hi,
	output led
	
);

	CpuBus cpu;
	assign cpu 	= mai.cpu;
	wire clk 	= mai.clk;
	
	
	assign brm_oe 				= mem_oe;
	assign brm_do[15:0] 		= mem_do[15:0];
	
	assign mem_di[15:0] 		= cpu.data[15:0];
	assign mem_addr[18:0] 	= cpu.addr[18:0];

	assign mem_ce_3x			= mai.cfg.bram_type == `BRAM_SRM3X & !cpu.ce_lo & cpu.addr[21:20] == 2'b11;
	assign mem_ce_3m			= mai.cfg.bram_type == `BRAM_SRM3M & !cpu.ce_lo & cpu.addr[21] & ram_flag;
	assign mem_ce_2m			= mai.cfg.bram_type == `BRAM_SRM   & !cpu.ce_lo & cpu.addr[21];
	
	assign mem_ce 				= mem_ce_2m | mem_ce_3m | mem_ce_3x;
	assign mem_oe 				= mem_ce & !cpu.oe;
	assign mem_we_lo 			= mem_ce & !cpu.we_lo;
	assign mem_we_hi 			= mem_ce & !cpu.we_hi;
	assign led 					= mem_we_lo | mem_we_hi;
	

	reg ram_flag;
	
	always @(negedge clk)
	if(mai.map_rst)
	begin
		ram_flag <= 0;
	end
		else
	if(!mai.sst.act)
	begin
		if(we_edge & !cpu.tim)ram_flag <= cpu.data[0];
	end
	
	
	wire we_edge;
	sync_edge eep_sync(.clk(clk), .ce(!cpu.we_lo), .sync(we_edge));
	
endmodule
