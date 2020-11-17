


`include "../base/defs.v"

module map_hub(

	output [`BW_MAP_OUT-1:0]mapout,
	input [`BW_MAP_IN-1:0]mapin,
	input clk
);
	
	`include "../base/sys_cfg.v"
	`include "../base/map_in.v"
	
	
	
	assign mapout[`BW_MAP_OUT-1:0] = map_out_fmv[`BW_MAP_OUT-1:0];
		
		
	wire [`BW_MAP_OUT-1:0]map_out_fmv;
	map_fmv fmv_inst(
		.mapout(map_out_fmv),
		.mapin(mapin),
		.clk(clk)
	);



endmodule
