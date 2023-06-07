


typedef struct{

	bit [7:0]map_idx;
	bit [9:0]rom_msk;
	bit [9:0]brm_msk;
	bit [7:0]bram_cfg;
	bit [7:0]features;
	bit [7:0]ss_key_save;
	bit [7:0]ss_key_load;
	bit [7:0]ss_key_menu;
	bit [7:0]ctrl;
	
	//ctrl bits
	bit ct_rst_off;	//turn off return to menu after reset
	bit ct_ss_on;		//vblank hook for in-game menu
	bit ct_gg_on;		//cheats engine
	bit ct_ss_btn;		//use external button for in-game menu
	bit ct_megasg;		//hacks for eliminating mega-sg bugs
	bit ct_32x;			//specific reset mode for 32x
	bit ct_sms;			//specific reset and sst mode for sms
	bit ct_gmode;		//game mode
	
	bit fea_mcd;		//CD addon enable
	bit fea_mdp;		//CD addon enable
	
	bit [3:0]bram_type;
	bit [3:0]bram_bus;//eeprom bus configuration
	
	
}SysCfg;



module sys_cfg(
	
	input  MapIn mai,
	
	output SysCfg cfg,
	output [7:0]pi_di
);
	
	
	PiBus pi;
	assign pi = mai.pi;
	
	assign pi_di[7:0]	= scfg[pi.addr[2:0]][7:0];
	
	
	wire [3:0]brm_msk_in, rom_msk_in;
	
	assign cfg.ctrl[7:0]				= scfg[7][7:0];
	assign cfg.ss_key_menu[7:0]  	= scfg[6][7:0];
	assign cfg.ss_key_load[7:0]  	= scfg[5][7:0];
	assign cfg.ss_key_save[7:0]  	= scfg[4][7:0];
	assign cfg.bram_cfg[7:0] 		= scfg[3][7:0];
	assign cfg.features[7:0]		= scfg[2][7:0];
	assign brm_msk_in[3:0]			= scfg[1][7:4];
	assign rom_msk_in[3:0]			= scfg[1][3:0];
	assign cfg.map_idx[7:0] 		= scfg[0][7:0];
	
	assign cfg.rom_msk[9:0] 	= (1'b1 << rom_msk_in[3:0])-1;
	assign cfg.brm_msk[9:0] 	= (1'b1 << brm_msk_in[3:0])-1;

	
	assign cfg.ct_rst_off 		= cfg.ctrl[0];//turn off return to menu after reset
	assign cfg.ct_ss_on   		= cfg.ctrl[1];//vblank hook for in-game menu
	assign cfg.ct_gg_on   		= cfg.ctrl[2];//cheats engine
	assign cfg.ct_ss_btn  		= cfg.ctrl[3];//use external button for in-game menu
	assign cfg.ct_megasg  		= cfg.ctrl[4];//mega sg fixes
	assign cfg.ct_32x				= cfg.ctrl[6:5] == 2'b01 & !mai.map_rst;
	assign cfg.ct_sms				= cfg.ctrl[6:5] == 2'b10 & !mai.map_rst;
	assign cfg.ct_gmode			= cfg.ctrl[7];//game mode
	
	assign cfg.fea_mcd			= cfg.features[0];
	assign cfg.fea_mdp			= cfg.features[1];
	
	assign cfg.bram_type[3:0] 	= cfg.bram_cfg[3:0];
	assign cfg.bram_bus[3:0]  	= cfg.bram_cfg[7:4];

	
//*******************************************************************************

	reg [7:0]scfg[8];

	always @(negedge mai.clk)
	begin
	
		if(pi.map.ce_cfg & pi.we_sync)scfg[pi.addr[2:0]][7:0] <= pi.dato[7:0];
		
	end
	
	
endmodule
