 
//********

typedef struct{
	
	MemCtrl	rom0;		//mamory controls
	MemCtrl	rom1;
	MemCtrl	sram;
	MemCtrl	bram;

	DacBus	dac;		//audio data
	
	bit [7:0]pi_di;	//mapper to pi
	bit [7:0]sst_di;	//save state to pi
	
	bit map_oe;			//mapper output enable
	bit [15:0]map_do;	//mapper data
	
	bit [4:0]gp_o;		//gpio data
	bit [4:0]gp_dir;	//gpio direction
	
	bit cart;			//#cart signal at cart pot
	bit dtack;			//dtack signal at cart port (inverted)
	bit led_r;
	bit led_g;
	bit mask_off;		//do not controll memory size (rom0 and bram)
	bit map_nsp;		//mapper not supported
	
}MapOut;

//********
typedef struct{
	
	bit clk;			//system clock
	bit btn;			//on-board button
	bit [4:0]gp_i;	//gpio inputs
	bit gp_ck;		//gpio clock input
	bit sys_rst;	//system reset
	bit map_rst;	//mapper reset. active when cart in menu
	
	//memory douts
	bit [15:0]rom0_do;
	bit [15:0]rom1_do;
	bit [15:0]sram_do;
	bit [15:0]bram_do;
	
	
	CpuBus 	cpu;//cpu bus
	SysCfg	cfg;//sysem config
	PiBus		pi; //peripheral interface
	SSTBus	sst;//save state bus
	
}MapIn;
//********

typedef struct{
	
	bit [15:0]data;
	bit [23:0]addr;
	bit as;
	bit oe;
	bit we_hi;
	bit we_lo;
	bit ce_hi;
	bit ce_lo;
	bit tim;
	bit vclk;
	//bit oe_as;
	
}CpuBus;

//********

typedef struct{
	bit act;
	bit ce_sni;
	bit ce_map;
	bit we_map;
	bit [6:0]addr;
	bit [7:0]dato;
}SSTBus;

//********

typedef struct{
	
	bit snd_on;
	bit clk;//sample rate x 512. 1 system clock pulse
	bit next_sample;
	bit signed[15:0]snd_r;
	bit signed[15:0]snd_l;
	bit [8:0]phase;
	
}DacBus;

//********

typedef struct{
	
	bit [15:0]dati;
	bit [22:0]addr;
	bit oe, we_lo, we_hi;
	
}MemCtrl;

typedef struct{
	
	bit [7:0]dati;
	bit [22:0]addr;
	bit oe, we;

}MemCtrl_8;
//********

interface MemBus(

	output MemCtrl ctrl,
	input [15:0]dato
);

	bit [15:0]dati;
	bit [22:0]addr;
	bit oe, we_lo, we_hi;
	
	assign ctrl.dati 		= dati;
	assign ctrl.addr		= addr;
	assign ctrl.oe 		= oe;
	assign ctrl.we_lo 	= we_lo;
	assign ctrl.we_hi 	= we_hi;
	
endinterface

//********

typedef struct{
	bit [15:0]dato;
	bit [15:0]dati;
	bit [18:0]addr;
	bit ce, oe, we_lo, we_hi, bus_oe, led;
}BramIO;

//********

typedef struct{

	bit ce;
	bit oe;
	bit we;
	bit [3:0]addr;
	bit [15:0]data;
	
}BaioDriver;

//********

typedef struct{
	
	
	bit dst_mem;
	bit dst_map;
	
	bit ce_rom0;
	bit ce_rom1;
	bit ce_sram;
	bit ce_bram;
	
	bit ce_sys;
	bit ce_fifo;
	bit ce_map;
	bit ce_mcd;
	bit ce_mdp;
	bit ce_mst;
	
	
	bit ce_ggc;
	bit ce_cfg;
	bit ce_sst;
	
	bit ce_mcfg;
	
}PiMap;

//********

typedef struct{
	
	bit [31:0]addr;
	bit [7:0]dato;
	bit oe; 
	bit we;
	bit act;
	bit clk;
	bit sync;
	bit we_sync;
	
	PiMap map;
	
}PiBus;

//********

typedef struct{
	bit [7:0]pi_di;
	bit [22:0]addr;
	bit [15:0]data;
	bit oe, we_lo, we_hi;
	bit req_rom0, req_rom1, req_sram, req_bram;
	bit mem_req;
}DmaBus;
