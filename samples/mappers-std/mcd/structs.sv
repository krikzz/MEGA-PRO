
 
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
