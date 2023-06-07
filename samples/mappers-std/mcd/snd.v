

module mcd_dsp(

	input rst,
	input clk, 
	input McdIO cdio,
	input cdda_sync, pcm_sync,
	input signed[15:0]pcm_vol_l,  pcm_vol_r,
	input signed[15:0]cdda_vol_l, cdda_vol_r,

	output signed[15:0]snd_r,
	output signed[15:0]snd_l
);
	
//**************************************************************** filters

	wire signed[15:0]pcm_vol_l_lp, pcm_vol_r_lp;
	
	lo_pass lo_pass_l(
		.clk(clk),
		.sample_sync(pcm_sync),
		.alpha(cdio.cfg_dsp[0]),
		.gain_base(cdio.cfg_dsp[1]),
		.gain_filt(cdio.cfg_dsp[2]),
		.gain_totl(cdio.cfg_dsp[3]),
		.vol_in(pcm_vol_l),
		.vol_out(pcm_vol_l_lp)
	);
	
	lo_pass lo_pass_r(
		.clk(clk),
		.sample_sync(pcm_sync),
		.alpha(cdio.cfg_dsp[0]),
		.gain_base(cdio.cfg_dsp[1]),
		.gain_filt(cdio.cfg_dsp[2]),
		.gain_totl(cdio.cfg_dsp[3]),
		.vol_in(pcm_vol_r),
		.vol_out(pcm_vol_r_lp)
	);
	
	wire signed[15:0]cdda_vol_l_hp, cdda_vol_r_hp;
	
	hi_pass hi_pass_l(
		.clk(clk),
		.alpha(cdio.cfg_dsp[4]),
		.gain_base(cdio.cfg_dsp[5]),
		.gain_filt(cdio.cfg_dsp[6]),
		.gain_totl(cdio.cfg_dsp[7]),
		.sample_sync(cdda_sync),
		.vol_in(cdda_vol_l),
		.vol_out(cdda_vol_l_hp)
	);
	
	hi_pass hi_pass_r(
		.clk(clk),
		.alpha(cdio.cfg_dsp[4]),
		.gain_base(cdio.cfg_dsp[5]),
		.gain_filt(cdio.cfg_dsp[6]),
		.gain_totl(cdio.cfg_dsp[7]),
		.sample_sync(cdda_sync),
		.vol_in(cdda_vol_r),
		.vol_out(cdda_vol_r_hp)
	);
	

//**************************************************************** mixer

	wire signed [16:0]vol_l_int = pcm_vol_l_lp + cdda_vol_l_hp;
	wire signed [16:0]vol_r_int = pcm_vol_r_lp + cdda_vol_r_hp;
	
	assign snd_l = vol_l_int < -32768 ? -32768 : vol_l_int > 32767 ? 32767 : vol_l_int;
	assign snd_r = vol_r_int < -32768 ? -32768 : vol_r_int > 32767 ? 32767 : vol_r_int;
	
endmodule


module hi_pass(

	input clk,
	input sample_sync,
	input [7:0]alpha,
	input [7:0]gain_base,
	input [7:0]gain_filt,
	input [7:0]gain_totl,
	input signed [15:0]vol_in,
	output reg signed [15:0]vol_out
);


	parameter EXT = 256;

	reg [2:0]state;	
	reg signed [15:0]vol_old;
	reg signed [15:0]vol_cur;
	reg signed [16:0]vol_int;//was 16
	reg signed [17:0]vol_amp;
	
	wire [17:0]mul = vol_amp[17:0];
	reg sample_sync_st;
	

	always @(negedge clk)
	begin
		
		sample_sync_st <= sample_sync;
		
			
		
		case(state)
			0:begin
				if(sample_sync & !sample_sync_st)
				begin
					state <= state + 1;
				end
				vol_cur 	<= vol_in;
			end
			1:begin
				vol_amp 	<= (vol_int + vol_old - vol_cur);// * alpha / EXT;
				state 	<= state + 1;
			end
			2:begin
				vol_int 	<= $signed(vol_amp) * alpha / EXT;
				state 	<= state + 1;
			end
			3:begin
				vol_amp 	<= (vol_int + vol_old - vol_cur);// * alpha / EXT;
				state 	<= state + 1;
			end
			4:begin
				vol_int 	<= $signed(vol_amp) * alpha / EXT;
				state 	<= state + 1;
			end
			5:begin
				vol_amp 	<= ($signed(vol_cur) * gain_base + $signed(vol_int) * gain_filt) / 128;//17-30
				state 	<= state + 1;
			end
			6:begin
				vol_amp 	<= $signed(vol_amp) * gain_totl / 64;//10
				state 	<= state + 1;
			end
			
			7:begin
				
				vol_out	<= 
				vol_amp < -32768 ? -32768 :
				vol_amp >  32767 ?  32767 :
				vol_amp;
				
				vol_old 	<= vol_cur;
				state 	<= 0;
				
			end

			
		endcase
	end


endmodule


module lo_pass(
	input clk,
	input sample_sync,
	input [7:0]alpha,
	input [7:0]gain_base,
	input [7:0]gain_filt,
	input [7:0]gain_totl,
	input signed [15:0]vol_in,
	output reg signed [15:0]vol_out
);
	
	parameter EXT = 2048;

	reg sample_sync_st;
	reg [2:0]state;
	reg signed [15:0]vol_cur;
	reg signed [16:0]vol_int;
	reg signed [16:0]vol_amp;
	reg signed [16:0]delta;
	

	always @(negedge clk)
	begin
		
		sample_sync_st <= sample_sync;
		
		case(state)
			0:begin
				if(sample_sync & !sample_sync_st)
				begin
					state <= state + 1;
				end
				vol_cur 	<= vol_in;
			end	
			1:begin
				delta 	<= vol_cur - vol_int;
				state 	<= state + 1;
			end
			2:begin
				vol_int 	<= vol_int + (alpha * $signed(delta) / EXT);
				state 	<= state + 1;
			end
			3:begin
				vol_amp 	<= ($signed(vol_cur) * gain_base + $signed(vol_int) * gain_filt) / 128;
				state 	<= state + 1;
			end
			4:begin
				vol_out 	<= $signed(vol_amp) * gain_totl / 128;
				state 	<= 0;
			end
				
		endcase
	end


endmodule


module dac_cs4344__(
	output mclk, 
	output lrck,
	output sclk,
	output sdin,
	input signed[15:0]vol_r,
	input signed[15:0]vol_l,
	input clk,
	input rst
);
	
	
	assign mclk = ctr[0];
	assign sclk = 1;
	assign lrck = ctr[8];
	assign sdin = vol_bit;//vol[15 - bit_ctr[3:0]];
	
	wire next_bit = ctr[3:0] == 4'b1111;
	wire next_vol = next_bit & bit_ctr == 15;
	wire [3:0]bit_ctr = ctr[7:4];
	wire aclk = clk_ctr >= (CLK_DIV - CLK_INC);//cdda_lr == lrck & next_vol;

	
	reg [15:0]ctr;
	reg [15:0]vol;
	reg vol_bit;
	reg [21:0]clk_ctr;
	reg signed[24:0]over_r, over_l;
	
	//2,214425 sync with cdd
	parameter CLK_DIV = 2214425;
	parameter CLK_INC = 1000000;
	
		
	always @(negedge clk)
	if(rst)
	begin
		clk_ctr <= 0;
		ctr <= 0;//important for sync with cdda (lrck things)
		vol_bit <= 0;
		vol <= 0;
		over_l <= 0;
		over_r <= 0;
	end
		else
	begin
	
		clk_ctr <=  aclk ? clk_ctr - (CLK_DIV - CLK_INC) : clk_ctr + CLK_INC;
	
		if(aclk)
		begin
		
			ctr <= ctr + 1;
			if(next_bit)vol_bit <= vol[15 - bit_ctr[3:0]];
			
			
			if(next_vol & lrck == 1)
			begin
				vol <= over_l / 512;
				over_l <= vol_l;
			end
				else
			begin
				over_l <= over_l + vol_l;
			end
			
			if(next_vol & lrck == 0)
			begin
				vol <= over_r / 512;
				over_r <= vol_r;
			end
				else
			begin
				over_r <= over_r + vol_r;
			end
			
		end
		
	end
	
	
	
endmodule
