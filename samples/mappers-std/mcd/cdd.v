

module cdd(
	
	input rst, 
	input sys_rst,
	input clk_asic,
	input sub_sync,
	input cdc_host_data_main,
	

	input [15:0]sub_data,
	input [14:0]reg_addr,
	input sub_as,
	input regs_we_lo_sub, regs_we_hi_sub,
	input regs_oe_sub,
	input bus_req,
	
	input  [15:0]reg_8002_do,
	output [15:0]reg_8034_do, reg_8036_do,
	output [15:0]reg_8038_do, reg_803A_do, reg_803C_do, reg_803E_do, reg_8040_do, 
	output [15:0]reg_8042_do, reg_8044_do, reg_8046_do, reg_8048_do, reg_804A_do, 

	input McdIO cdio,
	output [7:0]cdio_di,
	
	output frame_sync,
	output irq4,
	
	output [15:0]reg_8004_do, reg_8006_do, reg_8008_do, reg_800A_do, 
	output irq5,
	
	output [18:0]dma_addr,
	output [15:0]dma_dat,
	output dma_ce_wram, dma_ce_pram, dma_ce_pcm, 
	output dma_ce_main, dma_ce_sub,
	output dma_we,
	
	output signed[15:0]vol_l, vol_r,
	output cdda_sync,
	output dac_clk,
	output [7:0]dbg
);
	
	
	wire DRS = 0;
	wire DTS = 0;
	assign reg_8036_do[2:0] = {7'hd0, mute, 5'd0, reg_8036[2], DRS, DTS};
	
	assign reg_8038_do[11:8] = cdd_sta[0];
	assign reg_8038_do[7:0]  = cdd_sta[1];
	
	assign reg_803A_do[11:8] = cdd_sta[2];
	assign reg_803A_do[7:0]  = cdd_sta[3];
	assign reg_803C_do[11:8] = cdd_sta[4];
	assign reg_803C_do[7:0]  = cdd_sta[5];
	assign reg_803E_do[11:8] = cdd_sta[6];
	assign reg_803E_do[7:0]  = cdd_sta[7];
	
	assign reg_8040_do[11:8] = cdd_sta[8];
	assign reg_8040_do[7:0]  = cdd_sta[9];
	
	//assign irq4 = ctr == 166665 & hock_on;
	//assign irq4 = pi.map.mcd_irq & hock_on;
	assign irq4 = cdio.mcd_irq & hock_on;
	
	wire hock_on = reg_8036[2];
	wire regs_we_hi = regs_we_hi_sub;// regs_ce_sub & !sub_we_hi;
	wire regs_we_lo = regs_we_lo_sub;// regs_ce_sub & !sub_we_lo;
	wire regs_we_xx = (regs_we_hi_sub | regs_we_lo_sub);//regs_ce_sub & (regs_we_hi | regs_we_lo);
	
	reg [15:0]reg_8036;
	
	always @(negedge clk_asic)
	if(rst)
	begin
		reg_8036 <= 0;
	end
		else
	if(sub_sync)
	begin
		if(regs_we_lo & reg_addr == 9'h036)reg_8036[7:0] <= sub_data[7:0];
	end

//**************************************************************************************  frame counter
	assign frame_sync = fctr == 1;
	wire fsync 			= fctr == 2351 & dclk;
	
	
	reg [11:0]fctr;
	
	always @(negedge clk_asic)
	if(sys_rst)
	begin
		fctr 		<= 0;//important for sync with dac (lrck things)
	end
		else
	if(sub_sync & dclk)
	begin
		fctr 		<= fsync ? 0 : fctr + 1;
	end
	
//**************************************************************************************  cdd clock	
	reg dclk;
	reg dclk_st;
	reg [6:0]dclk_ctr;
	
	always @(negedge clk_asic)
	if(sys_rst)
	begin
		dclk_ctr 	<= 1;//important for sync with dac (lrck things)
		dclk			<= 0;
		dclk_st		<= 0;
	end
		else
	begin
		
		if(dac_clk)
		begin
			dclk_ctr <= dclk_ctr + 1;
		end
		
		if(sub_sync & dclk_st)
		begin
			dclk		<= 1;
		end
			else
		if(sub_sync)
		begin
			dclk 		<= 0;
		end

		
		//176400Hz clock (44100*512/128)
		if(dclk_ctr == 0 & dac_clk)
		begin
			dclk_st 	<= 1;
		end
			else
		if(sub_sync)
		begin
			dclk_st 	<= 0;
		end
		
	end
	

	
	clk_dvp_cd sclk_inst(

		.clk(clk_asic),
		.rst(sys_rst),
		.ck_base(50000000),
		.ck_targ(44100*512),
		.ck_out(dac_clk)
	);
	
//************************************************************************************** cdd communication	
	assign cdio_di[7:0] = 
	cdio.ce_cdd & cdio.addr[2:0] == 0 ? {cdd_cmd[0][3:0], cdd_cmd[1][3:0]} :
	cdio.ce_cdd & cdio.addr[2:0] == 1 ? {cdd_cmd[2][3:0], cdd_cmd[3][3:0]} :
	cdio.ce_cdd & cdio.addr[2:0] == 2 ? {cdd_cmd[4][3:0], cdd_cmd[5][3:0]} :
	cdio.ce_cdd & cdio.addr[2:0] == 3 ? {cdd_cmd[6][3:0], cdd_cmd[7][3:0]} :
	cdio.ce_cdd & cdio.addr[2:0] == 4 ? {cdd_cmd[8][3:0], cdd_cmd[9][3:0]} :
	cdio.ce_cdd ? 8'h00 :
	host_resp 	? 8'hff : 
					  8'h00;

	
	
	reg [5:0]cmd_addr;
	reg [3:0]cdd_cmd[10];
	reg [3:0]cdd_sta[10];
	reg host_resp;
	
	reg mute;
	
	always @(negedge clk_asic)
	if(rst)
	begin
		mute <= 1;
		//DRS <= 1;
		//frame_sync <= 0;
		host_resp <= 0;
	end
		else
	begin	
		
		if(cdio.mcd_mut0)mute <= 0;
			else
		if(cdio.mcd_mut1)mute <= 1;
		
//************************************************************************************************** receive data from cdd

		if(cdio.we_sync & hock_on)
		begin
			if(cdio.ce_cdd & cdio.addr[2:0] == 0){cdd_sta[0][3:0], cdd_sta[1][3:0]} <= cdio.dato[7:0];
			if(cdio.ce_cdd & cdio.addr[2:0] == 1){cdd_sta[2][3:0], cdd_sta[3][3:0]} <= cdio.dato[7:0];
			if(cdio.ce_cdd & cdio.addr[2:0] == 2){cdd_sta[4][3:0], cdd_sta[5][3:0]} <= cdio.dato[7:0];
			if(cdio.ce_cdd & cdio.addr[2:0] == 3){cdd_sta[6][3:0], cdd_sta[7][3:0]} <= cdio.dato[7:0];
			if(cdio.ce_cdd & cdio.addr[2:0] == 4){cdd_sta[8][3:0], cdd_sta[9][3:0]} <= cdio.dato[7:0];
		end
		
//************************************************************************************************** receive data from host

		if(sub_sync)
		begin
		
			if(regs_we_hi & reg_addr == 9'h042)cdd_cmd[0] <= sub_data[11:8];
			if(regs_we_lo & reg_addr == 9'h042)cdd_cmd[1] <= sub_data[3:0];
			
			if(regs_we_hi & reg_addr == 9'h044)cdd_cmd[2] <= sub_data[11:8];
			if(regs_we_lo & reg_addr == 9'h044)cdd_cmd[3] <= sub_data[3:0];
			
			if(regs_we_hi & reg_addr == 9'h046)cdd_cmd[4] <= sub_data[11:8];
			if(regs_we_lo & reg_addr == 9'h046)cdd_cmd[5] <= sub_data[3:0];
			
			if(regs_we_hi & reg_addr == 9'h048)cdd_cmd[6] <= sub_data[11:8];
			if(regs_we_lo & reg_addr == 9'h048)cdd_cmd[7] <= sub_data[3:0];
			
			if(regs_we_hi & reg_addr == 9'h04a)cdd_cmd[8] <= sub_data[11:8];
			if(regs_we_lo & reg_addr == 9'h04a)cdd_cmd[9] <= sub_data[3:0];
			
		end
		
		
		if(sub_sync & regs_we_xx & reg_addr == 9'h04A)host_resp <= 1;
			else
		if(cdio.mcd_rack)
		begin
			host_resp <= 0;
		end
		
	end
	


//************************************************************************************** 	cdc
	
	cdc cdc_inst(
	
			.rst(rst), 
			.clk_asic(clk_asic),
			.cdc_host_data_main(cdc_host_data_main),
			
			.sub_sync(sub_sync),
			.sub_data(sub_data),
			.reg_addr(reg_addr),
			.sub_as(sub_as),
			.regs_we_lo_sub(regs_we_lo_sub),
			.regs_we_hi_sub(regs_we_hi_sub),
			.regs_oe_sub(regs_oe_sub),
			.bus_req(bus_req),
			
			.reg_8002_do(reg_8002_do),
			.reg_8004_do(reg_8004_do), 
			.reg_8006_do(reg_8006_do), 
			.reg_8008_do(reg_8008_do), 
			.reg_800A_do(reg_800A_do),
			.irq5(irq5),
			
			.dma_addr(dma_addr),
			.dma_dat(dma_dat),
			.dma_ce_wram(dma_ce_wram), 
			.dma_ce_pram(dma_ce_pram), 
			.dma_ce_pcm(dma_ce_pcm), 
			.dma_ce_main(dma_ce_main), 
			.dma_ce_sub(dma_ce_sub),
			.dma_we(dma_we),
				
			.dclk(dclk),			
			.fsync(fsync),
			.cdio(cdio)
			//.dbg(dbg)
	);
	
	
	
	//************************************************************************************** 	fader
	assign cdda_sync = fctr[1:0] == 0;

	fader fader_inst(
		
		.rst(sys_rst),
		.clk_asic(clk_asic),
		.sub_data(sub_data),
		.reg_addr(reg_addr),
		.sub_sync(sub_sync),
		.regs_we_hi(regs_we_hi), 
		.regs_we_lo(regs_we_lo),
		.fsync(fsync), 
		.dclk(dclk), 
		.lr_ctr(fctr[1:0]),
		.cdio(cdio),
		.mcu_mute(mute),
		
		.reg_8034_do(reg_8034_do),
		.vol_l(vol_l), 
		.vol_r(vol_r)
);
	
endmodule


module fader(
	
	input rst,
	input clk_asic,
	input [15:0]sub_data,
	input [14:0]reg_addr,
	input sub_sync,
	input regs_we_hi, regs_we_lo,
	input fsync, dclk, 
	input [1:0]lr_ctr,
	input McdIO cdio,
	input mcu_mute,
	
	output [15:0]reg_8034_do,
	output reg signed[15:0]vol_l, vol_r
);

	
	assign reg_8034_do[15:0] = {EFDT, 15'd0};//was fixed. EFDT was out of 16 bit
	
	wire [10:0]fad_vol = reg_8034[14:4] >= 1024 ? 1024 : reg_8034[14:4];
	
	reg signed[11:0]cur_vol;
	reg [15:0]reg_8034;
	//reg [15:0]vol_buff[2];
	reg cdda_on;
	reg signed[15:0]vol_l_int, vol_r_int;
	reg EFDT;
	
	
	always @(negedge clk_asic)
	if(sub_sync & lr_ctr == 0 & dclk)
	begin
		if(cur_vol < fad_vol)cur_vol <= cur_vol + 1;
		if(cur_vol > fad_vol)cur_vol <= cur_vol - 1;
	end
	
	reg [7:0]vol_buff;
	
	reg [15:0]mul_l, mul_r;
	reg valid_vol;
	
	always @(negedge clk_asic)
	if(sub_sync)
	begin
		
		EFDT <= cur_vol != fad_vol;
		
		vol_l <= vol_l_int * cur_vol / 1024;
		vol_r <= vol_r_int * cur_vol / 1024;
		
	end
	
	always @(negedge clk_asic)
	if(rst)
	begin
		reg_8034[14:4] <= 1024;
	end
		else
	if(sub_sync)
	begin
		
		if(mcu_mute)
		begin
			cdda_on <= 0;
		end
			else
		if(fsync & !mcu_mute)
		begin
			cdda_on <= 1;
			if(!cdda_on)cdda_addr_rd <= cdda_addr_wr - 2352;
		end
		
		if(regs_we_hi & reg_addr == 9'h034)reg_8034[15:8] <= sub_data[15:8];
		if(regs_we_lo & reg_addr == 9'h034)reg_8034[7:0] <= sub_data[7:0];
		
		
		
		if(dclk)
		begin
		
			if(cdda_on == 0)valid_vol <= 0;
			if(cdda_on == 1 & lr_ctr == 3)valid_vol <= 1;

			vol_buff[7:0] <=  cdda_do[7:0];

			if(cdda_on == 1 & valid_vol)
			begin
				
				if(lr_ctr == 1)vol_l_int[15:0] <= {cdda_do[7:0], vol_buff[7:0]};
				if(lr_ctr == 3)vol_r_int[15:0] <= {cdda_do[7:0], vol_buff[7:0]};
				
			end
				else
			if(cdda_on == 0 & lr_ctr == 0)//roll back to mid state for click avoid.
			begin
				if(vol_l_int != 0)vol_l_int <= vol_l_int < 0 ? vol_l_int + 1 : vol_l_int - 1;
				if(vol_r_int != 0)vol_r_int <= vol_r_int < 0 ? vol_r_int + 1 : vol_r_int - 1;
			end
			
			if(cdda_on)cdda_addr_rd <= cdda_addr_rd + 1;
			
		end
		
	end
	
	
	
	always @(negedge clk_asic)
	begin
		if(cdda_we)cdda_addr_wr <= cdda_addr_wr + 1;
	end
	
	reg [12:0]cdda_addr_rd;
	reg [12:0]cdda_addr_wr;
	wire [7:0]cdda_do;
	wire cdda_we = cdio.ce_cdc & cdio.we_sync;
	
	ram_dp8x cdda_buff(

		.din(cdio.dato[7:0]),
		.dout(cdda_do),
		.we(cdda_we), 
		.clk(clk_asic),
		.addr_r(cdda_addr_rd),
		.addr_w(cdda_addr_wr)
	);

endmodule
