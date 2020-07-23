 
 
 
 	wire [15:0]cpu_data;
	wire [23:0]cpu_addr;
	wire    oe_as, sst_act, map_rst, sys_rst, vclk, btn, tim, ce_lo, ce_hi, we_lo, we_hi, oe, as;
	assign {oe_as, sst_act, map_rst, sys_rst, vclk, btn, tim, ce_lo, ce_hi, we_lo, we_hi, oe, as, cpu_addr[23:1], cpu_data[15:0]} = mdbus[`BW_MDBUS-1:0];
	
