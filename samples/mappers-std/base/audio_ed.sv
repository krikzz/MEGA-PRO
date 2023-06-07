 
 
 module audio_ed(
	
	input  clk,
	input  rst,
	input  DacBus dac,
	
	output mclk, 
	output lrck,
	output sclk,
	output sdin
 );
 
 
//************************************************************************************ mute stuff
	
	wire signed[15:0]snd_r;
	wire signed[15:0]snd_l;
	
	mute_snd mute_r(

		.clk(clk),
		.mute(rst),
		.next_sample(next_sample),
		
		.snd_i(dac.snd_r),
		.snd_o(snd_r)
	);
	
	mute_snd mute_l(

		.clk(clk),
		.mute(rst),
		.next_sample(next_sample),
		
		.snd_i(dac.snd_l),
		.snd_o(snd_l)
	);
	
//*********************************************************************************** dac clock (only for reset mode)
	wire dac_clk_int;
	
	clk_dvp dac_clk_inst(

		.clk(clk),
		.rst(0),
		.ck_base(50000000),
		.ck_targ(44100 * 512),
		.ck_out(dac_clk_int)
	);	
//*********************************************************************************** dac

	wire dac_clk	= rst ? dac_clk_int : dac.clk;
	wire next_sample;
	
	dac_cs4344 dac_inst(
	
		.clk(clk),
		.rst(dac_rst),
		.dac_clk(dac_clk),
		.vol_r(snd_r),
		.vol_l(snd_l),
		
		.next_sample(next_sample),
		.mclk(mclk),
		.lrck(lrck),
		.sclk(sclk),
		.sdin(sdin)
	);
	
	
	//reset for sync sith cdda is very important
	wire dac_rst = rst_st != rst;
	reg rst_st;
	
	always @(negedge clk)
	begin
		rst_st	<= rst;
	end
	
 endmodule
  
//------------------------------------------------------------------------------------ dac

 module dac_cs4344(
	
	input clk,
	input rst,
	input dac_clk,
	input signed[15:0]vol_r,
	input signed[15:0]vol_l,
	
	output next_sample,
	
	output mclk, 
	output lrck,
	output sclk,
	output sdin

);
	assign next_sample	= dac_clk & phase[8:0] == 511;
	
	assign mclk 			= phase[0];
	assign sclk 			= 1;
	assign lrck 			= phase[8];
	assign sdin 			= vol_bit;
	
	wire next_bit 			= phase[3:0] == 4'b1111;
	wire [3:0]bit_ctr 	= phase[7:4];

	
	reg [8:0]phase;
	reg vol_bit;
	reg signed[15:0]vol_r_st, vol_l_st;
	reg signed[24:0]vol_r_acc, vol_l_acc;
	
	
	always @(negedge clk)
	if(rst)
	begin
		phase 		<= 1;
		vol_bit 		<= 0;
		vol_r_st		<= 0;
		vol_l_st		<= 0;
		vol_r_acc	<= vol_r;
		vol_l_acc	<= vol_l;
	end
		else
	if(dac_clk)
	begin
	
		phase 			<= phase + 1;
		

		if(next_bit & lrck == 1)
		begin
			vol_bit 		<= vol_r_st[15 - bit_ctr[3:0]];
		end
		
		
		if(next_bit & lrck == 0)
		begin
			vol_bit		<= vol_l_st[15 - bit_ctr[3:0]];
		end
		
		
		if(phase == 511)
		begin
			vol_r_st 	<= vol_r_acc / 512;
			vol_l_st 	<= vol_l_acc / 512;
			vol_r_acc 	<= vol_r;
			vol_l_acc 	<= vol_l;
		end
			else
		begin
			vol_r_acc 	<= vol_r_acc + vol_r;
			vol_l_acc 	<= vol_l_acc + vol_l;
		end
		
	end
	
endmodule

//------------------------------------------------------------------------------------ mute

module mute_snd(

	input  clk,
	input  mute,
	input  next_sample,
	
	input  signed [15:0]snd_i,
	output signed [15:0]snd_o
);

	reg signed [15:0]snd_cur;
	reg signed [9:0]vol;
	reg [7:0]delay;
	
	always @(negedge clk)
	begin
	
		snd_o	<= snd_cur * vol / 256;
			
		if(!mute)
		begin
			snd_cur	<= snd_i;
		end
		
	end
	
	always @(negedge clk)
	if(next_sample)
	begin
	
		if(delay != 0)
		begin
			delay	<= delay - 1;
		end
			else
		if(mute & vol != 0)
		begin
			delay	<= 16;
			vol	<= vol - 1;
		end
			else
		if(!mute & vol != 256) 
		begin
			delay	<= 16;
			vol	<= vol + 1;
		end
		
	end

endmodule
