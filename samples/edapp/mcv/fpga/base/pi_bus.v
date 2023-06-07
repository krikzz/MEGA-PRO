	
	parameter MAP_MOD_NSP = 8'hA5;//mapper not supported. force to reload mapper pack
	parameter MAP_MOD_MCD = 8'h01;//mcd normal mode
	parameter MAP_MOD_IGM = 8'h02;//mcd in-game menu
	
	
	
	wire [7:0]pi_do;
	wire [31:0]pi_addr;
	wire pi_sync, pi_we, pi_oe, pi_act, pi_clk;
	assign {pi_sync, pi_clk, pi_act, pi_we, pi_oe, pi_do[7:0], pi_addr[31:0]} = pi_bus[`BW_PI_BUS-1:0];

	wire pi_we_hi = pi_we & pi_addr[0] == 0;
	wire pi_we_lo = pi_we & pi_addr[0] == 1;
	wire pi_we_sync = pi_we & pi_sync;

	wire [1:0]pi_dst = pi_addr[24:23];
	
	wire pi_busy = (pi_we | pi_oe);
	wire pi_dst_mem = pi_dst != 3;
	wire pi_dst_map = pi_dst == 3 & pi_addr[22:16] == 3;//64K.
	
	
	wire pi_ce_rom0 = pi_act & pi_dst == 0;//8M
	wire pi_ce_rom1 = pi_act & pi_dst == 1;//8M
	wire pi_ce_sram = pi_act & pi_dst == 2 & pi_addr[22:19] == 0;//512K
	wire pi_ce_bram = pi_act & pi_dst == 2 & pi_addr[22:19] == 1;//512K
	wire pi_ce_sys  = pi_act & pi_dst == 3 & pi_addr[22:16] == 0;//64K
	wire pi_ce_fifo = pi_act & pi_dst == 3 & pi_addr[22:16] == 1;//64K. do not use next 64k
	wire pi_ce_map  = pi_act & pi_dst_map;//64K. mapper io
	
	//map config
	wire pi_ce_ggc	 = pi_ce_sys & {pi_addr[15:7], 7'd0} == 16'h0000;//128B cheats
	wire pi_ce_dsp  = pi_ce_sys & {pi_addr[15:3], 3'd0} == 16'h0080;//8B dsp config
	wire pi_ce_pha  = pi_ce_sys & {pi_addr[15:1], 1'd0} == 16'h0088;//2B mcd irq phase
	wire pi_ce_cfg	 = pi_ce_sys & {pi_addr[15:3], 3'd0} == 16'h00f8;//8B sys config
	
	
	wire pi_ce_sst	 = pi_ce_sys & {pi_addr[15:8], 8'd0} == 16'h0100;//256B save state data. 128B sniffer, 128B map regs
	
	
	//save state registers
	wire pi_ce_sst_sys = pi_ce_sst & pi_addr[7] == 0;//128 bytes for sniffer
	wire pi_ce_sst_map = pi_ce_sst & pi_addr[7] == 1;//128 bytes for mapper registers
	wire pi_we_sst_map = pi_ce_sst_map & pi_we_sync;
	wire [6:0]pi_addr_sst = pi_addr[6:0];
	
	//mappers registers
	wire pi_we_map  = pi_ce_map & pi_we_sync;
	wire pi_ce_mod  = pi_ce_map & pi_addr[15:0] == 16'hffff;//mapper mode. 
	
	//mega-cd  control interface
	wire pi_ce_cdc  = pi_ce_map & pi_addr[15] == 0 & pi_addr[14:0] < 2352;//data stream wr, host_resp status rd
	wire pi_ce_cdd  = pi_ce_map & pi_addr[15] == 1 & pi_addr[14:0] < 5;//cmd r/w

	wire pi_mcd_cmd  = pi_we_map & pi_addr[15:0] == 16'h8010;
	wire pi_mcd_irq  = pi_mcd_cmd & pi_do[0];
	wire pi_mcd_mut0 = pi_mcd_cmd & pi_do[1];
	wire pi_mcd_mut1 = pi_mcd_cmd & pi_do[2];
	wire pi_mcd_ack_resp = pi_mcd_cmd & pi_do[3];
	
	
	
