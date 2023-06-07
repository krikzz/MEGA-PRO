

module mdp(
	
	input  MapIn mai,
	
	output mdp_oe,
	output [15:0]mdp_data,
	output [7:0]pi_di,
	output mdp_act,
	output mcu_mode,
	output DacBus dac
);
	
	wire clk				= mai.clk;
	
	CpuBus cpu;
	assign cpu 			= mai.cpu;

	PiBus  pi;
	assign pi			= mai.pi;
	
	assign mcu_mode	= mai.cfg.fea_mdp & !mai.map_rst;
	assign mdp_oe		= mdp_oe_int & mdp_act;
	//assign mdp_act		= mai.cfg.fea_mdp & (mdp_act_md | !mai.cfg.fea_mcd);
//************************************************************************************* mode selector	
	mdp_mode mdp_mode_inst(

		.clk(clk),
		.rst(mai.map_rst),
		.cpu(cpu),
		.mdp_on(mai.cfg.fea_mdp),
		.mcd_on(mai.cfg.fea_mcd),
		.mdp_act_int(mdp_act_int),
		.mdp_act(mdp_act)
	);
//************************************************************************************* md regs	

	wire cmd_exec;
	wire [15:0]cmd;
	wire dbud_ce_cpu;
	wire mdp_act_int;
	wire mdp_oe_int;
	
	mdp_md_regs(
	
		.clk(clk),
		.rst(mai.map_rst | !mai.cfg.fea_mdp),
		.cpu(cpu),
		.cmd_ack(cmd_ack),
		.resp(resp),
		.dbuf_do(dbuf_do_cpu),
		
		.dbud_ce(dbud_ce_cpu),
		.mdp_act(mdp_act_int),
		.cmd_exec(cmd_exec),
		.cmd(cmd),
		.mdp_oe(mdp_oe_int),
		.mdp_data(mdp_data)
	);
//************************************************************************************* pi regs
	wire pi_we_pcm;
	wire pcm_play;
	wire pcm_addr_rst;
	wire cmd_ack;
	wire [15:0]resp;
	wire [7:0]pcm_vol;
	wire dbud_ce_pi;
	
	
	mdp_pi_regs pi_regs_inst(

		.clk(clk),
		.pi(pi),
		.rst(mai.map_rst),
		.mdp_act(mdp_act),
		.pcm_can_wr(pcm_can_wr),
		.cmd_exec(cmd_exec),
		.cmd(cmd),
		.dbuf_do(dbuf_do_pi),
		
		.dbud_ce(dbud_ce_pi),
		.pi_we_pcm(pi_we_pcm),
		.pcm_play(pcm_play),
		.pcm_addr_rst(pcm_addr_rst),
		.cmd_ack(cmd_ack),
		.resp(resp),
		.pcm_vol(pcm_vol),
		.pi_di(pi_di)
	);
//************************************************************************************* data buff	
	wire [15:0]dbuf_do_cpu;
	wire [7:0]dbuf_do_pi;
	
	mdp_data_buff data_buff_inst(
	
		.clk(clk),
		.cpu(cpu),
		.pi(pi),
		.cpu_ce(dbud_ce_cpu),
		.pi_ce(dbud_ce_pi),
		
		.cpu_do(dbuf_do_cpu),
		.pi_do(dbuf_do_pi)
	);
		
//************************************************************************************* pcm buffer
	wire pcm_can_wr;
	wire signed [15:0]pcm_r;
	wire signed [15:0]pcm_l;
	
	mdp_pcm_buff pcm_buff_inst(
	
		.clk(clk),
		.dac_clk(dac.clk),
		.rst(mai.map_rst),
		.play(pcm_play),
		.buff_we(pi_we_pcm),
		.addr_rst(pcm_addr_rst),
		.dati(pi.dato),
		
		.can_wr(pcm_can_wr),
		.pcm_r(pcm_r),
		.pcm_l(pcm_l)
	);
//************************************************************************************* dac
	//wire dac_clk;
	
	clk_dvp dac_clk_inst(

		.clk(clk),
		.rst(mai.map_rst),
		.ck_base(50000000),
		.ck_targ(44100 * 512),
		.ck_out(dac.clk)
	);
	
	
	mdp_vol_ctrl vol_ctrl_inst(

		.clk(clk),
		.vol(pcm_vol),
		.snd_i_r(pcm_r),
		.snd_i_l(pcm_l),
		
		.snd_o_r(dac.snd_r),
		.snd_o_l(dac.snd_l)
	);
	

endmodule
//-------------------------------------------------------------------------------------
//-------------------------------------------------------------------------------------
//-------------------------------------------------------------------------------------
//------------------------------------------------------------------------------------- md regs
module mdp_md_regs(
	
	input  clk,
	input  rst,
	input  CpuBus cpu,
	input  cmd_ack,
	input  [15:0]resp,
	input  [15:0]dbuf_do,
	
	output dbud_ce,
	output mdp_act,
	output cmd_exec,
	output [15:0]cmd,
	output mdp_oe,
	output [15:0]mdp_data
);
	
	assign dbud_ce 	= ce_buf;
	
	assign mdp_oe 		= !cpu.oe & (ce_rsp | ce_id0 | ce_id1 | ce_buf | ce_cmd);
	assign mdp_data 	= 
	ce_cmd ? (cmd_exec ? 'hffff : 'h0000) ://cmd execution status
	ce_rsp ? resp :
	ce_id0 ? 'h5241 :
	ce_id1 ? 'h5445 :
	ce_buf ? dbuf_do :
				'hffff;

	wire ce_cmd		= !cpu.ce_lo & cpu.addr[21:0] == 'h3F7FE & ovl_on;
	wire ce_rsp		= !cpu.ce_lo & cpu.addr[21:0] == 'h3F7FC & ovl_on;
	wire ce_ovl		= !cpu.ce_lo & cpu.addr[21:0] == 'h3F7FA;
	wire ce_id0		= !cpu.ce_lo & cpu.addr[21:0] == 'h3F7F6 & ovl_on;
	wire ce_id1		= !cpu.ce_lo & cpu.addr[21:0] == 'h3F7F8 & ovl_on;
	wire ce_buf		= !cpu.ce_lo & {cpu.addr[21:11], 11'd0} == 'h3F800 & ovl_on;
	
	wire cmd_we		= we_edge & ce_cmd;
	
	reg ovl_on;//overlay
	
	reg [15:0]cmd_buff;
	reg cmd_ib;
	
	always @(negedge clk)
	if(rst)
	begin
		ovl_on 		<= 0;
		cmd_exec 	<= 0;
		mdp_act		<= 0;
		cmd_ib		<= 0;
	end
		else
	begin
		
		
		if(we_edge & ce_ovl)
		begin
			ovl_on	<= cpu.data == 'hCD54;
		end
		
		if(cmd_we & cmd_exec & !cmd_ack)
		begin
			cmd_buff	<= cpu.data;
			cmd_ib	<= 1;
		end
		
		
		if(cmd_we & !cmd_exec)
		begin
			cmd		<= cpu.data;
			cmd_exec <= 1;
		end
			else
		if(cmd_ack)
		begin
			cmd_exec <= cmd_ib;
			cmd		<= cmd_buff;
			cmd_ib	<= 0;
		end
		
		
		if(ovl_on)
		begin
			mdp_act 	<= 1;
		end
		
	end

	
	wire we_edge;
	sync_edge we_edge_inst(.clk(clk), .ce(!cpu.we_lo & !cpu.we_hi), .sync(we_edge));
	
endmodule
//------------------------------------------------------------------------------------- pi regs
module mdp_pi_regs(

	input  clk,
	input  PiBus  pi,
	input  rst,
	input  mdp_act,
	input  pcm_can_wr,
	input  cmd_exec,
	input  [15:0]cmd,
	input  [7:0]dbuf_do,
	
	output dbud_ce,
	output pi_we_pcm,
	output pcm_play,
	output pcm_addr_rst,
	output cmd_ack,
	output [15:0]resp,
	output [7:0]pcm_vol,
	output [7:0]pi_di
);
	
	assign dbud_ce		= pi_ce_dat;
	assign pi_we_pcm 	= pi.we_sync & pi_ce_pcm;
	assign cmd_ack 	= pi.we_sync & pi_reg_ack;

	always @(negedge clk)
	if(pi.sync)
	begin
		pi_di <= 
		pi_reg_stat & pi.addr[1:0] == 0 ? {pcm_can_wr, cmd_exec} :
		pi_reg_stat & pi.addr[1:0] == 1 ? (mdp_act ? 8'h2A : 8'hff) :
		pi_reg_stat & pi.addr[1:0] == 2 ? cmd[15:8] : 
		pi_reg_stat & pi.addr[1:0] == 3 ? cmd[7:0] :
		pi_ce_dat ? dbuf_do :
		8'hff;
	end
	
	
	wire pi_ce_reg		= pi.map.ce_mdp & {pi.addr[15:12], 12'd0} == 16'h0000;
	wire pi_ce_pcm 	= pi.map.ce_mdp & {pi.addr[15:12], 12'd0} == 16'h1000;
	wire pi_ce_dat 	= pi.map.ce_mdp & {pi.addr[15:12], 12'd0} == 16'h2000;
	
	
	wire pi_reg_stat	= pi_ce_reg & {pi.addr[7:2], 2'b0} == 0;//read status
	wire pi_reg_resp	= pi_ce_reg & {pi.addr[7:1], 1'b0} == 0;//write resp
	wire pi_reg_ack	= pi_ce_reg & pi.addr[7:0] == 3;
	wire pi_reg_ctrl	= pi_ce_reg & pi.addr[7:0] == 4;
	wire pi_reg_vol	= pi_ce_reg & pi.addr[7:0] == 5;
	
	
	
	always @(negedge clk)
	if(rst)
	begin
		pcm_play			<= 0;
		pcm_addr_rst 	<= 1;
	end
		else
	begin
		
		if(pi.we_sync & pi_reg_resp & pi.addr[0] == 0)
		begin
			resp[15:8]		<= pi.dato;
		end
		
		if(pi.we_sync & pi_reg_resp & pi.addr[0] == 1)
		begin
			resp[7:0] 		<= pi.dato;
		end
		
		if(pi.we_sync & pi_reg_ctrl)
		begin
			pcm_play			<= pi.dato[0];
			pcm_addr_rst	<= !pi.dato[0];
		end
		
		if(pi.we_sync & pi_reg_vol)
		begin
			pcm_vol[7:0] 	<= pi.dato;
		end
		
		if(pi.we_sync & pi_ce_pcm)
		begin
			pcm_addr_rst	<= 0;
		end
		
	end
	
endmodule
//------------------------------------------------------------------------------------- pcm buffer

module mdp_pcm_buff(
	
	input  clk,
	input  dac_clk,
	input  rst,
	input  play,
	input  buff_we,
	input  addr_rst,
	input  [7:0]dati,
	
	output can_wr,
	output [15:0]pcm_r,
	output [15:0]pcm_l
);
	
	
	reg empty;
	reg [12:0]rd_addr;
	reg [12:0]wr_addr;
	
	reg [15:0]pcm_r_int;
	reg [15:0]pcm_l_int;
	reg [12:0]pcm_delta;
	
	
	always @(negedge clk)
	begin
		
		if(buff_we)
		begin
			wr_addr <= wr_addr + 1;
		end
			else
		if(addr_rst)
		begin
			wr_addr <= 0;
		end
		
		can_wr		<= pcm_delta > 2352 | empty;
		
		pcm_delta	<= wr_addr < rd_addr ? rd_addr - wr_addr : rd_addr + (8192 -  wr_addr);

	end
	

	
	always @(negedge clk)
	if(!play)
	begin
		rd_addr 	<= 0;
		empty		<= 1;
	end
		else
	if(dac_clk & rd_addr[12:2] == wr_addr[12:2])
	begin
		empty 	<= 1;
	end
		else
	if(dac_clk & empty & dac_ctr == 511)
	begin
		empty		<= 0;
	end
		else
	if(dac_clk)
	begin
		
		if(dac_ctr == 511)
		begin
			pcm_r				<= pcm_r_int;
			pcm_l				<= pcm_l_int;
			rd_addr[12:2]	<= rd_addr[12:2] + 1;
		end
		
		if(dac_ctr[6:0] == 0)
		begin
			rd_addr[1:0] 	<= dac_ctr[8:7];
		end
		
		case(rd_addr[1:0])
			0:pcm_l_int[7:0] 	<= pcm_do;
			1:pcm_l_int[15:8] <= pcm_do;
			2:pcm_r_int[7:0] 	<= pcm_do;
			3:pcm_r_int[15:8] <= pcm_do;
		endcase
		
	end
	
	
//******************** sync with dac	
	reg [8:0]dac_ctr;
	
	always @(negedge clk)
	if(rst)
	begin
		dac_ctr	<= 0;
	end
		else
	if(dac_clk)
	begin
		dac_ctr 	<= dac_ctr + 1;
	end
//******************** buff memory	
	wire [7:0]pcm_do;
	
	ram_dp8 pcm_ram_inst(

		.clk_a(clk),
		.din_a(dati),
		.addr_a(wr_addr),
		.we_a(buff_we), 
		
		.clk_b(clk),
		.addr_b(rd_addr),
		.dout_b(pcm_do)
	);

endmodule

//-------------------------------------------------------------------------------------  data buff

module mdp_data_buff(
	
	input clk,
	input CpuBus cpu,
	input PiBus  pi,
	
	input cpu_ce,
	input pi_ce,
	
	output [15:0]cpu_do,
	output [7:0]pi_do
);
	
	assign cpu_do[15:0] 	= {cpu_do_hi[7:0], cpu_do_lo[7:0]};
	assign pi_do[7:0]		= pi.addr[0] == 0 ? pi_do_hi : pi_do_lo;
	
	wire [7:0]cpu_do_hi;
	wire [7:0]pi_do_hi;

	ram_dp8 data_ram_hi(

		.clk_a(clk),
		.din_a(cpu.data[15:8]),
		.addr_a(cpu.addr[10:1]),
		.we_a(we_edge_hi), 
		.dout_a(cpu_do_hi),
		
		.clk_b(clk),
		.din_b(pi.dato[7:0]),
		.addr_b(pi.addr[10:1]),
		.we_b(pi_ce & pi.we_sync & pi.addr[0] == 0), 
		.dout_b(pi_do_hi)
	);
	
	
	wire [7:0]cpu_do_lo;
	wire [7:0]pi_do_lo;

	ram_dp8 data_ram_lo(

		.clk_a(clk),
		.din_a(cpu.data[7:0]),
		.addr_a(cpu.addr[10:1]),
		.we_a(we_edge_lo), 
		.dout_a(cpu_do_lo),
		
		.clk_b(clk),
		.din_b(pi.dato[7:0]),
		.addr_b(pi.addr[10:1]),
		.we_b(pi_ce & pi.we_sync & pi.addr[0] == 1), 
		.dout_b(pi_do_lo)
	);
	
	wire we_edge_lo;
	wire we_edge_hi;
	sync_edge we_lo_inst(.clk(clk), .ce(cpu_ce & !cpu.we_lo), .sync(we_edge_lo));
	sync_edge we_hi_inst(.clk(clk), .ce(cpu_ce & !cpu.we_hi), .sync(we_edge_hi));
	
endmodule

//------------------------------------------------------------------------------------- vol ctrl
module mdp_vol_ctrl(

	input clk,
	input [7:0]vol,
	input signed[15:0]snd_i_r,
	input signed[15:0]snd_i_l,
	
	output signed[15:0]snd_o_r,
	output signed[15:0]snd_o_l
);

	reg signed [8:0]cur_vol;//one extra bit to be signed
	
	reg [10:0]ctr;

	
	always @(negedge clk)
	begin
		
		ctr <= ctr + 1;
		
		if(ctr == 0 & cur_vol < vol)
		begin
			cur_vol <= cur_vol + 1;
		end
		
		if(ctr == 0 & cur_vol > vol)
		begin
			cur_vol <= cur_vol - 1;
		end
		
		snd_o_r 	<= snd_i_r * cur_vol / 256;
		snd_o_l	<= snd_i_l * cur_vol / 256;
		
	end
	
endmodule
//------------------------------------------------------------------------------------- mdp/mcd mode selector

module mdp_mode(

	input clk,
	input rst,
	input CpuBus cpu,
	input mdp_on,
	input mcd_on,
	input mdp_act_int,
	
	output mdp_act
);
	
	assign mdp_act = mode == MODE_MDP;
	
	parameter MODE_DEF	= 0;
	parameter MODE_MCD	= 1;
	parameter MODE_MDP	= 2;
	
	wire mcd_ctrl_we		= we_edge & cpu.addr == 'hA12000; 
	
	reg [1:0]mode;
	
	always @(negedge clk)
	if(rst)
	begin
		mode	<= MODE_DEF;
	end
		else
	begin
		
		if(!mdp_on & !mcd_on)
		begin
			mode	<= MODE_DEF;
		end
			else
		if(mdp_on & !mcd_on)
		begin
			mode	<= MODE_MDP;
		end
			else
		if(!mdp_on & mcd_on)
		begin
			mode	<= MODE_MCD;
		end
			else
		if(mode == MODE_DEF & mdp_on & mdp_act_int)
		begin
			mode	<= MODE_MDP;
		end
			else
		if(mode == MODE_DEF & mcd_on & mcd_ctrl_we)
		begin
			mode	<= MODE_MCD;
		end
	
	end
	
	wire we_edge;
	sync_edge we_edge_inst(.clk(clk), .ce(!cpu.we_lo), .sync(we_edge));
	
endmodule
