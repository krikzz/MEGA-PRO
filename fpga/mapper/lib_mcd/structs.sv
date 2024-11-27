
 
 interface MemIO #( 

	parameter DW = 16,
   parameter AW = 23,
	parameter RO = 0
);
	
	bit [DW-1:0]dati;
	bit [DW-1:0]dato;
	bit [AW-1:0]addr;
	bit oe;
	bit we;
	bit we_lo;
	bit we_hi;
	
	
	generate

		if(DW != 8  | RO != 0)
		begin
			assign we = 0;
		end
		
		if(DW != 16 | RO != 0)
		begin
			assign we_lo = 0;
			assign we_hi = 0;
		end

	endgenerate
	

endinterface

//********

interface MemIO_WR;

	bit [15:0]dati;
	bit [15:0]dato;
	bit [16:0]addr;
	bit [3:0]mask;
	bit [1:0]mode;
	
endinterface

//********

typedef struct{
	
	bit [7:0]cfg_dsp[8];
	bit [11:0]cfg_pha;	//cdc irq phase
	
	bit ce_cdc;
	bit ce_cdd;

	bit mcd_irq;
	bit mcd_mut0;
	bit mcd_mut1;
	bit mcd_rack;	
	
	bit [7:0]dato;
	bit [31:0]addr;
	bit sync;
	bit we;
	bit we_sync;
	
}McdIO;

typedef struct{

	bit [18:0]addr;
	bit [15:0]dat;
	bit ce_wram;
	bit ce_pram; 
	bit ce_pcm;
	bit ce_main;
	bit ce_sub;
	bit we;
	
}McdDma;


typedef struct{

	bit [15:0]dati;
	bit [2:0]ipl;
	bit bgack;
	bit br;
	bit vpa;
	bit dtak;
	bit halt;
	bit clk_p;
	bit clk_n;
	bit rst;
	
}M68K_in;

typedef struct{

	bit [15:0]dato;
	bit [23:0]addr;
	bit [2:0]fc;
	bit halted;
	bit uds;
	bit lds;
	bit as;
	bit rw;
	
}M68K_out;


interface MemCtrl_WR;

	bit [15:0]dati;
	bit [16:0]addr;
	bit [3:0]mask;
	bit [1:0]mode;

endinterface


