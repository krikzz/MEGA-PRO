




module dmaio(
	
	input  PiBus pi,
	input  [15:0]rom0_do,
	input  [15:0]rom1_do,
	input  [15:0]sram_do,
	input  [15:0]bram_do,
	
	output DmaBus	dma
);
	
	
	assign dma.pi_di[7:0]	= pi.addr[0] == 0 ? mem_do_sel[15:8] : mem_do_sel[7:0];
	assign dma.data[15:0] 	= {pi.dato[7:0], pi.dato[7:0]};
	assign dma.addr[22:0] 	= pi.addr[22:0];
	assign dma.oe 				= pi.act & pi.oe;
	assign dma.we_hi 			= pi.act & pi.we & pi.addr[0] == 0;
	assign dma.we_lo 			= pi.act & pi.we & pi.addr[0] == 1;
	
	assign dma.req_rom0 		= pi.map.ce_rom0;
	assign dma.req_rom1 		= pi.map.ce_rom1;
	assign dma.req_sram 		= pi.map.ce_sram;
	assign dma.req_bram 		= pi.map.ce_bram;
	
	assign dma.mem_req		= dma.req_rom0 | dma.req_rom1 | dma.req_sram | dma.req_bram;
	
	wire [15:0]mem_do_sel = 
	dma.req_rom0 ? rom0_do[15:0] : 
	dma.req_rom1 ? rom1_do[15:0] : 
	dma.req_sram ? sram_do[15:0] : 
	dma.req_bram ? bram_do[15:0] : 16'hffff;
	
endmodule
