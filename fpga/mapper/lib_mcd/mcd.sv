

module mcd
(
	output [15:0]main_din,
	input [15:0]main_dout,
	input [17:1]main_addr,
	input main_oe, main_we_lo, main_we_hi, 
	input main_ce_bios, main_ce_wram, main_ce_pram, main_ce_regs, main_vdp_dma,
	
	input clk_asic, 
	
	input [15:0]bi_data, 
	output [16:0]bi_addr, 
	output bi_oe,
	
	
	output [15:0]prg_din, 
	input [15:0]prg_dout,
	output [18:0]prg_addr,
	output prg_we_lo, prg_we_hi, prg_oe,
	
	input [15:0]wram_dout_a,
	output [15:0]wram_din_a,
	output [16:0]wram_addr_a,
	output [3:0]wram_mask_a,
	output [1:0]wram_mode_a,
	
	input [15:0]wram_dout_b,
	output [15:0]wram_din_b,
	output [16:0]wram_addr_b,
	output [3:0]wram_mask_b,
	output [1:0]wram_mode_b,
	
	output [7:0]bram_din, 
	input [7:0]bram_dout,
	output [12:0]bram_addr,
	output bram_we, bram_oe,
	
	output [15:0]pcm_ram_addr,
	output [7:0]pcm_ram_di,
	input [7:0]pcm_ram_do,
	output pcm_ram_we,
	output pcm_ram_oe,
	
	input McdIO cdio,
	output [7:0]cdio_di,
	
	output frame_sync, mcu_reset,
	
	output DacBus dac,
	
	input map_rst,
	input cd_halt,
	
	output [1:0]led
);
	
	McdDma dma;
	M68K_in  sub_in;
	M68K_out sub;
//*************************************************************************** dac
	wire signed [15:0]snd_l;
	wire signed [15:0]snd_r;
	
	dac_controller dac_controller_inst(

		.clk(clk_asic),
		//.rst(map_rst),
		.snd_on(!map_rst),
		.rate(44100),
		.snd_l(snd_l),
		.snd_r(snd_r),
		.dac(dac)
	);
	
//*************************************************************************** 
	assign main_din[15:0] = 
	main_ce_bios & {main_addr[17:1], 1'd0} == 18'h70 ? 16'hffff : 
	main_ce_bios & {main_addr[17:1], 1'd0} == 18'h72 ? reg_2006 : 
	main_ce_bios ? bi_data[15:0] : 
	main_ce_pram & bus_req == 0 ? bi_data[15:0] :
	main_ce_pram & bus_req == 1 ? prg_dout[15:0] :
	main_ce_regs ? reg_do_main_sync[15:0] : 
	wram_dout_main[15:0];
	
	wire cd_rst = map_rst;//sub_in.rst;
//*************************************************************************** bios
	assign bi_addr[16:1] = main_addr[16:1];
	assign bi_oe = !main_oe & (main_ce_bios | (main_ce_pram & bus_req == 0));
//*************************************************************************** prg ram	
	assign prg_din[15:0] = 	bus_req ? prg_din_main 		: dma.ce_pram ? dma.dat : prg_din_sub;
	assign prg_addr[18:1] = bus_req ? prg_addr_main 	: dma.ce_pram ? dma.addr[18:1] : prg_addr_sub;
	assign prg_oe = 			bus_req ? prg_oe_main 		: dma.ce_pram ? 0 : prg_oe_sub;
	assign prg_we_lo = 		bus_req ? prg_we_lo_main 	: dma.ce_pram ? dma.we : prg_we_lo_sub;
	assign prg_we_hi = 		bus_req ? prg_we_hi_main 	: dma.ce_pram ? dma.we : prg_we_hi_sub;
	

	wire [15:0]prg_din_main = main_dout[15:0];
	wire [18:1]prg_addr_main = {ga_bk[1:0], main_addr[16:1]};
	
	wire prg_oe_main = main_ce_pram & !main_oe;
	wire prg_we_lo_main = main_ce_pram & !main_we_lo;
	wire prg_we_hi_main = main_ce_pram & !main_we_hi;
	
	
	wire [15:0]prg_din_sub = sub.dato[15:0];
	wire [18:1]prg_addr_sub = sub.addr[18:1];
	wire prg_ce_sub = {sub.addr[23:19], 19'd0} == 24'h000000 & !sub.as;
	wire prg_oe_sub = prg_ce_sub & !sub_oe;
	wire prg_we_lo_sub = prg_ce_sub & !sub_we_lo & !wp_area;
	wire prg_we_hi_sub = prg_ce_sub & !sub_we_hi & !wp_area;
	wire wp_area = (prg_addr[18:9] < ga_wp[7:0]) & !bus_req;//not used for main access
//*************************************************************************** backup ram
	wire bram_ce = sub.addr[23:16] == 8'hFE & !sub.as;
	assign bram_din = sub.dato;
	//input [7:0]bram_dout,
	assign bram_addr[12:0] = sub.addr[13:1];
	assign bram_we = bram_ce & !sub_we_lo;
	assign bram_oe = bram_ce & !sub_oe;
//*************************************************************************** wram	
	wire wram_ce_sub = !sub.as & ({sub.addr[23:18], 18'd0} == 24'h80000 | {sub.addr[23:17], 17'd0} == 24'hC0000);
	
	wire [15:0]wram_dout_main;
	wire [15:0]wram_dout_sub;
	
	wire [15:0]reg_2002_do;// = {ga_wp[7:0], ga_bk[1:0], 3'd0, ga_mode, ga_dmna, ga_ret};
	wire [15:0]reg_8002_do;// = {ga_wp[7:0], 3'd0, ga_pm[1:0], ga_mode, ga_dmna, ga_ret};
	
	wire [7:0]ga_wp = reg_2002_do[15:8];
	wire [1:0]ga_bk = reg_2002_do[7:6];
	wire wram_halt_req;
	
	wram_ctrl wctrl(
	
		.clk_asic(clk_asic),
		.sub_sync(sub_sync),
		.cd_rst(map_rst),
		
		.wram_dout_a(wram_dout_a),
		.wram_din_a(wram_din_a),
		.wram_addr_a(wram_addr_a),
		.wram_mask_a(wram_mask_a),
		.wram_mode_a(wram_mode_a),
		
		.wram_dout_b(wram_dout_b),
		.wram_din_b(wram_din_b),
		.wram_addr_b(wram_addr_b),
		.wram_mask_b(wram_mask_b),
		.wram_mode_b(wram_mode_b),

		.wram_dout_main(wram_dout_main),
		.wram_dout_sub(wram_dout_sub),
		.reg_2002_do(reg_2002_do), 
		.reg_8002_do(reg_8002_do),
		
		.main_data(main_dout),
		.main_addr(main_addr),
		.main_we_lo(main_we_lo), 
		.main_we_hi(main_we_hi), 
		.main_oe(main_oe),
		.main_vdp_dma(main_vdp_dma),
		
		
		.sub_data(sub.dato),
		.sub_addr(sub.addr),
		.sub_we_lo(sub_we_lo), 
		.sub_we_hi(sub_we_hi), 
		.sub_oe(sub_oe),
		
		.regs_we_lo_main(regs_we_lo_main),
		.regs_we_hi_main(regs_we_hi_main),
		.regs_we_lo_sub(regs_we_lo_sub),
		.regs_we_hi_sub(regs_we_hi_sub),
		
		.wram_ce_main(main_ce_wram), 
		.wram_ce_sub(wram_ce_sub),
		
		.wram_dout_asic(wram_dout_asic),
		.wram_din_asic(wram_din_asic),
		.wram_addr_asic(wram_addr_asic),
		.wram_we_asic(wram_we_asic), 
		.wram_oe_asic(wram_oe_asic),
		
		.dma(dma),

		.wram_halt_req(wram_halt_req)
		
	);
//***************************************************************************	CDD
	wire [15:0]reg_8004_do, reg_8006_do, reg_8008_do, reg_800A_do;
	wire [15:0]reg_8034_do, reg_8036_do;
	wire [15:0]reg_8038_do, reg_803A_do, reg_803C_do, reg_803E_do, reg_8040_do; 
	wire [15:0]reg_8042_do, reg_8044_do, reg_8046_do, reg_8048_do, reg_804A_do;
	wire irq4, irq5;
	wire [15:0]cdda_snd_l, cdda_snd_r;
	wire cdc_host_data_main = regs_ce_main & regs_addr_main == 8'h08;// & !main_oe ;
	assign mcu_reset = map_rst | !pi_ready | sub_in.rst;
	

	cdd cdd_inst(
	
		.rst(map_rst | !pi_ready),
		.sys_rst(map_rst),
		.clk_asic(clk_asic),
		.sub_sync(sub_sync),
		.cdc_host_data_main(cdc_host_data_main),

		.sub_data(sub.dato),
		.reg_addr(regs_addr_sub),
		.sub_as(sub.as),
		.regs_we_lo_sub(regs_we_lo_sub),
		.regs_we_hi_sub(regs_we_hi_sub),
		.regs_oe_sub(regs_oe_sub),
		.bus_req(bus_req),
		
		.reg_8002_do(reg_8002_do),//input
		
		.reg_8034_do(reg_8034_do), 
		.reg_8036_do(reg_8036_do),
		
		.reg_8038_do(reg_8038_do), 
		.reg_803A_do(reg_803A_do),
		.reg_803C_do(reg_803C_do),
		.reg_803E_do(reg_803E_do),
		.reg_8040_do(reg_8040_do),
		
		.reg_8042_do(reg_8042_do),
		.reg_8044_do(reg_8044_do),
		.reg_8046_do(reg_8046_do),
		.reg_8048_do(reg_8048_do),
		.reg_804A_do(reg_804A_do),
		
		.cdio(cdio),
		.cdio_di(cdio_di),
		
		.frame_sync(frame_sync),
		
		.irq4(irq4), 
		
		.reg_8004_do(reg_8004_do),
		.reg_8006_do(reg_8006_do),
		.reg_8008_do(reg_8008_do),
		.reg_800A_do(reg_800A_do),
		.irq5(irq5),
		
		.dma(dma),
		
		.dac(dac),
		.snd_l(cdda_snd_l),
		.snd_r(cdda_snd_r)
	);

//*************************************************************************** pcm

	wire [15:0]regs_do_pcm;
	wire [15:0]pcm_snd_l, pcm_snd_r;
	wire regs_ce_pcm;
	wire pcm_sync;
	
	MemCtrl_8 pcm_ram;
	
	assign pcm_ram_di		= pcm_ram.dati;
	assign pcm_ram_addr	= pcm_ram.addr;
	assign pcm_ram_oe 	= pcm_ram.oe;
	assign pcm_ram_we 	= pcm_ram.we;
	
	
	pcm pcm_inst(
		
		.rst(map_rst),
		.clk_asic(clk_asic),
		.sub_sync(sub_sync),
		.sub_data(sub.dato),
		.sub_addr(sub.addr),
		.sub_we_lo(sub_we_lo), 
		.sub_we_hi(sub_we_hi), 
		.sub_oe(sub_oe),
		.sub_as(sub.as),
	
		.regs_do(regs_do_pcm),
		.regs_ce(regs_ce_pcm),
		
		.ram(pcm_ram),
		.ram_dato(pcm_ram_do),

		.dma(dma),
		
		.snd_l(pcm_snd_l), 
		.snd_r(pcm_snd_r),
		.snd_next_sample(pcm_sync),
	);

//*************************************************************************** audio	dsp
`ifndef MCD_MUTE

	mcd_dsp mcd_dsp_inst(

		.rst(map_rst),
		.clk(clk_asic),
		.cdio(cdio),
		
		.snd_clk(dac.clk),
		.snd_next_sample(dac.next_sample),
		
		.pcm_snd_l(pcm_snd_l),
		.pcm_snd_r(pcm_snd_r),
		.cdda_snd_l(cdda_snd_l),
		.cdda_snd_r(cdda_snd_r),
		
		.snd_l(snd_l),
		.snd_r(snd_r)
	);
	
`endif
//***************************************************************************	asic
	wire [15:0]reg_8058_do, reg_805A_do, reg_805C_do, reg_805E_do;
	wire [15:0]reg_8060_do, reg_8062_do, reg_8064_do, reg_8066_do;
	wire [15:0]wram_dout_asic, wram_din_asic;
	wire [17:1]wram_addr_asic;
	wire wram_we_asic, wram_oe_asic, asic_irq;
	wire irq1;
	
	
	asic asic_vdp(

		.rst(cd_rst),
		.clk_asic(clk_asic),
		.sub_sync(sub_sync),
		.sub_data(sub.dato),
		.reg_addr(regs_addr_sub),
		.regs_we_lo_sub(regs_we_lo_sub),
		.regs_we_hi_sub(regs_we_hi_sub),
	
		.reg_8058_do(reg_8058_do),
		.reg_805A_do(reg_805A_do),
		.reg_805C_do(reg_805C_do),
		.reg_805E_do(reg_805E_do),
		
		.reg_8060_do(reg_8060_do),
		.reg_8062_do(reg_8062_do),
		.reg_8064_do(reg_8064_do),
		.reg_8066_do(reg_8066_do),
	
		.wram_dout_asic(wram_dout_asic),
		.wram_din_asic(wram_din_asic),
		.wram_addr_asic(wram_addr_asic),
		.wram_we_asic(wram_we_asic), 
		.wram_oe_asic(wram_oe_asic),
		
		.wram_mode(reg_2002_do[2]),
		.wram_for_sub(reg_2002_do[1]),
		.asic_irq(irq1)
);

//***************************************************************************	color calc
	wire [15:0]reg_804C_do ,reg_804E_do, reg_8050_do, reg_8052_do, reg_8054_do, reg_8056_do;
	
	color_calc color_calc_inst(
	
		.clk_asic(clk_asic),
		.sub_data(sub.dato),
		.regs_addr_sub(regs_addr_sub),
		.regs_we_lo_sub(regs_we_lo_sub),
		.regs_we_hi_sub(regs_we_hi_sub),
		
		.reg_804C_do(reg_804C_do),
		.reg_804E_do(reg_804E_do),
		.reg_8050_do(reg_8050_do), 
		.reg_8052_do(reg_8052_do), 
		.reg_8054_do(reg_8054_do), 
		.reg_8056_do(reg_8056_do)
);	
//***************************************************************************	regs main 2000
	wire regs_ce_main = main_ce_regs;
	wire regs_we_lo_main = regs_ce_main & main_we_lo_sync;
	wire regs_we_hi_main = regs_ce_main & main_we_hi_sync;
	wire [12:0]regs_addr_main = {main_addr[12:1], 1'b0};
	
	
	wire [15:0]reg_do_main = 
	regs_addr_main == 8'h00 ? reg_2000_do : 
	regs_addr_main == 8'h02 ? reg_2002_do : 
	regs_addr_main == 8'h06 ? reg_2006 : 
	regs_addr_main == 8'h04 ? {reg_8004_do[15:8], 8'h00} : 
	regs_addr_main == 8'h08 ? reg_8008_do : 
	regs_addr_main == 8'h0C ? reg_800C_do :
	regs_addr_main == 8'h0E ? reg_200E_do :
	com_cmd_ce_main			? reg_201X[regs_addr_main[3:1]] : 
	com_sta_ce_main			? reg_802X[regs_addr_main[3:1]] : 
	16'hFFFF;
	
	
	/*
	sync_edge regs_ce_sync(.clk(clk_asic), .ce(regs_ce_main), .sync(regs_ce_main_edge));
	reg [15:0]reg_do_main_sync;
	always @(posedge clk_asic)*/
	
	
	reg [15:0]reg_do_main_sync;
	reg [3:0]reg_ce_main_st;
		
	always @(posedge clk_asic)
	begin
		reg_ce_main_st[3:0] <= {reg_ce_main_st[2:0], regs_ce_main};
		if(reg_ce_main_st[2:0] == 3'b011)reg_do_main_sync <= reg_do_main;
		//if(!regs_ce_main)reg_do_main_sync <= reg_do_main;
	end
	

	reg com_cmd_ce_main, com_sta_ce_main;
	
	always @(posedge clk_asic)
	begin
		com_cmd_ce_main <= regs_ce_main & {regs_addr_main[12:4], 4'd0} == 8'h10;
		com_sta_ce_main <= regs_ce_main & {regs_addr_main[12:4], 4'd0} == 8'h20;
	end
	
	initial reg_2006[15:0] = 16'hffff;
	
	reg [15:0]reg_2000, reg_2006, reg_200E;
	reg [15:0]reg_201X[8];

	wire [15:0]reg_2000_do = {ga_ien[2], 6'd0, irq_pend[2], 6'd0, bus_req, ga_sres};//bit 15 shown unknown status, likely it ien2
	wire [15:0]reg_200E_do = {reg_200E[15:8], reg_800E[7:0]};
	

	wire ga_sbrq = reg_2000[1];//sub bus req
	wire ga_sres = reg_2000[0];//sub reset
	wire bus_req = (!sub_in.halt & sub.as & sub_in.dtak) | sub_in.rst;//(!sub_br & !sub_bg) | sub_in.rst;
	
	

	wire main_we_lo_sync = main_we_lo_st[1:0] == 2'b10;
	wire main_we_hi_sync = main_we_hi_st[1:0] == 2'b10;
	reg [3:0]main_we_lo_st, main_we_hi_st;
	
	
	always @(posedge clk_asic)
	if(map_rst)
	begin
		reg_2006[15:0] <= 16'hffff;
		reg_2000[15:0] <= 0;
	end
		else
	if(sub_sync)
	begin
		
		main_we_lo_st[3:0] <= {main_we_lo_st[2:0], main_we_lo};
		main_we_hi_st[3:0] <= {main_we_hi_st[2:0], main_we_hi};
		
		if(regs_we_hi_main)
		case(regs_addr_main)
			8'h00:reg_2000[15:8] 	<= main_dout[15:8];//irq2
			8'h10:reg_201X[0][15:8] <= main_dout[15:8];
			8'h12:reg_201X[1][15:8] <= main_dout[15:8];
			8'h14:reg_201X[2][15:8] <= main_dout[15:8];
			8'h16:reg_201X[3][15:8] <= main_dout[15:8];
			8'h18:reg_201X[4][15:8] <= main_dout[15:8];
			8'h1A:reg_201X[5][15:8] <= main_dout[15:8];
			8'h1C:reg_201X[6][15:8] <= main_dout[15:8];
			8'h1E:reg_201X[7][15:8] <= main_dout[15:8];
		endcase
		
		
		if(regs_we_lo_main)
		case(regs_addr_main)
			8'h00:reg_2000[7:0] <= main_dout[7:0];//reset halt
			8'h10:reg_201X[0][7:0] <= main_dout[7:0];
			8'h12:reg_201X[1][7:0] <= main_dout[7:0];
			8'h14:reg_201X[2][7:0] <= main_dout[7:0];
			8'h16:reg_201X[3][7:0] <= main_dout[7:0];
			8'h18:reg_201X[4][7:0] <= main_dout[7:0];
			8'h1A:reg_201X[5][7:0] <= main_dout[7:0];
			8'h1C:reg_201X[6][7:0] <= main_dout[7:0];
			8'h1E:reg_201X[7][7:0] <= main_dout[7:0];
		endcase
		
		
		if(regs_we_lo_main | regs_we_hi_main)
		case(regs_addr_main)
			8'h06:reg_2006[15:0] <= main_dout[15:0];//hint
			8'h0E:reg_200E[15:8] <= main_dout[15:8];//communication flag
		endcase
		
	end	

	
//***************************************************************************	regs sub	8000
	wire regs_ce_sub = !sub.as & {sub.addr[23:15], 15'd0} == 24'hFF8000;
	wire regs_we_lo_sub_int = regs_ce_sub & !sub_we_lo & sub_sync;
	wire regs_we_hi_sub_int = regs_ce_sub & !sub_we_hi & sub_sync;//may be worth to remove sub_sync?
	wire regs_we_lo_sub = regs_we_lo_sub_int & !regs_we_lo_sub_st;
	wire regs_we_hi_sub = regs_we_hi_sub_int & !regs_we_hi_sub_st;
	wire regs_oe_sub = regs_ce_sub & !sub_oe;
	wire [14:0]regs_addr_sub = sub.addr[14:0];
	

	
	wire [15:0]reg_do_sub = 
	
	
	regs_addr_sub == 9'h000 ? reg_8000_do :
	regs_addr_sub == 9'h002 ? reg_8002_do :
	
	regs_addr_sub == 9'h004 ? reg_8004_do :
	regs_addr_sub == 9'h006 ? reg_8006_do :
	regs_addr_sub == 9'h008 ? reg_8008_do :
	regs_addr_sub == 9'h00A ? reg_800A_do :
	
	regs_addr_sub == 9'h00C ? reg_800C_do :
	regs_addr_sub == 9'h00E ? reg_800E_do :
	regs_addr_sub == 9'h030 ? reg_8030_do :	
	com_cmd_ce_sub				? reg_201X[regs_addr_sub[3:1]] : 
	com_sta_ce_sub				? reg_802X[regs_addr_sub[3:1]] : 
	regs_addr_sub == 9'h032 ? reg_8032_do :
	
	
	regs_addr_sub == 9'h034 ? reg_8034_do :
	regs_addr_sub == 9'h036 ? reg_8036_do :
	
	
	regs_addr_sub == 9'h038 ? reg_8038_do :
	regs_addr_sub == 9'h03A ? reg_803A_do :
	regs_addr_sub == 9'h03C ? reg_803C_do :
	regs_addr_sub == 9'h03E ? reg_803E_do :
	regs_addr_sub == 9'h040 ? reg_8040_do :
	
	regs_addr_sub == 9'h042 ? reg_8042_do :
	regs_addr_sub == 9'h044 ? reg_8044_do :
	regs_addr_sub == 9'h046 ? reg_8046_do :
	regs_addr_sub == 9'h048 ? reg_8048_do :
	regs_addr_sub == 9'h04A ? reg_804A_do :
	
	regs_addr_sub == 9'h04C ? reg_804C_do :
	regs_addr_sub == 9'h04E ? reg_804E_do :
	regs_addr_sub == 9'h050 ? reg_8050_do :
	regs_addr_sub == 9'h052 ? reg_8052_do :
	regs_addr_sub == 9'h054 ? reg_8054_do :
	regs_addr_sub == 9'h056 ? reg_8056_do :
	
	regs_addr_sub == 9'h058 ? reg_8058_do :
	regs_addr_sub == 9'h05A ? reg_805A_do :
	regs_addr_sub == 9'h05C ? reg_805C_do :
	regs_addr_sub == 9'h05E ? reg_805E_do :
	
	regs_addr_sub == 9'h060 ? reg_8060_do :
	regs_addr_sub == 9'h062 ? reg_8062_do :
	regs_addr_sub == 9'h064 ? reg_8064_do :
	regs_addr_sub == 9'h066 ? reg_8066_do :
	
	16'h0000;
	

	reg regs_we_lo_sub_st, regs_we_hi_sub_st;
	reg [15:0]reg_8000, reg_8032, reg_800E;
	reg [15:0]reg_802X[8];
	
	wire [15:0]reg_8000_do = {6'd0, led[1:0], 4'd0, 3'd0, pi_ready};
	wire [15:0]reg_800E_do = {reg_200E[15:8], reg_800E[7:0]};
	wire [15:0]reg_8032_do = {9'd0, ga_ien[6:1], 1'b0};
	
	
	assign led[1:0] = reg_8000[9:8];
	wire [6:1]ga_ien = reg_8032[6:1];
	
	wire com_cmd_ce_sub = regs_ce_sub & {regs_addr_sub[14:4], 4'd0} == 9'h010;
	wire com_sta_ce_sub = regs_ce_sub & {regs_addr_sub[14:4], 4'd0} == 9'h020;

	
	always @(posedge clk_asic, posedge cd_rst)
	if(cd_rst)
	begin
		reg_8032 <= 0;
		reg_8000 <= 0;
	end
		else
	if(sub_sync)
	begin
		
		regs_we_lo_sub_st <= regs_we_lo_sub_int;
		regs_we_hi_sub_st <= regs_we_hi_sub_int;
		
		if(regs_we_hi_sub)
		case(regs_addr_sub)
			9'h000:reg_8000[15:8] 	 <= sub.dato[15:8];
			9'h020:reg_802X[0][15:8] <= sub.dato[15:8];
			9'h022:reg_802X[1][15:8] <= sub.dato[15:8];
			9'h024:reg_802X[2][15:8] <= sub.dato[15:8];
			9'h026:reg_802X[3][15:8] <= sub.dato[15:8];
			9'h028:reg_802X[4][15:8] <= sub.dato[15:8];
			9'h02A:reg_802X[5][15:8] <= sub.dato[15:8];
			9'h02C:reg_802X[6][15:8] <= sub.dato[15:8];
			9'h02E:reg_802X[7][15:8] <= sub.dato[15:8];
		endcase
		
		if(regs_we_lo_sub)
		case(regs_addr_sub)
			9'h000:reg_8000[7:0] 	<= sub.dato[7:0];
			9'h020:reg_802X[0][7:0] <= sub.dato[7:0];
			9'h022:reg_802X[1][7:0] <= sub.dato[7:0];
			9'h024:reg_802X[2][7:0] <= sub.dato[7:0];
			9'h026:reg_802X[3][7:0] <= sub.dato[7:0];
			9'h028:reg_802X[4][7:0] <= sub.dato[7:0];
			9'h02A:reg_802X[5][7:0] <= sub.dato[7:0];
			9'h02C:reg_802X[6][7:0] <= sub.dato[7:0];
			9'h02E:reg_802X[7][7:0] <= sub.dato[7:0];
			9'h032:reg_8032[7:0] 	<= sub.dato[7:0];
		endcase
		
		if(regs_we_hi_sub | regs_we_lo_sub)
		case(regs_addr_sub)
			9'h00E:reg_800E[7:0] 	<= sub.dato[7:0];
		endcase
		
	end
	
//*************************************************************************** sub memory mapping	
	assign sub_in.dati[15:0] = 
	regs_ce_pcm ? regs_do_pcm :
	regs_ce_sub ? reg_do_sub : 
	wram_ce_sub ? wram_dout_sub : 
	bram_ce ? {8'h80, bram_dout[7:0]} :
	prg_dout;
//*************************************************************************** sub cpu	
	wire sub_halt_req = (dma.ce_pram | wram_halt_req | dma.ce_pcm | cd_halt);//probably for pram should be used halt insyead of dtak
	wire sub_halt_act = (dtak_delay != 0 | sub_halt_req | wait_wram);
	//wire sub_halt_act = (dtak_delay != 0 | sub_halt_req | wait_wram) & !sub.as;
	
	
	reg [3:0]dtak_delay;
	always @(posedge clk_asic)
	begin
		//if(sub_halt_req)dtak_delay <= 8;
		if(sub_halt_req & !sub.as)dtak_delay <= 8;
			else
		if(dtak_delay != 0)dtak_delay <= dtak_delay - 1;
	end
	
	wire wait_wram = 0;//wram_ce_sub & wram_delay != 0;
	reg [3:0]wram_delay;
	always @(posedge clk_asic)
	begin
		if(!wram_ce_sub)wram_delay <= 16;
			else
		if(wram_delay)wram_delay <= wram_delay - 1;
	end
	
	wire sub_sync =  sub_in.clk_p & !cd_halt;
	
	reg [1:0]clk_div;
	always @(posedge clk_asic)
	begin
		clk_div <= clk_div + 1;
	end
	
		
	wire sub_oe = 		!(sub.rw == 1 & !sub.as);
	wire sub_we_lo = 	!(sub.rw == 0 & !sub.lds & !sub.as);
	wire sub_we_hi = 	!(sub.rw == 0 & !sub.uds & !sub.as);
	
	
	assign sub_in.rst				= map_rst | !ga_sres;
	assign sub_in.clk_n			= clk_div[1:0] == 2'b01;
	assign sub_in.clk_p			= clk_div[1:0] == 2'b11;
	assign sub_in.halt			= !(ga_sbrq);
	assign sub_in.dtak			= !(!sub.as & !sub_halt_act & !dbg_halt);
	//assign sub_in.vpa				= sub_vpa;//Valid Peripheral Address
	assign sub_in.br				= 1;//bus request
	assign sub_in.bgack			= 1;
	//assign sub_in.ipl[2:0]		= sub_ipl[2:0];
	

	cpu cpu_inst(
	
		.clk(clk_asic),
		.cpu_in(sub_in),
		.cpu_out(sub)
	);

	
	wire irq2 = regs_we_hi_main & regs_addr_main == 8'h00 & main_dout[8] == 1;
	
	assign ireq[1] = irq1;
	assign ireq[2] = irq2;
	assign ireq[3] = irq3;
	assign ireq[4] = irq4;
	assign ireq[5] = irq5;
	
	
	wire [6:1]ireq;
	wire [6:1]irq_pend;
	
	irq_ctrl irq_inst(
	
		.rst(sub_in.rst),
		.clk_asic(clk_asic),
		.sub_sync(sub_sync),
		.ireq(ireq),
		.imsk(ga_ien),
		.cpu_fc(sub.fc),
		.cpu_ipl(sub_in.ipl),
		.cpu_vpa(sub_in.vpa),
		.cpu_addr(sub.addr[3:1]),
		.cpu_oe(sub_oe),
		.irq_pend_out(irq_pend)
	);
	

	
//*************************************************************************** var	

	wire pi_ready;
	wire pi_rst;
	
	pi_rest pi_rst_inst(
		.clk_asic(clk_asic),
		.sub_sync(sub_sync),
		.sub_rst(sub_in.rst),
		.sub_data(sub.dato),
		.reg_addr(regs_addr_sub),
		.regs_we_lo_sub(regs_we_lo_sub),
		.pi_ready(pi_ready),
		.pi_rst(pi_rst),
	 );
	 
	 wire [15:0]reg_800C_do;
	 timer_800C tmr_800C(
		.rst(cd_rst),
		.clk_asic(clk_asic),
		.sub_sync(sub_sync),
		.reg_addr(regs_addr_sub),
		.regs_we_lo_sub(regs_we_lo_sub),
		.regs_we_hi_sub(regs_we_hi_sub),
		.reg_800C_do(reg_800C_do)
	 );
	 
	 
	 wire irq3;
	 wire [15:0]reg_8030_do;
	 timer_8030 tmr_8030(
		.rst(cd_rst),
		.clk_asic(clk_asic),
		.sub_sync(sub_sync),
		.regs_we_lo_sub(regs_we_lo_sub),
		.regs_we_hi_sub(regs_we_hi_sub),
		.sub_data(sub.dato),
		.reg_addr(regs_addr_sub),
		.reg_8030_do(reg_8030_do),
		.irq(irq3)
	);
	
//*************************************************************************** dbg	
	wire dbg_halt;
	
	
	
endmodule






