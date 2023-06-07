

//`define DSP_OFF
`define USE_MDP
`define USE_AUDIO
`define USE_MCD

`include "../base/defs.v"

module map_hub(

	input  MapIn mai,
	output MapOut mout
);
	
	
	assign mout = 
	mai.cfg.map_idx == `MAP_SMD ? mout_smd : 
										   mout_nom;
	
	
	MapOut mout_nom;
	map_nom nom_inst(mai, mout_nom);
	
	MapOut mout_smd;
	map_smd smd_inst(mai, mout_smd);



endmodule
