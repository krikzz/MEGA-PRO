

`include "../lib_base/defs.sv"


module map_hub(

	input  MapIn mai,
	output MapOut mao
);
	
	
	assign mao = 
	mai.cfg.map_idx == `MAP_MCD ? mout_mcd : 
										   mout_nom;
	
	
	MapOut mout_nom;
	map_nom nom_inst(mai, mout_nom);
	
	MapOut mout_mcd;
	map_mcd mcd_inst(mai, mout_mcd);
	

endmodule
