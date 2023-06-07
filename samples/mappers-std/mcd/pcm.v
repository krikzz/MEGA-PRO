
`define pcm_args(arg)				\
	.chan_idx(arg),					\
	.pcm_addr(chan_rd_addr[arg]),	\
	.vol_l(chan_vol_l[arg]), 		\
	.vol_r(chan_vol_r[arg]),		\
	.rst(rst),							\
	.clk_asic(clk_asic),				\
	.sub_sync(sub_sync),				\
	.sampler_sync(sampler_sync),	\
	.pcm_on(pcm_on),					\
	.chan_sw(chan_sw[7:0]),			\
	.pcm_upd(pcm_upd),				\
	.upd_idx(upd_chan[2:0]),		\
	.pcm_dat(ram_do[7:0]),			\
	.reg_we(regs_we),					\
	.reg_idx(cur_reg[2:0]),			\
	.reg_dat(host_data[7:0]),		\
	.host_addr(host_addr[3:0])		

module pcm(

	input rst, 
	input clk_asic,
	input sub_sync,
	input [15:0]sub_data,
	input [23:0]sub_addr,
	input sub_we_lo, sub_we_hi, sub_oe, sub_as, 

	output [15:0]regs_do_pcm,
	output regs_ce_pcm,

	output [15:0]ram_addr,
	output [7:0]ram_di,
	input [7:0]ram_do,
	output ram_we, ram_oe,
	
	input [18:0]dma_addr,
	input [15:0]dma_dat,
	input dma_ce_pcm,
	input dma_we,
	
	output signed [15:0]pcm_vol_l,
	output signed [15:0]pcm_vol_r,
	output pcm_sync
);

	
	assign regs_do_pcm[15:8] = 8'h80;
	assign regs_ce_pcm = !sub_as & {sub_addr[23:15], 15'd0} == 24'hFF0000;
	

	wire [7:0]host_data = dma_ce_pcm ? dma_dat[7:0] : sub_data[7:0];
	wire [12:0]host_addr = dma_ce_pcm ? {1'b1, dma_addr[12:1]} : sub_addr[13:1];
	wire host_we = dma_ce_pcm ? dma_we : !sub_we_lo;
	wire host_ce = dma_ce_pcm ? 1 : regs_ce_pcm;
	wire host_oe = dma_ce_pcm ? 0 : !sub_oe;
	
	
	pcm_int pcm_int_inst(

		.rst(rst), 
		.clk_asic(clk_asic),
		.sub_sync(sub_sync),

		.regs_do_pcm(regs_do_pcm[7:0]),
		.ram_addr(ram_addr),
		.ram_di(ram_di),
		.ram_do(ram_do),
		.ram_we(ram_we),
		.ram_oe(ram_oe),
		
		.host_addr(host_addr),
		.host_data(host_data),
		.host_ce(host_ce),
		.host_we(host_we),
		.host_oe(host_oe),
		
		.pcm_vol_l(pcm_vol_l),
		.pcm_vol_r(pcm_vol_r),
		.pcm_sync(pcm_sync)
		
	);
	
endmodule	
	
module pcm_int(

	input rst, 
	input clk_asic,
	input sub_sync,

	output [7:0]regs_do_pcm,

	output reg[15:0]ram_addr,
	output reg[7:0]ram_di,
	input [7:0]ram_do,
	output reg ram_we, ram_oe,
	
	input [12:0]host_addr,
	input [7:0]host_data,
	input host_ce,
	input host_we,
	input host_oe,
	
	output reg signed[15:0]pcm_vol_l,
	output reg signed[15:0]pcm_vol_r,
	output pcm_sync
);

	
	
	//assign regs_do_pcm[15:8] = 8'h00;
	assign regs_do_pcm[7:0] = 
	host_addr[12] ? ram_do[7:0] : 
	host_addr[0] == 0 ? chan_rd_addr[host_addr[3:1]][7:0] : chan_rd_addr[host_addr[3:1]][15:8];
	

	wire regs_ce = host_ce & host_addr[12:4] == 0;
	wire regs_we = regs_ce & host_we;// & !regs_we_st;
	wire mem_ce = host_ce & host_addr[12] == 1;
	wire mem_we = mem_ce & host_we;
	
	assign pcm_sync = sampler_ctr == 0;
	wire sampler_sync = sampler_ctr == 0;
	
	reg pcm_on;
	reg [8:0]sampler_ctr;
	reg [3:0]ram_bank;
	reg [2:0]cur_reg;
	reg [7:0]chan_sw;
	reg regs_we_st;

	
	always @(negedge clk_asic)
	if(rst)
	begin
		ram_bank <= 0;
		cur_reg <= 0;
		pcm_on <= 0;
		chan_sw[7:0] = 8'hff;
		regs_we_st <= 0;
	end
		else
	if(sub_sync)
	begin
		
		regs_we_st <= regs_ce & host_we;
		
		if(regs_we & host_addr == 7)//control register
		begin
			pcm_on <= host_data[7];
			if(host_data[6] == 0)ram_bank[3:0] <= host_data[3:0];
			if(host_data[6] == 1)cur_reg[2:0] <= host_data[2:0];
		end
		
		if(regs_we & host_addr == 8)//on/off register
		begin
			chan_sw[7:0] <= host_data[7:0];
		end
		
		
	
		
	end
	
	
	always @(negedge clk_asic)
	if(sub_sync)
	begin
		//if(!pcm_on)sampler_ctr <= 1;
			//else
		sampler_ctr <= sampler_ctr == 47 ? 0 : sampler_ctr + 1;
	end
	

//*********************************************************************************************** memory control	
	
	wire [2:0]upd_chan = upd_chan_ctr[2:0];//doulble fetch for each channel?
	
	reg [3:0]upd_chan_ctr;
	reg [3:0]mem_state;
	reg mem_we_st;
	reg pcm_upd;
	//reg [7:0]pcm_upd_val;
	
	always @(negedge clk_asic)
	if(rst)
	begin
		upd_chan_ctr <= 0;
		mem_state <= 0;
		mem_we_st <= 0;
		ram_we <= 0;
		pcm_upd <= 0;
	end
		else
	if(sub_sync)
	begin
		
		mem_we_st <= mem_we;
		if(pcm_upd)pcm_upd <= 0;
		
		if(mem_we & !mem_we_st)
		begin
			ram_addr[15:0] <= {ram_bank[3:0], host_addr[11:0]};
			ram_di[7:0] <= host_data[7:0];
			mem_state <= 8;
			ram_oe <= 0;
		end
			else
		case(mem_state)
			//********************************** read
			0:begin
				if(pcm_on == 0)ram_addr[15:0] <= {ram_bank[3:0], host_addr[11:0]};//forever host read cycle if pcm
				if(pcm_on == 0)ram_oe <= host_oe;
				if(pcm_on == 1)ram_addr[15:0] <= chan_rd_addr[upd_chan];
				if(pcm_on == 1)mem_state <= mem_state + 1;
				if(pcm_on == 1)ram_oe <= 1;
				ram_we <= 0;
			end
			1:begin
				mem_state <= mem_state + 1;//+80ns
				pcm_upd <= 1;
			end
			2:begin
				upd_chan_ctr <= upd_chan_ctr + 1;
				ram_oe <= 0;
				mem_state <= 0;
			end
			//********************************** write
			8:begin
				ram_we <= 1;
				mem_state <= mem_state + 1;
			end
			9:begin
				mem_state <= mem_state + 1;//+80ns
			end
			10:begin
				mem_state <= 0;
				ram_we <= 0;
			end
			
		endcase
	
	end

//*********************************************************************************************** channels
	wire [15:0]chan_rd_addr[8];
	wire [14:0]chan_vol_l[8];
	wire [14:0]chan_vol_r[8];
	

	pcm_chan pcm0(`pcm_args(0));
	pcm_chan pcm1(`pcm_args(1));
	pcm_chan pcm2(`pcm_args(2));
	pcm_chan pcm3(`pcm_args(3));
	pcm_chan pcm4(`pcm_args(4));
	pcm_chan pcm5(`pcm_args(5));
	pcm_chan pcm6(`pcm_args(6));
	pcm_chan pcm7(`pcm_args(7));
	
//*********************************************************************************************** mixer	

	reg signed[18:0]vol_calc_l, vol_calc_r;
	reg [4:0]mix_ctr;
	
	wire signed [14:0]cur_vol_l = chan_vol_l[mix_ctr[2:0]][13:0];
	wire signed [14:0]cur_vol_r = chan_vol_r[mix_ctr[2:0]][13:0];
	
	wire cur_sign_l = chan_vol_l[mix_ctr[2:0]][14];
	wire cur_sign_r = chan_vol_l[mix_ctr[2:0]][14];
	
	
	
	always @(negedge clk_asic)
	if(rst)
	begin
		vol_calc_l <= 0;
		vol_calc_r <= 0;
		mix_ctr <= 9;
		pcm_vol_r <= 0;
		pcm_vol_l <= 0;
	end
		else
	if(sub_sync)
	begin

		mix_ctr <= mix_ctr == 9 ? 0 : mix_ctr + 1;
		
		if(mix_ctr == 8)
		begin
			if(vol_calc_l < -32768)pcm_vol_l <= -32768;
				else
			if(vol_calc_l > 32767)pcm_vol_l <= 32767;
				else
			pcm_vol_l <= vol_calc_l;
			
			if(vol_calc_r <= -32768)pcm_vol_r <= -32768;
				else
			if(vol_calc_r >= 32767)pcm_vol_r <= 32767;
				else
			pcm_vol_r <= vol_calc_r;
		end
			else
		if(mix_ctr == 9)
		begin
			vol_calc_l <= 0;//18'h20000;
			vol_calc_r <= 0;//18'h20000;
		end
			else
		begin
			vol_calc_l <= cur_sign_l == 1 ? (vol_calc_l - cur_vol_l) : (vol_calc_l + cur_vol_l);
			vol_calc_r <= cur_sign_r == 1 ? (vol_calc_r - cur_vol_r) : (vol_calc_r + cur_vol_r);
		end
	
	end
	

endmodule



module pcm_chan(
	
	input [2:0]chan_idx,
	output [15:0]pcm_addr,
	output reg[14:0]vol_r, 
	output reg[14:0]vol_l,
	
	input rst, clk_asic, sub_sync, sampler_sync, pcm_on,
	input [7:0]chan_sw,
	
	input pcm_upd,
	input [2:0]upd_idx,
	input [7:0]pcm_dat,
	
	input reg_we,
	input [2:0]reg_idx,
	input [7:0]reg_dat,
	input [3:0]host_addr

);
	
	
	parameter ADDR_HI = 29;
	parameter ADDR_LO	= 14;
	
	assign pcm_addr[15:0] = addr_ctr[ADDR_HI:ADDR_LO];
		
	
	wire chan_off = chan_sw[chan_idx];
	wire pcm_upd_this = pcm_upd & upd_idx == chan_idx;
	wire reg_we_this = reg_we & reg_idx == chan_idx;
	
	wire [7:0]env = regs[0][7:0];
	wire [7:0]pan = regs[1][7:0];
	wire [15:0]fd = {regs[3][7:0], regs[2][7:0]};
	wire [15:0]ls = {regs[5][7:0], regs[4][7:0]};
	wire [7:0]st  = regs[6][7:0];
	
	
	reg [1:0]mul_ctr;
	reg [7:0]regs[7];
	reg [ADDR_HI:0]addr_ctr;
	reg [7:0]pcm_sample;
	reg [15:0]env_vol;
	
	reg pan_sig;
	reg [18:0]pan_l, pan_r;
	reg [7:0]pcm_dat_last;
	reg [2:0]state;
	reg upd_valid;
	
	always @(negedge clk_asic)
	if(rst)
	begin	
		vol_r <= 0;
		vol_l <= 0;
		regs[0][7:0] <= 0;
		regs[1][7:0] <= 8'hff;
		regs[2][7:0] <= 0;
		regs[3][7:0] <= 0;
		regs[4][7:0] <= 0;
		regs[5][7:0] <= 0;
		regs[6][7:0] <= 0;
		pcm_sample[7:0] <= 8'h00;
		state <= 0;
		mul_ctr <= 0;
		addr_ctr <= 0;
		env_vol <= 0;
		pan_sig <= 0;
		pan_l <= 0;
		pan_r <= 0;
		pcm_dat_last <= 0;
		upd_valid <= 0;
	end
		else
	if(sub_sync)
	begin
		
		
		if(reg_we_this & host_addr == 0)regs[0][7:0] <= reg_dat[7:0];
		if(reg_we_this & host_addr == 1)regs[1][7:0] <= reg_dat[7:0];
		if(reg_we_this & host_addr == 2)regs[2][7:0] <= reg_dat[7:0];
		if(reg_we_this & host_addr == 3)regs[3][7:0] <= reg_dat[7:0];
		if(reg_we_this & host_addr == 4)regs[4][7:0] <= reg_dat[7:0];
		if(reg_we_this & host_addr == 5)regs[5][7:0] <= reg_dat[7:0];
		if(reg_we_this & host_addr == 6)regs[6][7:0] <= reg_dat[7:0];
		
		if(pcm_upd_this)pcm_dat_last <= pcm_dat;
		
		if(!pcm_on | chan_off)state <= 0;
			
		if(pcm_on)
		case(state)
		
			0:begin
				addr_ctr[ADDR_HI:ADDR_HI-7] <= st[7:0];//{st[7:0], 22'd0};
				addr_ctr[ADDR_HI-8:0] <= 0;
				if(!chan_off & pcm_upd_this)state <= state + 1;
			end
			
			1:begin
			
				if(pcm_upd_this & pcm_dat[7:0] == 8'hff)
				begin
					state <= state + 1;
					addr_ctr[ADDR_HI:ADDR_LO] <= ls[15:0];
					addr_ctr[ADDR_LO-1:0] <= 0;
				end
				
				if(pcm_upd_this & pcm_dat[7:0] != 8'hff)
				begin
					state <= state + 2;
				end
				
			end
			
			2:begin
				if(pcm_upd_this & pcm_dat[7:0] != 8'hff)state <= state + 1;
			end

			3:begin
				if(pcm_dat[7:0] == 8'hff & pcm_upd_this)
				begin
					addr_ctr[ADDR_HI:ADDR_LO] <= ls[15:0];//{ls[15:0], 14'd0};
					addr_ctr[ADDR_LO-1:0] <= 0;
					state <= state + 1;
					upd_valid <= 0;
				end
					else
				if(sampler_sync)
				begin
					addr_ctr <= addr_ctr + fd;
					pcm_sample[7:0] <= pcm_dat_last[7:0];
				end
			end
			4:begin
				if(pcm_upd_this)upd_valid <= 1;
				
				if(sampler_sync & upd_valid)
				begin
					addr_ctr[ADDR_HI:ADDR_LO] <= addr_ctr[ADDR_HI:ADDR_LO] + 1;
					pcm_sample[7:0] <= pcm_dat_last[7:0];
					state <= state - 1;
				end
			end
			
		endcase
		

		
		mul_ctr <= mul_ctr + 1;
		
		case(mul_ctr)
			0:begin
				env_vol[15:0] <=  pcm_sample[6:0] * env[7:0];
				pan_sig <= pcm_sample[7];
			end
			1:begin
				pan_l[18:0] <= env_vol[15:0] * pan[3:0];
			end
			2:begin
				pan_r[18:0] <= env_vol[15:0] * pan[7:4];
			end
			3:begin
				if(pcm_on)vol_l[14:0] = chan_off ? 0 : {pan_sig, pan_l[18:5]};
				if(pcm_on)vol_r[14:0] = chan_off ? 0 : {pan_sig, pan_r[18:5]};
			end
		endcase
		
	end
	
	
	


endmodule
