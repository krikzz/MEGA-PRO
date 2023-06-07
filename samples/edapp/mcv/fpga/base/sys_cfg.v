	
	
	
	wire [7:0]map_idx;
	wire [9:0]rom_msk;
	wire [9:0]brm_msk;
	wire [7:0]bram_cfg;
	wire [7:0]map_cfg;
	wire [7:0]ss_key_save;
	wire [7:0]ss_key_load;
	wire [7:0]ss_key_menu;
	wire [7:0]ctrl;
	
	
	
	//masks over 8K
	assign rom_msk[9:0] = (1'b1 << rom_msk_in[3:0])-1;
	assign brm_msk[9:0] = (1'b1 << brm_msk_in[3:0])-1;
	
	wire [3:0]rom_msk_in, brm_msk_in;
	assign 
	{
	
		ctrl[7:0],			//7
		ss_key_menu[7:0], //6
		ss_key_load[7:0], //5
		ss_key_save[7:0], //4
		bram_cfg[7:0],		//3
		map_cfg[7:0],		//2
		brm_msk_in[3:0],	//1
		rom_msk_in[3:0],	//1
		map_idx[7:0]		//0
	
	} = sys_cfg[`BW_SYS_CFG-1:0];
	
	
	
	
	wire ctrl_rst_off = ctrl[0];//turn off return to menu after reset
	wire ctrl_ss_on   = ctrl[1];//vblank hook for in-game menu
	wire ctrl_gg_on   = ctrl[2];//cheats engine
	wire ctrl_ss_btn  = ctrl[3];//use external button for in-game menu
	wire ctrl_gmode	= ctrl[7];//game mode
	
	wire mcfg_ms_bios = map_cfg[0];
	wire mcfg_ms_fm  	= map_cfg[1];
	wire mcfg_ms_ext 	= map_cfg[2];
	wire mcfg_ms_msg	= map_cfg[3];//timings hack for mega-sg
	
	
	wire [3:0]bram_type = bram_cfg[3:0];
	wire [3:0]bram_bus  = bram_cfg[7:4];
	
	
	parameter BRAM_OFF		= 4'h0;
	parameter BRAM_SRM      = 4'h1;
	parameter BRAM_SRM3M    = 4'h2;
	parameter BRAM_24X01    = 4'h3;
	parameter BRAM_24C01    = 4'h4;
	parameter BRAM_24C02    = 4'h5;
	parameter BRAM_24C08    = 4'h6;
	parameter BRAM_24C16    = 4'h7;
	parameter BRAM_24C64    = 4'h8;
	parameter BRAM_M95320   = 4'h9;
	parameter BRAM_RCART    = 4'hA;
	
	parameter BRAM_BUS_ACLM = 4'h0;
	parameter BRAM_BUS_EART = 4'h1;
	parameter BRAM_BUS_SEGA = 4'h2;
	parameter BRAM_BUS_CODM = 4'h3;
	
	