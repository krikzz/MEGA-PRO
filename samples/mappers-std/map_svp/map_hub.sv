


`include "../base/defs.v"


module map_hub(

	input  MapIn mai,
	output MapOut mout
);
	

	
	assign mout = 
	mai.cfg.map_idx == `MAP_SVP ? mout_svp : 
										   mout_nom;
	
	
	MapOut mout_nom;
	map_nom nom_inst(mai, mout_nom);
	
	MapOut mout_svp;
	map_svp svp_inst(mai, mout_svp);
	


endmodule
