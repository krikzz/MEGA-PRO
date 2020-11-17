

	wire [`BW_PI_BUS-1:0]pi_bus;
	wire [`BW_SYS_CFG-1:0]sys_cfg;
	wire [`BW_MDBUS-1:0]mdbus;
	wire [`BW_MEMDAT-1:0]mem_data;
	assign {pi_bus[`BW_PI_BUS-1:0], sys_cfg[`BW_SYS_CFG-1:0], mdbus[`BW_MDBUS-1:0], mem_data[`BW_MEMDAT-1:0]} = mapin[`BW_MAP_IN-1:0];