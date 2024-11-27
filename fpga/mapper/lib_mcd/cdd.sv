

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
	
	output McdDma dma,
	
	input  DacBus dac,
	output signed[15:0]snd_l,
	output signed[15:0]snd_r
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
	
	always @(posedge clk_asic)
	if(rst)
	begin
		reg_8036 <= 0;
	end
		else
	if(sub_sync)
	begin
		if(regs_we_lo & reg_addr == 9'h036)reg_8036[7:0] <= sub_data[7:0];
	end
	
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
	
	always @(posedge clk_asic)
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
			
			.dma(dma),
				
			.dclk(dclk),
			.cdio(cdio)
	);
//**************************************************************************************  frame counter
	assign frame_sync = fctr == 1;//mcu irq
	wire dclk 			= dac.phase[6:0] == 0 & dac.clk & !sys_rst;//176400Hz clock (44100*512/128)
	
	reg [11:0]fctr;
	
	always @(posedge clk_asic)
	if(sys_rst)
	begin
		fctr 		<= 0;
	end
		else
	if(dclk)
	begin
		fctr 		<= fctr == 2351 ? 0 : fctr + 1;
	end
//************************************************************************************** pcm fifo
	wire signed[15:0]pcm_l;
	wire signed[15:0]pcm_r;
	
	cdda_fifo cdda_fifo_inst(

		.clk(clk_asic),
		.cdio(cdio),
		.mcu_mute(mute),
		.snd_next_sample(dac.next_sample),
		.snd_phase(dac.phase),
		
		.pcm_l(pcm_l),
		.pcm_r(pcm_r)
	);
	
//************************************************************************************** 	fader
	fader fader_inst(
		
		.rst(sys_rst),
		.clk_asic(clk_asic),
		.sub_data(sub_data),
		.reg_addr(reg_addr),
		.sub_sync(sub_sync),
		.regs_we_hi(regs_we_hi), 
		.regs_we_lo(regs_we_lo),
		.reg_8034_do(reg_8034_do),
		
		.snd_next_sample(dac.next_sample),
		.snd_i_l(pcm_l),
		.snd_i_r(pcm_r),
		.snd_o_l(snd_l), 
		.snd_o_r(snd_r)
	);
	
endmodule

module cdda_fifo(

	input clk,
	input McdIO cdio,
	input mcu_mute,
	input snd_next_sample,
	input [8:0]snd_phase,
	
	output [15:0]pcm_l,
	output [15:0]pcm_r
);
	
	reg play_on;
	reg [12:0]in_buff;
	reg [7:0]pcm_do_lo;
	
	always @(posedge clk)
	if(mcu_mute)
	begin
		pcm_addr_rd		<= 0;
		pcm_addr_wr		<= 0;
		play_on			<= 0;
		in_buff			<= 0;
	end
		else
	begin

			
		if(snd_next_sample & in_buff < 4)
		begin
			play_on			<= 0;
		end
			else
		if(snd_next_sample & in_buff > 2352*2)
		begin
			play_on			<= 1;
		end
		
			
		if(snd_next_sample & play_on & in_buff >= 4)
		begin
			pcm_addr_rd		<= pcm_addr_rd + 4;
			in_buff			<= in_buff - (pcm_we ? 3 : 4);
		end
			else
		if(pcm_we)
		begin
			in_buff			<= in_buff + 1;
		end
		
		
		if(pcm_we)
		begin
			pcm_addr_wr		<= pcm_addr_wr + 1;
		end
		
		
		if(play_on)
		case(snd_phase[8:7])
			0:pcm_do_lo[7:0]		<= pcm_do;
			1:pcm_int_l[15:0] 	<= {pcm_do[7:0], pcm_do_lo[7:0]};
			2:pcm_do_lo[7:0]		<= pcm_do;
			3:pcm_int_r[15:0] 	<= {pcm_do[7:0], pcm_do_lo[7:0]};
		endcase
		
	end
	
	reg[15:0]pcm_int_l;
	reg[15:0]pcm_int_r;
	
	cdda_mute cdda_mute_inst(

		.clk(clk),
		.snd_next_sample(snd_next_sample),
		.mute(!play_on),
		.snd_i_l(pcm_int_l),
		.snd_i_r(pcm_int_r),
		
		.snd_o_l(pcm_l),
		.snd_o_r(pcm_r)
	);
		
	
	
	reg  [12:0]pcm_addr_rd;
	reg  [12:0]pcm_addr_wr;
	wire [7:0]pcm_do;
	wire pcm_we		= cdio.ce_cdc & cdio.we_sync;
	
	ram_dp8x pcm_buff(

		.din(cdio.dato[7:0]),
		.dout(pcm_do),
		.we(pcm_we), 
		.clk(clk),
		.addr_r({pcm_addr_rd[12:2], snd_phase[8:7]}),
		.addr_w(pcm_addr_wr)
	);
	
	
endmodule


module fader(
	
	input  rst,
	input  clk_asic,
	input  [15:0]sub_data,
	input  [14:0]reg_addr,
	input  sub_sync,
	input  regs_we_hi, regs_we_lo,
	output [15:0]reg_8034_do,
	
	input  snd_next_sample,	
	input  signed[15:0]snd_i_l,
	input  signed[15:0]snd_i_r,
	output signed[15:0]snd_o_l, 
	output signed[15:0]snd_o_r
);

	
	assign reg_8034_do[15:0] = {EFDT, 15'd0};//was fixed. EFDT was out of 16 bit
	
	wire [10:0]fad_vol = reg_8034[14:4] >= 1024 ? 1024 : reg_8034[14:4];
	
	reg [15:0]reg_8034;
	reg EFDT;
	
//************************************************* regs
	always @(posedge clk_asic)
	if(sub_sync)
	begin
		EFDT <= cur_vol != fad_vol;
	end
	
	
	always @(posedge clk_asic)
	if(rst)
	begin
		reg_8034[14:4] <= 1024;
	end
		else
	if(sub_sync)
	begin
		if(regs_we_hi & reg_addr == 9'h034)reg_8034[15:8] 	<= sub_data[15:8];
		if(regs_we_lo & reg_addr == 9'h034)reg_8034[7:0] 	<= sub_data[7:0];
	end

//************************************************* vol ctrl
	reg signed[11:0]cur_vol;
	
	
	always @(posedge clk_asic)
	if(snd_next_sample)
	begin
		if(cur_vol < fad_vol)cur_vol <= cur_vol + 1;
		if(cur_vol > fad_vol)cur_vol <= cur_vol - 1;
		
		snd_o_l <= snd_i_l * cur_vol / 1024;
		snd_o_r <= snd_i_r * cur_vol / 1024;
	end

	
endmodule


module cdda_mute(

	input  clk,
	input  snd_next_sample,
	input  mute,
	input  signed[15:0]snd_i_l,
	input  signed[15:0]snd_i_r,
	
	output signed[15:0]snd_o_l,
	output signed[15:0]snd_o_r
);
	
	wire gain_ck	= gain_delay == 0;

	reg signed[8:0]gain;
	reg [3:0]gain_delay;
	
	always @(posedge clk)
	if(snd_next_sample)
	begin
		
		snd_o_l		<= snd_i_l * gain / 128;
		snd_o_r		<= snd_i_r * gain / 128;
		
		gain_delay	<= gain_delay + 1;
		
		if(gain_ck & mute == 0 & gain < 128)
		begin
			gain		<= gain + 1;
		end
			else
		if(gain_ck & mute == 1 & gain > 0)
		begin
			gain		<= gain - 1;
		end
		
	end
	
endmodule

