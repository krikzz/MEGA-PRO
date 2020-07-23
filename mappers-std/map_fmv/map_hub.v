


`include "../base/defs.v"

module map_hub(

	output [`BW_MAP_OUT-1:0]mapout,
	input [`BW_MAP_IN-1:0]mapin,
	input clk,
	
	output [26:0]sub_cpu_in_ext,
	input [46:0]sub_cpu_out_ext
);
	
	`include "../base/sys_cfg.v"
	`include "../base/map_in.v"
	

	
	
	assign mapout[`BW_MAP_OUT-1:0] = 
	map_idx == 99 ? map_out_fmv[`BW_MAP_OUT-1:0] :
						 map_out_nom[`BW_MAP_OUT-1:0];
	
	
	wire [`BW_MAP_OUT-1:0]map_out_nom;
	map_nom nom_inst(
		.mapout(map_out_nom),
		.mapin(mapin),
		.clk(clk)
	);
	
		
	wire [`BW_MAP_OUT-1:0]map_out_fmv;
	map_fmv fmv_inst(
		.mapout(map_out_fmv),
		.mapin(mapin),
		.clk(clk)
	);

	


endmodule
