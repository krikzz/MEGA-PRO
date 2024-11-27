

`include "../lib_base/defs.sv"


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
