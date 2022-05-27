


`include "../base/defs.v"


module map_hub(

	EDBus ed,
	output MapOut mout
);
	

	assign mout = mout_wspr;
	

	MapOut mout_wspr;
	map_wspr wspr_inst(ed, mout_wspr);
	
endmodule
