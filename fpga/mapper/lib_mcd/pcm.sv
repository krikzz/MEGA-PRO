
typedef struct{
	
	bit clk;
	bit rst;
	bit sub_sync;
	bit sample_ck;
	bit addr_ck;
	bit pcm_on;
	bit [7:0]chan_sw;
	
	bit reg_we;
	bit [2:0]reg_sel;
	bit [7:0]host_data;
	bit [3:0]host_addr;
	
	
	PcmSample sample;
	
}PcnIn;


typedef struct{
	bit [15:0]addr;
	bit [15:0]addr_last;
	bit [14:0]snd_l;
	bit [14:0]snd_r;
}PcnOut;


typedef struct{
	PcnOut chan[8];
}PcnOutBus;


typedef struct{
	bit[7:0]chan[8];
}PcmSample;

//*********************************************************************************************** 
module pcm(

	input rst, 
	input clk_asic,
	input sub_sync,
	input [15:0]sub_data,
	input [23:0]sub_addr,
	input sub_we_lo, sub_we_hi, sub_oe, sub_as, 

	output [15:0]regs_do,
	output regs_ce,

	output MemCtrl_8 ram,
	input  [7:0]ram_dato,
	
	input  McdDma dma,
	
	output signed [15:0]snd_l,
	output signed [15:0]snd_r,
	output snd_next_sample
);
	
	
	assign regs_do[15:8] 	= 8'h80;
	assign regs_ce 			= !sub_as & {sub_addr[23:15], 15'd0} == 24'hFF0000;
	

	wire [7:0]host_data 		= dma.ce_pcm ? dma.dat[7:0] : sub_data[7:0];
	wire [12:0]host_addr 	= dma.ce_pcm ? {1'b1, dma.addr[12:1]} : sub_addr[13:1];
	wire host_we 				= dma.ce_pcm ? dma.we : !sub_we_lo;
	wire host_ce 				= dma.ce_pcm ? 1 : regs_ce;
	wire host_oe 				= dma.ce_pcm ? 0 : !sub_oe;
	
	
	chip_pcm chip_pcm_inst(

		.rst(rst), 
		.clk_asic(clk_asic),
		.sub_sync(sub_sync),

		.regs_do(regs_do[7:0]),
		.ram(ram),
		.ram_dato(ram_dato),
		
		.host_addr(host_addr),
		.host_data(host_data),
		.host_ce(host_ce),
		.host_we(host_we),
		.host_oe(host_oe),
		
		.snd_l(snd_l),
		.snd_r(snd_r),
		.snd_next_sample(snd_next_sample)
		
	);
	
endmodule	

//*********************************************************************************************** chip pcm
module chip_pcm(

	input rst, 
	input clk_asic,
	input sub_sync,

	output [7:0]regs_do,
	
	output MemCtrl_8 ram,
	input  [7:0]ram_dato,
	
	input  [12:0]host_addr,
	input  [7:0]host_data,
	input  host_ce,
	input  host_we,
	input  host_oe,
	
	output reg signed[15:0]snd_l,
	output reg signed[15:0]snd_r,
	output snd_next_sample
);
	
	PcnOutBus chan_bus;
	PcnIn chan_i;
	
//*************************************************  control registers
	wire mem_we;
	wire [3:0]ram_bank;

	
	pcm_ctrl pcm_ctrl_inst(

		.clk(clk_asic),
		.rst(rst),
		.sub_sync(sub_sync),
		
		.host_addr(host_addr),
		.host_data(host_data),
		.host_ce(host_ce),
		.host_we(host_we),
		
		.ram_dato(ram_dato), 
		.chan_bus(chan_bus),
		
		.mem_we(mem_we),
		.ram_bank(ram_bank),
		.regs_we(chan_i.reg_we),
		.pcm_on(chan_i.pcm_on),
		.reg_sel(chan_i.reg_sel),
		.chan_sw(chan_i.chan_sw),
		.regs_do(regs_do)
	);
//*************************************************  memory control	
	pcm_ramio pcm_ramio_inst(

		.clk(clk_asic),
		.rst(rst),
		.sub_sync(sub_sync),
		.pcm_on(chan_i.pcm_on),
		.mem_we(mem_we),
		.host_oe(host_oe),
		.host_data(host_data),
		.host_addr(host_addr),
		.chan_bus(chan_bus),
		
		.ram_bank(ram_bank),
		.ram_dato(ram_dato),
		.ram(ram),
		
		.sample(chan_i.sample)
	
	);

//*************************************************  channels	
	assign snd_next_sample		= chan_i.sample_ck;

	assign chan_i.rst				= rst;
	assign chan_i.clk				= clk_asic;
	assign chan_i.sub_sync		= sub_sync;	
	assign chan_i.host_data		= host_data[7:0];
	assign chan_i.host_addr		= host_addr[3:0];

	
	pcm_clocker pcm_clocker_inst(

		.clk(clk_asic),
		.sub_sync(sub_sync),
		.addr_ck(chan_i.addr_ck),
		.sample_ck(chan_i.sample_ck)
	);
	

	pcm_chan pcm0(.chan_i(chan_i), .chan_idx(0), .chan_o(chan_bus.chan[0]));
	pcm_chan pcm1(.chan_i(chan_i), .chan_idx(1), .chan_o(chan_bus.chan[1]));
	pcm_chan pcm2(.chan_i(chan_i), .chan_idx(2), .chan_o(chan_bus.chan[2]));
	pcm_chan pcm3(.chan_i(chan_i), .chan_idx(3), .chan_o(chan_bus.chan[3]));
	pcm_chan pcm4(.chan_i(chan_i), .chan_idx(4), .chan_o(chan_bus.chan[4]));
	pcm_chan pcm5(.chan_i(chan_i), .chan_idx(5), .chan_o(chan_bus.chan[5]));
	pcm_chan pcm6(.chan_i(chan_i), .chan_idx(6), .chan_o(chan_bus.chan[6]));
	pcm_chan pcm7(.chan_i(chan_i), .chan_idx(7), .chan_o(chan_bus.chan[7]));
	
//*************************************************  mixer	

	pcm_mixer pcm_mixer_inst(
	
		.clk(clk_asic),
		.rst(rst),
		.sample_ck(chan_i.sample_ck),
		.chan_bus(chan_bus),
		
		.snd_l(snd_l),
		.snd_r(snd_r)
	);
	

endmodule

//************************************************************************************* control registers
module pcm_ctrl(

	input  clk,
	input  rst,
	input  sub_sync,
	
	input  [12:0]host_addr,
	input  [7:0]host_data,
	input  host_ce,
	input  host_we,
	
	input  [7:0]ram_dato, 
	input  PcnOutBus chan_bus,
	
	output mem_we,
	output [3:0]ram_bank,
	output regs_we,
	output pcm_on,
	output [2:0]reg_sel,
	output [7:0]chan_sw,
	output [7:0]regs_do
);


	assign regs_do		= 
	host_addr[12] 		? ram_dato[7:0] : 
	host_addr[0] == 0 ? chan_bus.chan[host_addr[3:1]].addr_last[7:0] : chan_bus.chan[host_addr[3:1]].addr_last[15:8];
	
	
	wire regs_ce 		= host_ce & host_addr[12:4] == 0;
	wire mem_ce 		= host_ce & host_addr[12] == 1;
	assign regs_we 	= regs_ce & host_we;
	assign mem_we 		= mem_ce  & host_we;

	
	always @(posedge clk)
	if(rst)
	begin
		ram_bank 		<= 0;
		reg_sel 			<= 0;
		pcm_on 			<= 0;
		chan_sw[7:0] 	<= 8'hff;
	end
		else
	if(sub_sync)
	begin
		
		
		if(regs_we & host_addr == 7)//control register
		begin
		
			pcm_on 				<= host_data[7];
			
			if(host_data[6] == 0)
			begin
				ram_bank[3:0]	<= host_data[3:0];
			end
			
			if(host_data[6] == 1)
			begin
				reg_sel[2:0]	<= host_data[2:0];
			end
			
		end
		
		if(regs_we & host_addr == 8)//on/off register
		begin
			chan_sw[7:0] 		<= host_data[7:0];
		end
		
	end
	
endmodule
//************************************************************************************* ram io 
module pcm_ramio(

	input  clk,
	input  rst,
	input  sub_sync,
	input  pcm_on,
	input  mem_we,
	input  host_oe,
	input  [7:0]host_data,
	input  [11:0]host_addr,
	input  PcnOutBus chan_bus,
	
	input  [3:0]ram_bank,
	input  [7:0]ram_dato,
	
	output MemCtrl_8 ram,
	output PcmSample sample
	
);

	
	reg [2:0]upd_ctr;
	reg [2:0]mem_state;
	reg mem_we_st;
	
	
	always @(posedge clk)
	if(sub_sync)
	begin
		
		mem_we_st			<= mem_we;
		
		if(rst)
		begin
			upd_ctr 			<= 0;
			mem_state 		<= 0;
			ram.we 			<= 0;
		end
			else
		if(mem_we & !mem_we_st)
		begin
			ram.addr[15:0] 	<= {ram_bank[3:0], host_addr[11:0]};
			ram.dati[7:0] 		<= host_data[7:0];
			mem_state 			<= 4;
			ram.oe 				<= 0;
		end
			else
		case(mem_state)
//*************************************************  read
			0:begin
				
				ram.we 				<= 0;
				
				if(pcm_on)
				begin
					ram.addr[15:0]	<= chan_bus.chan[upd_ctr].addr;
					mem_state 		<= 1;
					ram.oe 			<= 1;
				end
					else
				begin
					ram.addr[15:0] <= {ram_bank[3:0], host_addr[11:0]};//forever host read cycle if pcm
					ram.oe 			<= host_oe;
				end
				
			end
			1:begin
				mem_state 		<= mem_state + 1;//+80ns
			end
			2:begin
				sample.chan[upd_ctr]	<=  ram_dato[7:0];
				upd_ctr 			<= upd_ctr + 1;
				ram.oe 			<= 0;
				mem_state 		<= 0;
			end
//*************************************************  write
			4:begin
				ram.we 			<= 1;
				mem_state 		<= mem_state + 1;
			end
			5:begin
				mem_state 		<= mem_state + 1;//+80ns
			end
			6:begin
				ram.we 			<= 0;
				mem_state 		<= 0;
			end
			
		endcase
	
	end
	
endmodule

//************************************************************************************* pcm clock generator
module pcm_clocker(

	input  clk,
	input  sub_sync,
	output addr_ck,
	output sample_ck
);
	
	assign addr_ck			= pcm_ck & pcm_ck_phase == 0;
	assign sample_ck		= pcm_ck & pcm_ck_phase == 1;
	
	wire pcm_ck				= sub_sync & pcm_ck_ctr == 191;//2x pcm clk (32552 * 2)
	reg [7:0]pcm_ck_ctr;
	reg pcm_ck_phase;
	
	always @(posedge clk)
	if(sub_sync)
	begin
	
		pcm_ck_ctr			<= pcm_ck ? 0 : pcm_ck_ctr + 1;
		
		if(pcm_ck)
		begin
			pcm_ck_phase	<= !pcm_ck_phase;
		end

	end
	
endmodule

//************************************************************************************* 


module pcm_mixer(
	
	input  clk,
	input  rst,
	input  sample_ck,
	input  PcnOutBus chan_bus,
	
	output signed[15:0]snd_l,
	output signed[15:0]snd_r
);
	
	wire [2:0]chan_idx;
	
	pcm_mix_mono pcm_mix_l(
	
		.clk(clk),
		.sample_ck(sample_ck),
		.sample(chan_bus.chan[chan_idx].snd_l),
		
		.chan_idx(chan_idx),
		.snd_o(snd_l)
	);
	
	pcm_mix_mono pcm_mix_r(
	
		.clk(clk),
		.sample_ck(sample_ck),
		.sample(chan_bus.chan[chan_idx].snd_r),
		
		.snd_o(snd_r)
	);
	
endmodule

//************************************************************************************* mixer

module pcm_mix_mono(

	input  clk,
	input  sample_ck,
	input  [14:0]sample,
	
	output [2:0]chan_idx,
	output signed [15:0]snd_o
);
	
	assign chan_idx					= mix_ctr[2:0];
	
	wire sample_sig 					= sample[14];
	wire signed [14:0]sample_val 	= sample[13:0];
	
	reg [3:0]mix_ctr;
	reg signed[18:0]snd_acc;
	
	
	always @(posedge clk)
	if(sample_ck)
	begin
		mix_ctr		<= 0;
	end
		else
	if(mix_ctr < 9)
	begin
		mix_ctr		<= mix_ctr + 1;
	end
	
	
	always @(posedge clk)
	if(sample_ck)
	begin
		snd_o			<= snd_acc;
		snd_acc		<= 0;
	end
		else
	if(mix_ctr < 8)
	begin
		snd_acc		<= sample_sig == 1 ? (snd_acc - sample_val) : (snd_acc + sample_val);
	end
		else
	if(mix_ctr == 8)
	begin
	
		if(snd_acc < -32768)
		begin
			snd_acc	<= -32768;
		end
			else
		if(snd_acc >  32767)
		begin
			snd_acc 	<= 32767;
		end
	end
	
endmodule

//************************************************************************************* channel 

module pcm_chan(
	
	input  PcnIn chan_i,
	input  [2:0]chan_idx,
	output PcnOut chan_o
);

	parameter HI 		= LO+15;
	parameter LO		= 11;

//************************************************* regs
	wire reg_we_this 	= chan_i.reg_we  & chan_i.reg_sel == chan_idx;
	
	wire [7:0]env 		= regs[0][7:0];
	wire [7:0]pan 		= regs[1][7:0];
	wire [15:0]fd 		= {regs[3][7:0], regs[2][7:0]};
	wire [15:0]ls 		= {regs[5][7:0], regs[4][7:0]};//loop adders.
	wire [7:0]st  		= regs[6][7:0];

	reg [7:0]regs[7];
	
	always @(posedge chan_i.clk)
	if(chan_i.rst)
	begin
		regs[0][7:0] 	<= 0;
		regs[1][7:0] 	<= 8'hff;
		regs[2][7:0] 	<= 0;
		regs[3][7:0] 	<= 0;
		regs[4][7:0] 	<= 0;
		regs[5][7:0] 	<= 0;
		regs[6][7:0] 	<= 0;
	end
		else
	if(chan_i.sub_sync & reg_we_this & chan_i.host_addr[3:0] < 7)
	begin
		regs[chan_i.host_addr[2:0]]	<= chan_i.host_data[7:0];
	end
	
//************************************************* sample reader
	assign chan_o.addr[15:0]	= addr_ctr[HI:LO];
	
	wire [7:0]pcm_dat				= chan_i.sample.chan[chan_idx];
	wire chan_off 					= chan_i.chan_sw[chan_idx] | !chan_i.pcm_on;
	
	reg [HI:0]addr_ctr;
	reg [7:0]pcm_sample;

	
	always @(posedge chan_i.clk)
	if(chan_i.rst)
	begin
		pcm_sample				<= 0;
		addr_ctr					<= 0;
	end
		else
	if(chan_i.addr_ck | chan_off)// | chan_off ?
	begin
		
		if(chan_off)
		begin
			addr_ctr[HI:HI-7] <= st[7:0];
			addr_ctr[HI-8:0] 	<= 0;
			pcm_sample			<= 0;//reset it here?
		end
			else
		if(pcm_dat[7:0] == 8'hff)
		begin
			addr_ctr[HI:LO] 	<= ls[15:0];
			addr_ctr[LO-1:0] 	<= 0;
		end
		
	end
		else
	if(chan_i.sample_ck)
	begin
		addr_ctr 			<= addr_ctr + fd;
		pcm_sample[7:0] 	<= pcm_dat[7:0];
	end
	
	//visible sample address shouldn't toggle during infinity loop at 0xff
	always @(posedge chan_i.clk)
	if(chan_i.sample_ck)
	begin
		chan_o.addr_last	<= addr_ctr[HI:LO];
	end
//************************************************* snd calc
	reg pan_sig;
	reg [15:0]env_vol;
	reg [18:0]pan_l, pan_r;
	
	always @(posedge chan_i.clk)
	if(chan_i.sub_sync)
	begin
	
		env_vol[15:0] 			<= pcm_sample[6:0] * env[7:0];
		pan_sig 					<= pcm_sample[7];
		
		pan_l[18:0] 			<= env_vol[15:0] * pan[3:0];
		pan_r[18:0] 			<= env_vol[15:0] * pan[7:4];
		
		
		if(chan_i.sample_ck & chan_i.pcm_on)
		begin
			chan_o.snd_l[14:0] <= chan_off ? 0 : {pan_sig, pan_l[18:5]};
			chan_o.snd_r[14:0] <= chan_off ? 0 : {pan_sig, pan_r[18:5]};
		end
		
	end

endmodule
