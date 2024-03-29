
//`define USE_SST_SMD
//`define USE_CHEATS
`define USE_AUDIO
`define USE_MDP


`include "../base/defs.v"


module map_hub(

	input  MapIn mai,
	output MapOut mout
);
	
	
	assign mout = 
	mai.cfg.map_idx == `MAP_SSF ? mout_ssf : 
										  mout_nom;
	
	
	MapOut mout_nom;
	map_nom nom_inst(mai, mout_nom);
	
	MapOut mout_ssf;
	map_ssf ssf_inst(mai, mout_ssf);
	


endmodule
