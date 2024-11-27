

`include "../lib_base/defs.sv"


module map_hub(

	input  MapIn mai,
	output MapOut mao
);
	
	
	map_mcv mcv_inst(mai, mao);
	

endmodule
