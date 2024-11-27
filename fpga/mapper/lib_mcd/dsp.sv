

module mcd_dsp(

	input rst,
	input clk, 
	input McdIO cdio,
	
	input snd_clk,
	input snd_next_sample,
	
	input signed[15:0]pcm_snd_l,  pcm_snd_r,
	input signed[15:0]cdda_snd_l, cdda_snd_r,
	
	output signed[15:0]snd_l,
	output signed[15:0]snd_r
);
	
	
//**************************************************************** filters

	wire signed[15:0]pcm_snd_l_rs, pcm_snd_r_rs;
	
	resampler resampler_l(

		.clk(clk),
		.next_sample(snd_next_sample),
		.dac_clk(snd_clk),
		.vol_src(pcm_snd_l),
		.vol_dst(pcm_snd_l_rs)
	);
	
	resampler resampler_r(

		.clk(clk),
		.next_sample(snd_next_sample),
		.dac_clk(snd_clk),
		.vol_src(pcm_snd_r),
		.vol_dst(pcm_snd_r_rs)
	);
	
	
	wire signed[15:0]pcm_snd_l_lp, pcm_snd_r_lp;
	
	lo_pass lo_pass_l(
		.clk(clk),
		.sample_sync(snd_next_sample),
		.alpha(cdio.cfg_dsp[0]),
		.gain_base(cdio.cfg_dsp[1]),
		.gain_filt(cdio.cfg_dsp[2]),
		.gain_totl(cdio.cfg_dsp[3]),
		.vol_in(pcm_snd_l_rs),
		.vol_out(pcm_snd_l_lp)
	);
	
	lo_pass lo_pass_r(
		.clk(clk),
		.sample_sync(snd_next_sample),
		.alpha(cdio.cfg_dsp[0]),
		.gain_base(cdio.cfg_dsp[1]),
		.gain_filt(cdio.cfg_dsp[2]),
		.gain_totl(cdio.cfg_dsp[3]),
		.vol_in(pcm_snd_r_rs),
		.vol_out(pcm_snd_r_lp)
	);
	
	
	wire signed[15:0]cdda_snd_l_hp, cdda_snd_r_hp;
	
	hi_pass hi_pass_l(
		.clk(clk),
		.alpha(cdio.cfg_dsp[4]),
		.gain_base(cdio.cfg_dsp[5]),
		.gain_filt(cdio.cfg_dsp[6]),
		.gain_totl(cdio.cfg_dsp[7]),
		.sample_sync(snd_next_sample),
		.vol_in(cdda_snd_l),
		.vol_out(cdda_snd_l_hp)
	);
	
	hi_pass hi_pass_r(
		.clk(clk),
		.alpha(cdio.cfg_dsp[4]),
		.gain_base(cdio.cfg_dsp[5]),
		.gain_filt(cdio.cfg_dsp[6]),
		.gain_totl(cdio.cfg_dsp[7]),
		.sample_sync(snd_next_sample),
		.vol_in(cdda_snd_r),
		.vol_out(cdda_snd_r_hp)
	);
	

//**************************************************************** mixer
`ifdef MCD_DSP_OFF
	wire signed [16:0]vol_l_int = cdda_snd_l + pcm_snd_l;
	wire signed [16:0]vol_r_int = cdda_snd_r + pcm_snd_r;
`else
	wire signed [16:0]vol_l_int = cdda_snd_l_hp + pcm_snd_l_lp;
	wire signed [16:0]vol_r_int = cdda_snd_r_hp + pcm_snd_r_lp;
`endif

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

	always @(posedge clk)
	begin
		
		if(sample_sync & state == 0)
		begin
			vol_out		<= vol_amp;
			state			<= 1;
		end
			else
		if(state != 0)
		begin
			state			<= state + 1;
		end
		
		case(state)
			0:begin
				vol_cur 	<= vol_in;
			end
			1:begin
				vol_amp 	<= (vol_int + vol_old - vol_cur);// * alpha / EXT;
			end
			2:begin
				vol_int 	<= $signed(vol_amp) * alpha / EXT;
			end
			3:begin
				vol_amp 	<= (vol_int + vol_old - vol_cur);// * alpha / EXT;
			end
			4:begin
				vol_int 	<= $signed(vol_amp) * alpha / EXT;
			end
			5:begin
				vol_amp 	<= ($signed(vol_cur) * gain_base + $signed(vol_int) * gain_filt) / 128;//17-30
			end
			6:begin
				vol_amp 	<= $signed(vol_amp) * gain_totl / 64;//10
			end
			
			7:begin
				
				vol_amp	<= 
				vol_amp < -32768 ? -32768 :
				vol_amp >  32767 ?  32767 :
				vol_amp;
				
				vol_old 	<= vol_cur;
				
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
	
	parameter EXT = 512;

	reg [1:0]state;
	reg signed [15:0]vol_cur;
	reg signed [16:0]vol_int;
	reg signed [16:0]vol_amp;
	reg signed [16:0]delta;
	

	always @(posedge clk)
	begin
		
		if(sample_sync & state == 0)
		begin
			state 		<= 1;
			vol_out 		<= $signed(vol_amp) * gain_totl / 128;
		end
			else
		if(state != 0)
		begin
			state			<= state + 1;
		end
		
		case(state)
			0:begin
				vol_cur 	<= vol_in;
			end	
			1:begin
				delta 	<= vol_cur - vol_int;
			end
			2:begin
				vol_int 	<= vol_int + (alpha * $signed(delta) / EXT);
			end
			3:begin
				vol_amp 	<= ($signed(vol_cur) * gain_base + $signed(vol_int) * gain_filt) / 128;
			end
				
		endcase
		
	end


endmodule

//*************************************************************************************
module resampler(

	input  clk,
	input  next_sample,
	input  dac_clk,
	input  signed[15:0]vol_src,
	output signed[15:0]vol_dst
);
	reg signed[24:0]vol_acc;
	
	always @(posedge clk)
	if(dac_clk)
	begin
		
		if(next_sample)
		begin
			vol_acc	<= vol_src;
			vol_dst	<= vol_acc / 512;
		end
			else
		begin
			vol_acc	<= vol_acc + vol_src;
		end
		
	end
	
endmodule
//*************************************************************************************