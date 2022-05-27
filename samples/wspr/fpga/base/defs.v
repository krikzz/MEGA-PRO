
`define BW_MAP_IN		(`BW_MEMDAT + `BW_MDBUS + `BW_PI_BUS + `BW_SYS_CFG)
`define BW_MAP_OUT	231
`define BW_MEMDAT		64
`define BW_MDBUS		52
`define BW_PI_BUS		45
`define BW_SYS_CFG	64


`define  ROM0			0
`define  ROM1 			1
`define  SRAM 			2
`define  BRAM 			3


`define  MAP_OS		0
`define  MAP_SMD		1
`define  MAP_32X		2
`define  MAP_10M		3
`define  MAP_CDB		4
`define  MAP_SSF		5
`define  MAP_SMS		6
`define  MAP_SVP		7
`define  MAP_MCD		8
`define  MAP_PIE		9
`define  MAP_PIE_CD	10
`define  MAP_SMD_CD	11
`define  MAP_APP		12
`define  MAP_GKO		13
`define  MAP_DEL		14
`define  MAP_RLT		15
`define  MAP_SF4		16
`define  MAP_SF2		17
`define  MAP_SF1A		18
`define  MAP_SF1B		19



`define BRAM_OFF			4'h0
`define BRAM_SRM     	4'h1
`define BRAM_SRM3M   	4'h2
`define BRAM_24X01   	4'h3
`define BRAM_24C01   	4'h4
`define BRAM_24C02   	4'h5
`define BRAM_24C08   	4'h6
`define BRAM_24C16   	4'h7
`define BRAM_24C64   	4'h8
`define BRAM_M95320  	4'h9
`define BRAM_RCART   	4'hA
`define BRAM_SRM3X   	4'hB

`define BRAM_BUS_ACLM	4'h0
`define BRAM_BUS_EART	4'h1
`define BRAM_BUS_SEGA	4'h2
`define BRAM_BUS_CODM	4'h3


`define  MAP_MOD_NSP 	8'hA5//mapper not supported. force to reload mapper pack
`define  MAP_MOD_MCD 	8'h01//mcd normal mode
`define  MAP_MOD_IGM 	8'h02//mcd in-game menu