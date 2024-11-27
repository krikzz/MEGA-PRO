 
//------------------------------------------------------------------------------------ audio_out_i2s
module audio_out_i2s(

	input  clk,
	input  snd_on,
	input  snd_clk,
	input  snd_next_sample,
	input  [8:0]snd_phase,
	input  signed[15:0]snd_i_l,
	input  signed[15:0]snd_i_r,
	
	output dac_mclk,
	output dac_lrck,
	output dac_sdin
);
	

	wire signed[15:0]snd_m_r;
	wire signed[15:0]snd_m_l;
	
	mute_stereo mute_stereo_inst(

		.clk(clk),
		.mute(!snd_on),
		.next_sample(snd_next_sample),
		.mute_vol(`MUTE_VOL),
		
		.snd_i_r(snd_i_r),
		.snd_i_l(snd_i_l),
		.snd_o_r(snd_m_r),
		.snd_o_l(snd_m_l)
	);
	
	
	dac_i2s dac_inst(
	
		.clk(clk),
		.dac_clk(snd_clk),
		.next_sample(snd_next_sample),
		.snd_phase(snd_phase),
		.snd_r(snd_m_r),
		.snd_l(snd_m_l),
		
		
		.mclk(dac_mclk),
		.lrck(dac_lrck),
		.sdin(dac_sdin)

	);
	
endmodule
//------------------------------------------------------------------------------------
 module dac_i2s(
	
	input clk,
	input dac_clk,
	input next_sample,
	input [8:0]snd_phase,
	input signed[15:0]snd_l,
	input signed[15:0]snd_r,
	
	output mclk, 
	output lrck,
	output sdin

);
	
	assign mclk 			= snd_phase[0];
	assign lrck 			= snd_phase[8];
	assign sdin 			= snd_bit;
	
	wire next_bit 			= snd_phase[3:0] == 4'b1111;
	wire [3:0]bit_ctr 	= snd_phase[7:4];

	
	
	reg snd_bit;
	reg signed[15:0]snd_l_st, snd_r_st;
	
	
	always @(posedge clk)
	if(dac_clk)
	begin
	
		
		if(next_bit & lrck == 0)
		begin
			snd_bit		<= snd_l_st[15 - bit_ctr[3:0]];
		end
		
		
		if(next_bit & lrck == 1)
		begin
			snd_bit 		<= snd_r_st[15 - bit_ctr[3:0]];
		end
		

		if(next_sample)
		begin
			snd_l_st 	<= snd_l;
			snd_r_st 	<= snd_r;
		end
		
	end
	
endmodule
//------------------------------------------------------------------------------------ audio_out_ds 
module audio_out_ds(

	input  clk,
	input  snd_on,
	input  snd_clk,
	input  snd_next_sample,
	input  [8:0]snd_phase,
	input  signed[15:0]snd_i_l,
	input  signed[15:0]snd_i_r,
	
	output snd_o_l,
	output snd_o_r
);
	

	wire signed[15:0]snd_m_r;
	wire signed[15:0]snd_m_l;
	
	mute_stereo mute_stereo_inst(

		.clk(clk),
		.mute(!snd_on),
		.next_sample(snd_next_sample),
		.mute_vol(`MUTE_VOL),
		
		.snd_i_l(snd_i_l),
		.snd_i_r(snd_i_r),
		.snd_o_l(snd_m_l),
		.snd_o_r(snd_m_r)
	);
	
	
	dac_ds_stereo dac_ds_stereo_inst(

		.clk(clk),
		.next_sample(snd_next_sample),
		.snd_i_l(snd_m_l),
		.snd_i_r(snd_m_r),
		
		.snd_o_l(snd_o_l),
		.snd_o_r(snd_o_r)
	);
	
endmodule

//------------------------------------------------------------------------------------
module dac_ds_stereo(

	input  clk,
	input  next_sample,
	input  signed[15:0]snd_i_l,
	input  signed[15:0]snd_i_r,
	
	output reg snd_o_l,
	output reg snd_o_r
);
	
	dac_ds_mono dac_ds_l(
		.clk(clk),
		.next_sample(next_sample),
		.snd_i(snd_i_l + 32768),
		.snd_o(snd_o_l)
	);
	
	
	dac_ds_mono dac_ds_r(
		.clk(clk),
		.next_sample(next_sample),
		.snd_i(snd_i_r + 32768),
		.snd_o(snd_o_r)
	);
	
endmodule
//------------------------------------------------------------------------------------
module dac_ds_mono(

	input  clk,
	input  next_sample,
	input  [DEPTH-1:0]snd_i,
	
	output reg snd_o
);
	
	parameter DEPTH = 16;
	

	wire [DEPTH+1:0]delta;
	wire [DEPTH+1:0]sigma;
	
	assign	delta[DEPTH+1:0] = {2'b0, snd_i_st[DEPTH-1:0]} + {sigma_st[DEPTH+1], sigma_st[DEPTH+1], {(DEPTH){1'b0}}};
	assign	sigma[DEPTH+1:0] = delta[DEPTH+1:0] + sigma_st[DEPTH+1:0];

	reg [DEPTH+1:0] sigma_st;
	reg [DEPTH-1:0]snd_i_st;
	
	always @(posedge clk) 
	begin
	
		sigma_st[DEPTH+1:0] 	<= sigma[DEPTH+1:0];
		snd_o						<= sigma_st[DEPTH+1];
		
		if(next_sample)
		begin
			snd_i_st				<= snd_i;
		end
		
	end
	
endmodule

//------------------------------------------------------------------------------------ mute (anti click)

module mute_stereo(

	input  clk,
	input  mute,
	input  next_sample,
	input  signed [15:0]mute_vol,//silence level
	
	input  signed [15:0]snd_i_l,
	input  signed [15:0]snd_i_r,
	
	output signed [15:0]snd_o_l,
	output signed [15:0]snd_o_r
);

	mute_mono mute_l(

		.clk(clk),
		.mute(mute),
		.next_sample(next_sample),
		.mute_vol(mute_vol),
		
		.snd_i(snd_i_l),
		.snd_o(snd_o_l)
	);
	
	
	mute_mono mute_r(

		.clk(clk),
		.mute(mute),
		.next_sample(next_sample),
		.mute_vol(mute_vol),
		
		.snd_i(snd_i_r),
		.snd_o(snd_o_r)
	);
	
endmodule
//------------------------------------------------------------------------------------
module mute_mono(

	input  clk,
	input  mute,
	input  next_sample,
	input  signed [15:0]mute_vol,//silence level
	
	input  signed [15:0]snd_i,
	output signed [15:0]snd_o
);
	
	reg signed [15:0]snd_cur;
	reg signed [9:0]vol;
	reg [7:0]delay;
	
	always @(posedge clk)
	if(next_sample)
	begin
	
		snd_o			<= (snd_cur * vol / 256) + (mute_vol * (256-vol) / 256);
			
		if(!mute)
		begin
			snd_cur	<= snd_i;
		end
		
	end
	
	always @(posedge clk)
	if(next_sample)
	begin
	
		if(delay != 0)
		begin
			delay		<= delay - 1;
		end
			else
		if(mute & vol != 0)
		begin
			delay		<= 16;
			vol		<= vol - 1;
		end
			else
		if(!mute & vol != 256) 
		begin
			delay		<= 16;
			vol		<= vol + 1;
		end
		
	end

endmodule

