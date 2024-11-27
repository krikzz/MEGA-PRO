

module map_mcv(
	input  MapIn mai,
	output MapOut mao
);

	CpuBus cpu;
	assign cpu 		= mai.cpu;
	
	PiBus	pi;
	assign pi		= mai.pi;
	
	wire clk;
	assign clk		= mai.clk;
	
	DacBus dac;
	assign mao.dac	= dac;
	
	BramIO brm_off;
	BramIO brmx;
	BramIO srm;
	BramIO eep;
//************************************************************************************* config	
	assign mao.mask_off 	= 1;

	MemBus mem(mao.rom0, mai.rom0_do);
//************************************************************************************* mapper logic
	
	assign mem.addr[21:0] 		= !mem.oe ?  {3'b100, pi_addr[18:0]} :  cpu_addr[21:0];
	assign mem.we_lo				= mem_we;
	assign mem.we_hi				= mem_we;
	
	assign mao.map_oe 			= mem_oe_cpu;
	assign mao.map_do[15:0]		= cpu_addr[21] ? dma_buff : mem.oe ? mem.dato : cpu_buff;
	
	wire mem_ce_pi 				= {pi.addr[24:18], 18'd0} == 25'h1F80000;//mcu address space
	wire mem_we_pi					= mem_ce_pi & pi.we_sync;
	
	wire mem_ce_cpu				= cpu.addr[23:22] == 0;
	wire mem_oe_cpu				= mem_ce_cpu & !cpu.oe;
	
	
	reg mem_we;
	reg mem_oe_req;
	reg [2:0]delay;
	
	reg pi_we_req;
	reg [18:0]pi_addr;
	reg [7:0]pi_buff;	

	reg [15:0]dma_buff;
	reg [15:0]dma_buff_next;
	reg [21:0]cpu_addr;
	reg [15:0]cpu_buff;
	
	always @(posedge clk)
	begin
		
		if(mem_we_pi & pi.addr[0] == 0)
		begin
			pi_buff[7:0]	<= pi.dato[7:0];
		end
		
		if(!pi_we_req & mem_we_pi & pi.addr[0] == 1)
		begin
			mem.dati[15:8]	<= pi_buff;
			mem.dati[7:0]	<= pi.dato[7:0];
			pi_addr[18:1]	<= pi.addr[18:1];
			pi_we_req		<= 1;
		end
		
		
		if(!mem_oe_req & mem_oe_start)
		begin
			dma_buff 		<= dma_buff_next[15:0];
			mem_oe_req		<= 1;			
			cpu_addr[21:0]	<= cpu.addr[21:0];
		end
	
	
	
		if(delay != 0)
		begin
			delay				<= delay - 1;
		end
			else
		if(mem.oe | mem_we)
		begin
			mem.oe			<=	0;
			mem_we			<=	0;
		end
			else
		if(mem_oe_req | mem_oe_start)
		begin
			mem.oe			<=	1;
			delay				<= 3;
		end
			else
		if(pi_we_req | (mem_we_pi & pi.addr[0] == 1))
		begin
			mem_we			<=	1;
			delay				<= 3;
		end
		
		
		if(delay	== 0 & mem.oe & cpu_addr[21])
		begin
			dma_buff_next	<= mem.dato[15:0];
		end
		
		
		if(delay	== 0 & mem.oe)
		begin
			cpu_buff 		<= mem.dato[15:0];
			mem_oe_req		<= 0;
		end
		
		if(delay == 0 & mem_we)
		begin
			pi_we_req		<= 0;
		end
	
	end
	
	
	
	wire mem_oe_start;
	wire mem_oe_end;
	
	edge_dtk edge_mem_oe(

		.clk(clk),
		.sync_mode(0),
		.delay(0),
		.sig_i(mem_oe_cpu),
		.sig_pe(mem_oe_start),
		.sig_ne(mem_oe_end),
	);
	
	
//************************************* region selector
	reg pal_mode;
	
	always @(posedge clk)
	if(regs_we_edge)
	begin
		pal_mode 	<= cpu.data[0];
	end

	
	wire regs_we 		= !cpu.ce_lo & !cpu.we_lo & !cpu.as & cpu.addr == 'h300000;
	wire regs_we_edge;
	
	edge_dtk edge_regs_we(

		.clk(clk),
		.sync_mode(1),
		.sig_i(regs_we),
		.sig_pe(regs_we_edge),
	);
	
	
//************************************* dac controller	
	DacBus dac_pal;
	DacBus dac_ntsc;
	assign dac = pal_mode ? dac_pal : dac_ntsc;
	
	dac_controller dac_ctrl_pal(

		.clk(clk),
		.rst(0),
		.snd_on(1),
		.rate(36530),//44100/60*49,701459=36530
		.snd_l(pcm_l),
		.snd_r(pcm_r),
		
		.dac(dac_pal)
	);
	

	
	dac_controller dac_ctrl_ntsc(

		.clk(clk),
		.rst(0),
		.snd_on(1),
		.rate(44043),//44100/60*59,92274=44043
		.snd_l(pcm_l),
		.snd_r(pcm_r),
		
		.dac(dac_ntsc)
	);
	
//************************************* pcm buffer	
	wire buff_ce 	= {pi.addr[24:18], 18'd0} == 25'h1F80000;
	wire buff_we 	= buff_ce & pi.we_sync;
	wire pcm_ce  	= buff_ce & pi.addr[15:0] >= 40448;
	wire pcm_we		= pcm_ce & pi.we_sync;
	
	wire signed[15:0]pcm_l, pcm_r;
	
	pcm_buff pcm_buff_inst(
	
		.clk(clk),
		.dac(dac),
		.rst(0),
		.play(1),
		.buff_we(pcm_we),
		.addr_rst(0),
		.dati(pi.dato),
		
		.can_wr(),
		
		.pcm_l(pcm_l),
		.pcm_r(pcm_r)
		
	);
	
	
endmodule


module pcm_buff(
	
	input  clk,
	input  DacBus dac,
	input  rst,
	input  play,
	input  buff_we,
	input  addr_rst,
	input  [7:0]dati,
	
	output can_wr,
	
	output [15:0]pcm_l,
	output [15:0]pcm_r
);
	
	reg empty;
	reg [12:0]rd_addr;
	reg [12:0]wr_addr;
	
	reg [15:0]pcm_r_int;
	reg [15:0]pcm_l_int;
	reg [12:0]pcm_delta;
	
	
	always @(posedge clk)
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
	

	
	always @(posedge clk)
	if(!play)
	begin
		rd_addr 	<= 0;
		empty		<= 1;
	end
		else
	if(dac.clk & rd_addr[12:2] == wr_addr[12:2])
	begin
		empty 	<= 1;
	end
		else
	if(dac.clk & empty & dac.next_sample)
	begin
		empty		<= 0;
	end
		else
	if(dac.clk)
	begin
		
		if(dac.next_sample)
		begin
			pcm_r				<= pcm_r_int;
			pcm_l				<= pcm_l_int;
			rd_addr[12:2]	<= rd_addr[12:2] + 1;
		end
		
		if(dac.phase[6:0] == 0)
		begin
			rd_addr[1:0] 	<= dac.phase[8:7];
		end
		
		case(rd_addr[1:0])
			0:pcm_l_int[7:0] 	<= pcm_do;
			1:pcm_l_int[15:8] <= pcm_do;
			2:pcm_r_int[7:0] 	<= pcm_do;
			3:pcm_r_int[15:8] <= pcm_do;
		endcase
		
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
