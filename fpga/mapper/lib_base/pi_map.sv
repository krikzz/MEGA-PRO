

module pi_map(
	
	input  PiBus pi,
	output PiMap map
);
	
	
	wire pi_on 				= pi.oe | pi.we;
	wire pi_act 			= pi.act;
	wire [31:0]pi_addr 	= pi.addr[31:0];
	wire [1:0]pi_dst 		= pi_addr[24:23];//8M blocks
	wire pi_we_sync		= pi.we_sync;
	
	assign map.dst_mem	= pi_dst != 3;
	assign map.dst_map	= pi_dst == 3 & pi_addr[22:16] == 3;//64K.
	
`ifdef HWC_ROM1_OFF
	assign map.ce_rom0 	= pi_on  & pi_dst <= 1;							 		//16M		0x0000000	
`elsif HWC_ROM1_ON
	assign map.ce_rom0 	= pi_on  & pi_dst == 0;							 		//8M		0x0000000
	assign map.ce_rom1 	= pi_on  & pi_dst == 1;							 		//8M		0x0800000
`else
	"undefined hardware config"
`endif	
	assign map.ce_sram 	= pi_on  & pi_dst == 2 & pi_addr[22:19] == 0;	//512K	0x1000000
	assign map.ce_bram 	= pi_on  & pi_dst == 2 & pi_addr[22:19] == 1;	//512K	0x1080000
	assign map.ce_sys  	= pi_act & pi_dst == 3 & pi_addr[22:16] == 0;	//64K		0x1800000
	assign map.ce_fifo 	= pi_act & pi_dst == 3 & pi_addr[22:16] == 1;	//64K 	0x1810000 do not use next 64k
	assign map.ce_map  	= pi_act & map.dst_map;									//64K 	0x1830000 mapper io
	assign map.ce_mcd		= pi_act & pi_dst == 3 & pi_addr[22:16] == 4;	//64K		0x1840000 MCD io
	assign map.ce_mdp		= pi_act & pi_dst == 3 & pi_addr[22:16] == 5;	//64K		0x1850000 MD+ io
	
	//map config
	assign map.ce_ggc	 	= map.ce_sys & {pi_addr[15:7], 7'd0} == 16'h0000;//128B 	cheats
	assign map.ce_cfg	 	= map.ce_sys & {pi_addr[15:3], 3'd0} == 16'h00f8;//8B 	sys config
	assign map.ce_sst	 	= map.ce_sys & {pi_addr[15:8], 8'd0} == 16'h0100;//256B 	save state data. 128B sniffer, 128B map regs
	assign map.ce_mst	 	= map.ce_sys & {pi_addr[15:1], 1'd0} == 16'h0200;//2B 	mapper status
	
	assign map.ce_mcfg	= map.ce_map & {pi_addr[15:8], 8'd0}  == 16'hff00;//256B	mapper config.  
	
	
endmodule
