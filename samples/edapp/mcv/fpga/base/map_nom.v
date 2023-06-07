
`include "defs.v"

module map_nom(

	output [`BW_MAP_OUT-1:0]mapout,
	input [`BW_MAP_IN-1:0]mapin,
	input clk
);
	
	`include "mapio.v"
	`include "sys_cfg.v"
	`include "pi_bus.v"

		
	assign dtack = 1;
//*************************************************************************************
	assign pi_din_map = pi_ce_mod ? 8'hA5 : 8'hff;
	
	assign mem_addr[`ROM0][21:0] = cpu_addr[21:0];
	assign mem_oe[`ROM0] = !ce_lo & !oe;
	assign map_oe = !ce_lo & !oe;
	
	assign map_do[15:0] = mem_do[`ROM0][15:0];
	
	
	assign led_r = ctr[25];
	reg [25:0]ctr;
	always @(negedge clk)
	begin
		ctr <= ctr + 1;
	end
	
endmodule
