
module wram_ctrl(
	
	input clk_asic, 
	input sub_sync,
	input cd_rst, 
	
	output [15:0]wram_din_a,
	input  [15:0]wram_dout_a,
	output [16:0]wram_addr_a,
	output [3:0]wram_mask_a,
	output [1:0]wram_mode_a,
	
	
	output [15:0]wram_din_b,
	input  [15:0]wram_dout_b,
	output [16:0]wram_addr_b,
	output [3:0]wram_mask_b,
	output [1:0]wram_mode_b,

	output [15:0]wram_dout_main,
	output [15:0]wram_dout_sub,
	output [15:0]reg_2002_do, reg_8002_do,
	
	input [15:0]main_data,
	input [17:1]main_addr,
	input main_we_lo, main_we_hi, main_oe, main_vdp_dma,
	
	
	input [15:0]sub_data,
	input [23:0]sub_addr,
	input sub_we_lo, sub_we_hi, sub_oe,
	
	input regs_we_lo_main, regs_we_hi_main,
	input regs_we_lo_sub, regs_we_hi_sub,
	input wram_ce_main, wram_ce_sub,

	output [15:0]wram_dout_asic,
	input [15:0]wram_din_asic,
	input [17:1]wram_addr_asic,
	input wram_we_asic, wram_oe_asic,
	
	input [18:0]dma_addr,
	input [15:0]dma_dat,
	input dma_ce_wram,
	input dma_we,
	
	output wram_halt_req
);


//***************************************************************************	regs
	wire [14:0]regs_addr_sub = sub_addr[14:0];
	wire [12:0]regs_addr_main = {main_addr[12:1], 1'b0};
	//MODE0=2M, MODE1=1M
	wire DMNA = MODE == 0 ? dmna_m0 : dmna_m1;//wram cdc dma relays on this bit. halted if 0 in 2m mode
	wire RET  = MODE == 0 ? ret_m0  : ret_m1;
	wire [7:0]WP = reg_2002[15:8];
	wire [1:0]BK = reg_2002[7:6];
	
	wire MODE = reg_8002[2];
	wire [1:0]PM = reg_8002[4:3];
	
	
	wire ret_m0 = !dmna_m0;
	
	
	reg [15:0]reg_2002;
	reg [15:0]reg_8002;
	reg dmna_m0;
	reg dmna_m1;
	reg ret_m1;
	
	always @(negedge clk_asic)
	if(cd_rst)
	begin
		reg_2002[15:0] <= 0;
		reg_8002[7:0] <= 0;
		dmna_m0 <= 0;
		dmna_m1 <= 0;
		ret_m1 <= 1;
	end
		else
	if(sub_sync)
	begin
	
		if(regs_we_hi_main & regs_addr_main == 8'h02)reg_2002[15:8] <= main_data[15:8];
		if(regs_we_lo_main & regs_addr_main == 8'h02)reg_2002[7:0] <= main_data[7:0];	
		
//************************************************************************* wram mode control
		
		if(regs_we_lo_main & regs_addr_main == 8'h02)
		begin
			if(main_data[1] == 1)dmna_m0 <= 1;
			if(main_data[1] == 0)dmna_m1 <= 1;
		end
		
		if((regs_we_lo_sub | regs_we_hi_sub) & regs_addr_sub == 9'h002)
		begin
		
			reg_8002[7:0] <= sub_data[7:0];
			
			if(sub_data[0] == 1)dmna_m0 <= 0;
			
			ret_m1 <= sub_data[0];
			if(ret_m1 != sub_data[0])dmna_m1 <= 0;
			
		end
		
	end
	
	
	assign reg_2002_do[15:0] = {WP[7:0], BK[1:0], 3'd0, MODE, DMNA, RET};
	assign reg_8002_do[15:0] = {WP[7:0], 3'd0, PM[1:0], MODE, DMNA, RET};
	
//***************************************************************************
	parameter SEL_MAI = 0;
	parameter SEL_SUB = 1;
	wire mem_sel_a = (MODE == 0 & RET == 1) | (MODE == 1 & RET == 0) ? SEL_MAI : SEL_SUB;
	wire mem_sel_b = (MODE == 0 & RET == 1) | (MODE == 1 & RET == 1) ? SEL_MAI : SEL_SUB;
	
	//wire prohibited = wram_ce_sub & MODE == 0 & sub_addr >= 24'hC0000;
	assign wram_halt_req = (MODE == 0 & wram_ce_sub & DMNA == 0) | asic_halt_req | dma_hlat_req;

	
//************************************************************************************************************** buffered memory	
	wire mem_oe_main_a = wram_ce_main & !main_oe;
	wire mem_oe_main_b = wram_ce_main & !main_oe;
	wire mem_oe_main_x = mem_oe_main_a | mem_oe_main_b;

	reg [3:0]main_oe_st;
	reg [15:0]dbuff_main[2];
	reg mem_oe_st;
	
	always @(negedge clk_asic)
	begin
		main_oe_st[3:0] <= {main_oe_st[2:0], mem_oe_main_x};
		
		if(mem_oe_main_x)dbuff_main[0] <= mai_data_rx;
		
		if(main_oe_st[2:0] == 3'b110)dbuff_main[1] <= dbuff_main[0];
	end	
//************************************************************************************************************** glue
	parameter MAI = 0;
	parameter SUB = 1;
	wire mem_master_a = (MODE == 0 & RET == 1) | (MODE == 1 & RET == 0) ? MAI : SUB;
	wire mem_master_b = (MODE == 0 & RET == 1) | (MODE == 1 & RET == 1) ? MAI : SUB;
	
	wire mem_ce_a_mai = (MODE == 1 | main_addr[1] == 0) & wram_ce_main & mem_master_a == MAI;
	wire mem_ce_b_mai = (MODE == 1 | main_addr[1] == 1) & wram_ce_main & mem_master_b == MAI;
	wire mem_ce_a_sub = (MODE == 1 | sub_addr[1] == 0) & wram_ce_sub & mem_master_a == SUB;
	wire mem_ce_b_sub = (MODE == 1 | sub_addr[1] == 1) & wram_ce_sub & mem_master_b == SUB;

	assign wram_dout_main[15:0] = main_vdp_dma ? dbuff_main[1] : mai_data_rx;
	assign wram_dout_sub[15:0]  = sub_data_rx;
	
	assign {wram_mode_a[1:0], wram_mask_a[3:0], wram_addr_a[16:1], wram_din_a[15:0]} = mem_ctrl_a[37:0];
	assign {wram_mode_b[1:0], wram_mask_b[3:0], wram_addr_b[16:1], wram_din_b[15:0]} = mem_ctrl_b[37:0];
	
	
	wire [37:0]mem_ctrl_a = mem_master_a == MAI ? mem_ctrl_a_mai : dma_sel_a ? mem_ctrl_dma : asic_sel_a ? mem_ctrl_asic : mem_ctrl_a_sub;
	wire [37:0]mem_ctrl_b = mem_master_b == MAI ? mem_ctrl_b_mai : dma_sel_b ? mem_ctrl_dma : asic_sel_b ? mem_ctrl_asic : mem_ctrl_b_sub;
	
	
	wire [37:0]mem_ctrl_a_mai = MODE == 0 ? mem_ctrl_a_mai_m0 : mem_ctrl_x_mai_m1;
	wire [37:0]mem_ctrl_b_mai = MODE == 0 ? mem_ctrl_b_mai_m0 : mem_ctrl_x_mai_m1;
	wire [37:0]mem_ctrl_a_sub = MODE == 0 ? mem_ctrl_a_sub_m0 : mem_ctrl_x_sub_m1;
	wire [37:0]mem_ctrl_b_sub = MODE == 0 ? mem_ctrl_b_sub_m0 : mem_ctrl_x_sub_m1;
//************************************************************************************************************** main	
	wire [37:0]mem_ctrl_a_mai_m0 = {2'b00, msk_a_mai_m0[3:0], main_addr[17:2], main_data[15:0]};
	wire [37:0]mem_ctrl_b_mai_m0 = {2'b00, msk_b_mai_m0[3:0], main_addr[17:2], main_data[15:0]};
	wire [37:0]mem_ctrl_x_mai_m1 = {2'b00, msk_x_mai_m1[3:0], addr_main_m1[16:1], main_data[15:0]};
	
	wire [3:0]msk_a_mai_m0 = wram_ce_main & main_addr[1] == 0 ? {!main_we_hi, !main_we_hi, !main_we_lo, !main_we_lo} : 4'b0000;
	wire [3:0]msk_b_mai_m0 = wram_ce_main & main_addr[1] == 1 ? {!main_we_hi, !main_we_hi, !main_we_lo, !main_we_lo} : 4'b0000;
	wire [3:0]msk_x_mai_m1 = wram_ce_main ? {!main_we_hi, !main_we_hi, !main_we_lo, !main_we_lo} : 4'b0000;//same for both
	
	wire [16:1]addr_main_m1 = main_addr[17] == 0 ? addr_main_m1_20 : addr_main_m1_22;
	wire [16:1]addr_main_m1_20 = main_addr[16:1];
	wire [16:1]addr_main_m1_22 = 
	main_addr[16] == 0 ? {main_addr[16],    main_addr[9:2], main_addr[15:10], main_addr[1]} : 
	main_addr[15] == 0 ? {main_addr[16:15], main_addr[8:2], main_addr[14:9], main_addr[1]} : 
	main_addr[14] == 0 ? {main_addr[16:14], main_addr[7:2], main_addr[13:8], main_addr[1]} : 
								{main_addr[16:13], main_addr[6:2], main_addr[12:7], main_addr[1]}; 

								
	wire [15:0]mai_data_rx = MODE == 0 ? mai_data_r0 : mai_data_r1;
	wire [15:0]mai_data_r0 = main_addr[1] == 0 ? wram_dout_a[15:0] : wram_dout_b[15:0];
	wire [15:0]mai_data_r1 = RET == 0 ? wram_dout_a[15:0] : wram_dout_b[15:0];
//************************************************************************************************************** sub	
	wire [37:0]mem_ctrl_a_sub_m0 = {2'b00, msk_a_sub_m0[3:0], sub_addr[17:2], sub_data[15:0]};
	wire [37:0]mem_ctrl_b_sub_m0 = {2'b00, msk_b_sub_m0[3:0], sub_addr[17:2], sub_data[15:0]};
	wire [37:0]mem_ctrl_x_sub_m1 = {mod_x_sub_m1, msk_x_sub_m1[3:0], addr_sub_m1[16:1], data_sub_m1[15:0]};
	
	wire [3:0]msk_a_sub_m0 = wram_ce_sub & sub_addr[1] == 0 ? {!sub_we_hi, !sub_we_hi, !sub_we_lo, !sub_we_lo} : 4'b0000;
	wire [3:0]msk_b_sub_m0 = wram_ce_sub & sub_addr[1] == 1 ? {!sub_we_hi, !sub_we_hi, !sub_we_lo, !sub_we_lo} : 4'b0000;
	wire [1:0]mod_x_sub_m1 = sub_addr[18] == 0 ? PM[1:0] : 2'b00;
	
	wire [3:0]msk_x_sub_m1 = 
	!wram_ce_sub ? 4'b0000 :
	sub_addr[18] == 1 ? {!sub_we_hi, !sub_we_hi, !sub_we_lo, !sub_we_lo} : 
	{sub_addr[1] == 0 & !sub_we_hi, sub_addr[1] == 0 & !sub_we_lo, sub_addr[1] == 1 & !sub_we_hi, sub_addr[1] == 1 & !sub_we_lo};

	wire [16:1]addr_sub_m1 = sub_addr[18] == 1 ? addr_sub_m1_C0 : addr_sub_m1_80;
	wire [16:1]addr_sub_m1_80 = sub_addr[17:2];
	wire [16:1]addr_sub_m1_C0 = sub_addr[16:1];
	
	wire [15:0]data_sub_m1 = sub_addr[18] == 1 ? sub_data : {sub_data[11:8], sub_data[3:0], sub_data[11:8], sub_data[3:0]};
	

	wire [15:0]sub_data_rx = MODE == 0 ? sub_data_r0 : sub_data_r1;
	wire [15:0]sub_data_r0 = sub_addr[1] == 0 ? wram_dout_a[15:0] : wram_dout_b[15:0];
	wire [15:0]sub_data_r1 = sub_addr[18] == 1 | sub_oe ? sub_data_s1 : sub_addr[1] == 0 ? {4'd0, sub_data_s1[15:12], 4'd0, sub_data_s1[11:8]} : {4'd0, sub_data_s1[7:4], 4'd0, sub_data_s1[3:0]};
	wire [15:0]sub_data_s1 = RET == 1 ? wram_dout_a[15:0] : wram_dout_b[15:0];
//************************************************************************************************************** asic	
	wire [3:0]msk_asic = wram_we_asic ? 4'b1111 : 0;
	assign wram_dout_asic = wram_addr_asic[1] == 0 ? wram_dout_a : wram_dout_b;
	wire asic_sel = MODE == 0 & DMNA == 1 & (wram_we_asic | wram_oe_asic);
	wire asic_sel_a = asic_sel & wram_addr_asic[1] == 0;
	wire asic_sel_b = asic_sel & wram_addr_asic[1] == 1;
	wire asic_halt_req = (asic_sel_a & mem_ce_a_sub) | (asic_sel_b & mem_ce_b_sub);//may be should be activated one cycle before using?*/
	
	wire [37:0]mem_ctrl_asic = {PM[1:0], msk_asic[3:0], wram_addr_asic[17:2], wram_din_asic[15:0]};
//************************************************************************************************************** dma	
	wire [3:0]msk_dma = dma_ce_wram & dma_we ? 4'b1111 : 0;
	wire dma_sel_a_m0 = dma_ce_wram & mem_master_a == SUB & dma_addr[1] == 0;
	wire dma_sel_b_m0 = dma_ce_wram & mem_master_b == SUB & dma_addr[1] == 1;
	wire dma_sel_a_m1 = dma_ce_wram & mem_master_a == SUB;
	wire dma_sel_b_m1 = dma_ce_wram & mem_master_b == SUB;
	wire dma_sel_a = MODE == 0 ? dma_sel_a_m0 : dma_sel_a_m1;
	wire dma_sel_b = MODE == 0 ? dma_sel_b_m0 : dma_sel_b_m1;
	wire [16:1]dma_addr_x = MODE == 0 ? dma_addr[17:2] : dma_addr[16:1];
	wire dma_hlat_req =  (dma_sel_a & mem_ce_a_sub) | (dma_sel_b & mem_ce_b_sub);
	
	wire [37:0]mem_ctrl_dma = {2'b00, 4'b1111, dma_addr_x[16:1], dma_dat[15:0]};

	
endmodule


/*
//***************************************************************************	regs
	wire [14:0]regs_addr_sub = sub_addr[14:0];
	wire [12:0]regs_addr_main = {main_addr[12:1], 1'b0};
	//MODE0=2M, MODE1=1M
	wire DMNA = MODE == 1 ? (ret_req ^ ret_m1) : dmna_m0;//wram cdc dma relays on this bit. halted if 0 in 2m mode
	wire RET  = MODE == 1 ? ret_m1 : !DMNA;
	wire [7:0]WP = reg_2002[15:8];
	wire [1:0]BK = reg_2002[7:6];
	
	wire MODE = reg_8002[2];
	wire [1:0]PM = reg_8002[4:3];
	
	
	
	wire sub_we = (!sub_we_lo | !sub_we_hi);
	wire swap_req = regs_we_lo_main & regs_addr_main == 8'h02 & main_data[1] == 0;//dmna 0
	
	wire ret_m1 = reg_8002[0];
	
	wire set_dmna_m0 = regs_we_lo_main & regs_addr_main == 8'h02;
	wire set_ret_m0 = sub_we & regs_ce_sub & regs_addr_sub == 9'h002;
	
	
	reg [15:0]reg_2002;
	reg [15:0]reg_8002;
	reg ret_req;
	reg dmna_m0;
	
	always @(negedge clk_asic)
	if(cd_rst)
	begin
		reg_2002[15:0] <= 0;
		reg_8002[7:0] <= 0;
		ret_req <= 0;
		dmna_m0 <= 0;
	end
		else
	if(sub_sync)
	begin
	
		if(regs_we_hi_main & regs_addr_main == 8'h02)reg_2002[15:8] <= main_data[15:8];
		if(regs_we_lo_main & regs_addr_main == 8'h02)reg_2002[7:0] <= main_data[7:0];	
		
//************************************************************************* mode 0 
		if(set_dmna_m0)
		begin
			if(dmna_m0 == 0)dmna_m0 <= main_data[1];
		end
			else
		if(set_ret_m0)
		begin
			if(dmna_m0 == 1)dmna_m0 <= !sub_data[0];
		end
//************************************************************************* mode 1
		if(swap_req)ret_req <= !ret_m1;//main
		
		if(sub_we & regs_ce_sub & regs_addr_sub == 9'h002)
		begin
		
			reg_8002[7:0] <= sub_data[7:0];
			
			//was observed during testing real hardware, but by some reasons this behaviour brokes Dark Wizard and Stellar-Fire
			//if(reg_8002[2] == 0 & sub_data[2] == 1);//skip ret_req modification when switching from 2m to 1m. 
				//else
			if(ret_req == ret_m1 & !swap_req)ret_req <= sub_data[0];
			
			
		end
		
	end
	
	
	assign reg_2002_do[15:0] = {WP[7:0], BK[1:0], 3'd0, MODE, DMNA, RET};
	assign reg_8002_do[15:0] = {WP[7:0], 3'd0, PM[1:0], MODE, DMNA, RET};
*/	
