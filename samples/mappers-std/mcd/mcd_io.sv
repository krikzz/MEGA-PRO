

module mcd_io(

	input clk,
	input PiBus pi,
	output McdIO cdio
);

	
	
	assign cdio.dato 		= pi.dato;
	assign cdio.addr 		= pi.addr;
	assign cdio.sync 		= pi.sync;
	assign cdio.we 		= pi.we;
	assign cdio.we_sync 	= pi.we_sync;
	
	wire   ce_mcd 			= pi.map.ce_mcd;
	wire	 ce_cfg 			= ce_mcd & {pi.addr[15:8], 8'd0}  == 16'hff00;
	
	//mega-cd  control interface
	assign cdio.ce_cdc   = ce_mcd & cdio.addr[15] == 0 & cdio.addr[14:0] < 2352;//data stream wr, host_resp status rd
	assign cdio.ce_cdd  	= ce_mcd & cdio.addr[15] == 1 & cdio.addr[14:0] < 5;//cmd r/w

	wire   ce_cmd			= ce_mcd & cdio.we_sync & cdio.addr[15:0] == 16'h8010;
	assign cdio.mcd_irq  = ce_cmd & cdio.dato[0];
	assign cdio.mcd_mut0 = ce_cmd & cdio.dato[1];
	assign cdio.mcd_mut1 = ce_cmd & cdio.dato[2];
	assign cdio.mcd_rack	= ce_cmd & cdio.dato[3]; //cdd resp ack
	

	wire [7:0]cfg_addr	= cdio.addr[7:0];
	wire ce_dsp 			= ce_cfg & {cfg_addr[7:3], 3'd0}	== 8'h00;//8B dsp config
	wire ce_pha 			= ce_cfg & {cfg_addr[7:1], 1'd0} == 8'h08;//2B mcd irq phase
	
	
	//config
	always @(negedge clk)
	if(cdio.we_sync)
	begin
				
		if(ce_dsp)
		begin
			cdio.cfg_dsp[cdio.addr[2:0]][7:0] <= cdio.dato[7:0];
		end
		
		
		if(cdio.cfg_pha == 0)cdio.cfg_pha <= 350;
		if(ce_pha & cdio.addr[0] == 0)cdio.cfg_pha[11:8] <= cdio.dato[7:0];
		if(ce_pha & cdio.addr[0] == 1)cdio.cfg_pha[7:0]  <= cdio.dato[7:0];

	end

endmodule
