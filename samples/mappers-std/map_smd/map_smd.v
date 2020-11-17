
`include "../base/defs.v"

module map_smd(

	output [`BW_MAP_OUT-1:0]mapout,
	input [`BW_MAP_IN-1:0]mapin,
	input clk
);
	
	`include "../base/mapio.v"
	`include "../base/sys_cfg.v"
	`include "../base/pi_bus.v"

	
	assign dtack = 1;
	assign pi_din_map[7:0] = 8'hff;//pi_din_map can be readed via usb (64K area at 0x1830000 in pi address space)
//*************************************************************************************
	assign mem_addr[`ROM0][22:0] = cpu_addr[22:0];//rom address
	assign mem_oe[`ROM0] = !ce_lo & !oe_as;//rom read
	assign map_oe        = !ce_lo & !oe_as;//cart databus output enable
	
	assign map_do[15:0] = mem_do[`ROM0][15:0];//output rom data bus to the system bus
	
	//console bus signals listed in mdbus.v
	//memory bus signals listed in map_in.v

endmodule

