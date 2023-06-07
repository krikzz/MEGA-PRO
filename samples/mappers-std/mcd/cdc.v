
module cdc(
	
	input rst, 
	input clk_asic,
	input cdc_host_data_main,

	input sub_sync, 
	input [15:0]sub_data,
	input [14:0]reg_addr,
	input sub_as,
	input regs_we_lo_sub, regs_we_hi_sub,
	input regs_oe_sub,
	input bus_req,
	
	input  [15:0]reg_8002_do,
	output [15:0]reg_8004_do, reg_8006_do, reg_8008_do, reg_800A_do,
	output irq5,
	
	output reg [18:0]dma_addr,
	output reg [15:0]dma_dat,
	output dma_ce_wram, dma_ce_pram, dma_ce_pcm, 
	output dma_ce_main, dma_ce_sub,
	output reg dma_we,
	
	input dclk,	
	input fsync,
	input McdIO cdio
);


	
	
	
	wire regs_we_hi = regs_we_hi_sub;
	wire regs_we_lo = regs_we_lo_sub;
	wire regs_we_xx = (regs_we_hi_sub | regs_we_lo_sub);
	wire regs_oe_xx = regs_oe_sub;
	
	
	reg [15:0]reg_8004;
	//wire ce_cdc_mode = regs_ce_sub & reg_addr == 9'h004;
	//wire ce_cdc_rs1 = regs_ce_sub & reg_addr == 9'h004;
	
	

//************************************************************************************** 	cdc regs	
	wire CMDIEN, DTEIEN, DECIEN, CMDBK, DTWAI, STWAI, DOUTEN, SOUTEN;
	wire DECEN, CTRL06, E01RQ, AUTORQ, ERAMRQ, WRRQ, QRQ, PRQ;
	wire SYIEN, SYDEN, DSCREN, COWREN, MODRQ, FORMRQ, MBCKRQ, SHDREN;
	wire CTRL27, CTRL26, CTRL25, BCKSL, DLAEN, CTRL22, STENCTL, STENTRG;
	
	assign {CMDIEN, DTEIEN, DECIEN, CMDBK, DTWAI, STWAI, DOUTEN, SOUTEN} = IFCTRL[7:0];
	assign {DECEN, CTRL06, E01RQ, AUTORQ, ERAMRQ, WRRQ, QRQ, PRQ} = CTRL0[7:0];
	assign {SYIEN, SYDEN, DSCREN, COWREN, MODRQ, FORMRQ, MBCKRQ, SHDREN} = CTRL1[7:0];
	assign {CTRL27, CTRL26, CTRL25, BCKSL, DLAEN, CTRL22, STENCTL, STENTRG} = CTRL2[7:0];
	
	wire cdc_reg_we = regs_we_lo & reg_addr == 9'h006;
	wire cdc_reg_oe = regs_oe_xx & reg_addr == 9'h006;
	
	wire sub_cycle_end = sub_as & !sub_as_st;
	
	wire dma_halt = (dma_dst_wram & !wram_avb) | (dma_dst_pram & !pram_avb);
	wire wram_avb = reg_8002_do[2] | reg_8002_do[1];
	wire pram_avb = !bus_req;
	
	wire dma_mem_ready = 
	dma_dst_pram ? sub_cycle_end & pram_avb : //prg ram
	dma_dst_wram ? sub_cycle_end & wram_avb : //1m mode or wram assigned to sub. may should be additionaly controlled cycle end confirmation
	dma_dst_pcm  ? sub_cycle_end : //pcm
	dma_dst_main ? !DSR :
	dma_dst_sub  ? !DSR :
	1;
	
	wire dma_dst_main = dma_dst == 3'b010;
	wire dma_dst_sub  = dma_dst == 3'b011;
	wire dma_dst_pcm  = dma_dst == 3'b100;
	wire dma_dst_pram = dma_dst == 3'b101;
	wire dma_dst_wram = dma_dst == 3'b111;
	
	wire dma_ce = cdc_dma | cdc_dma_st;
	assign dma_ce_main = dma_ce & dma_dst_main;
	assign dma_ce_sub  = dma_ce & dma_dst_sub;
	assign dma_ce_pcm  = dma_ce & dma_dst_pcm  & (dma_we | dma_we_st);
	assign dma_ce_pram = dma_ce & dma_dst_pram & (dma_we | dma_we_st);
	assign dma_ce_wram = dma_ce & dma_dst_wram & (dma_we | dma_we_st);
	
	wire soft_dma = dma_dst_main | dma_dst_sub;
	wire cdc_host_data_sub = reg_addr == 9'h008 & (regs_oe_xx | regs_we_xx);
	wire cdc_host_rd_main = cdc_host_st_main[1:0] == 2'b10;
	wire cdc_host_rd_sub = cdc_host_st_sub[1:0] == 2'b10;
	wire cdc_host_rd = dma_dst_main ? cdc_host_rd_main : dma_dst_sub ? cdc_host_rd_sub : 0;
	
	assign reg_8004_do[15:0] = {EDT, DSR, 1'b0, 2'd0, dma_dst[2:0], 3'd0, cdc_reg_addr[4:0]};
	//assign reg_8004_do[15:0] = {!cdc_dma, dma_data_ok, 3'd0, dma_dst[2:0], 4'd0, cdc_reg_addr[3:0]};
	assign reg_8006_do[7:0] = cdc_reg_addr[4] ? 8'hff : cdc_regs_do[cdc_reg_addr[3:0]][7:0];
	assign reg_8008_do[15:0] = host_data[15:0];
	assign reg_800A_do[15:0] = dma_addr[18:3];
	
	wire [7:0]cdc_regs_do[16];
	
	assign cdc_regs_do[0][7:0] = 8'hff;
	assign cdc_regs_do[1][7:0] = {1'b1, DTEI, DECI, 1'b1, !cdc_dma, 1'b1, !cdc_dma, 1'b1};//IFSTAT
	assign cdc_regs_do[2][7:0] = DBC[7:0];
	assign cdc_regs_do[3][7:0] = {!DTEI, !DTEI, !DTEI, !DTEI, DBC[11:8]};
	
	assign cdc_regs_do[4][7:0] = SHDREN ? 8'h00 : head[0][7:0];
	assign cdc_regs_do[5][7:0] = SHDREN ? 8'h00 : head[1][7:0];
	assign cdc_regs_do[6][7:0] = SHDREN ? 8'h00 : head[2][7:0];
	assign cdc_regs_do[7][7:0] = SHDREN ? 8'h00 : head[3][7:0];
	
	assign cdc_regs_do[8][7:0] = PT_LA[7:0];
	assign cdc_regs_do[9][7:0] = PT_LA[15:8];
	
	assign cdc_regs_do[10][7:0] = WA_LA[7:0];
	assign cdc_regs_do[11][7:0] = WA_LA[15:8];
	
	assign cdc_regs_do[12][7:0] = {CRCOK, 7'd0};		//STAT0
	assign cdc_regs_do[13][7:0] = 8'h00;				//STAT1
	assign cdc_regs_do[14][7:0] = {4'd0, MODE, FORM, 2'd0};	//STAT2
	assign cdc_regs_do[15][7:0] = {VALST, 7'h00};		//STAT3
	
	
	assign irq5 = cdc_irq_st[1:0] == 2'b01;//(DECI_ST[1:0] == 2'b10 & DECIEN) | (DTEI_ST[1:0] == 2'b10 & DTEIEN);////(fsync & DECEN & DECIEN);//!DECI & DTEIEN & DECIEN;//(!DTEI & DTEIEN) | (!DECI & DECIEN);
	
	
	reg [4:0]cdc_reg_addr;
	reg [7:0]IFCTRL;
	reg [15:0]WA, PT, DA, WA_LA, PT_LA;
	reg [11:0]DBC;//dma len
	reg [7:0]CTRL0;
	reg [7:0]CTRL1;
	reg [7:0]CTRL2;
	reg cdc_dma;
	reg [1:0]dma_state;
	reg [2:0]dma_dst;
	reg [11:0]frame_ctr;
	reg [7:0]head[4];
	reg block_decoding;
	reg [1:0]cdc_inc_st;
	reg cln_valst;
	reg dma_halt_st;
	reg dma_addr_inc;
	reg [3:0]dma_delay;
	
	reg [15:0]host_data;
	reg [1:0]cdc_host_st_main, cdc_host_st_sub;
	
	reg DTEI, DECI, VALST, MODE, FORM;
	
	reg EDT, DSR;
	reg RMOD;
	wire CRCOK = DECEN;
	
	wire cdc_rst = cdc_reg_we & cdc_reg_addr == 15;
	wire cdc_irq =  (!DECI & DECIEN) | (!DTEI & DTEIEN);
	

	reg [1:0]cdc_irq_st;
	reg  dma_we_st, cdc_dma_st, sub_as_st;
	
	always @(negedge clk_asic)
	if(sub_sync)
	begin	
		dma_we_st <= dma_we;//some hold ram for pram
		cdc_dma_st <= cdc_dma;
		sub_as_st <= sub_as;
		cdc_irq_st[1:0] <= {cdc_irq_st[0], cdc_irq};
		
		cdc_host_st_main[1:0] <= {cdc_host_st_main[0], cdc_host_data_main};
		cdc_host_st_sub[1:0] <=  {cdc_host_st_sub[0], cdc_host_data_sub};
	end
	
	/*
	reg [1:0]DECI_ST, DTEI_ST;
	always @(negedge clk_asic)
	if(sub_sync)
	begin
		DECI_ST[1:0] = {DECI_ST[0], DECI};
		DTEI_ST[1:0] = {DTEI_ST[0], DTEI};
	end*/
	
	always @(negedge clk_asic)
	//if(rst | cdc_rst)
	if(rst)
	begin
		cdc_dma <= 0;
		dma_we <= 0;
		IFCTRL <= 0;
		CTRL0 <= 0;
		CTRL1 <= 0;
		CTRL2 <= 0;
		EDT <= 0;
		DSR <= 0;
		DTEI <= 1;
		DECI <= 1;
		RMOD <= 0;
		//CRCOK <= 0;
		VALST <= 1;
		block_decoding <= 0;
		head[0] <= 8'h01;
		head[1] <= 8'h80;
		head[2] <= 8'h00;
		head[3] <= 8'h60;
		frame_ctr <= 0;
		MODE <= 0;
		FORM <= 0;
	end
		else
	if(sub_sync)
	begin
		
		cdc_inc_st[0] <= (regs_oe_xx | regs_we_xx) & reg_addr == 9'h006 & cdc_reg_addr != 0;
		cdc_inc_st[1] <= cdc_inc_st[0];
		dma_halt_st <= dma_halt;
		
		
		
		if(regs_we_lo & reg_addr == 9'h004)cdc_reg_addr[4:0] <= sub_data[4:0];
		if(cdc_inc_st[1:0] == 2'b10)cdc_reg_addr <= cdc_reg_addr + 1;
		
		if(regs_we_xx & reg_addr == 9'h00A)dma_addr[18:0] <= {sub_data[15:0], 3'd0};
		
		if(cdc_reg_we & cdc_reg_addr == 1)IFCTRL[7:0] <= sub_data[7:0];
		
		if(cdc_reg_we & cdc_reg_addr == 2)DBC[7:0] <= sub_data[7:0];
		if(cdc_reg_we & cdc_reg_addr == 3)DBC[11:8] <= sub_data[7:0];
		
		if(cdc_reg_we & cdc_reg_addr == 4)DA[7:0] <= sub_data[7:0];
		if(cdc_reg_we & cdc_reg_addr == 5)DA[15:8] <= sub_data[7:0];
		
		if(cdc_reg_we & cdc_reg_addr == 8)
		begin
			WA[7:0] <= sub_data[7:0];
			WA_LA[7:0] <= sub_data[7:0];
		end
		
		if(cdc_reg_we & cdc_reg_addr == 9)
		begin
			WA[15:8] <= sub_data[7:0];
			WA_LA[15:8] <= sub_data[7:0];
		end
		
		if(cdc_reg_we & cdc_reg_addr == 12)
		begin
			PT[7:0] <= sub_data[7:0];
			PT_LA[7:0] <= sub_data[7:0];
		end
		
		if(cdc_reg_we & cdc_reg_addr == 13)
		begin
			PT[15:8] <= sub_data[7:0];
			PT_LA[15:8] <= sub_data[7:0];
		end
		
		if(cdc_reg_we & cdc_reg_addr == 10)
		begin
			CTRL0[7:0] <= sub_data[7:0];
			//CRCOK <= sub_data[7];//DECEN;
			MODE <= MODRQ;
			if(sub_data[4])FORM <= FORMRQ;//dara[4] is AUTORQ bit
		end
		
		if(cdc_reg_we & cdc_reg_addr == 11)
		begin
			CTRL1[7:0] <= sub_data[7:0];
			MODE <= sub_data[3];//MODRQ bit
			if(AUTORQ)FORM <= sub_data[2];//FORMRQ bit
		end
		
		if(cdc_reg_we & cdc_reg_addr == 14)CTRL2[7:0] <= sub_data[7:0];
		
		
		if(cdc_reg_we & cdc_reg_addr == 15)//reset
		begin
			IFCTRL <= 0;
			CTRL0 <= 0;
			CTRL1 <= 0;
			FORM <= 0;
			MODE <= 0;
		end
		
		if(cdc_reg_oe & cdc_reg_addr == 15)
		begin
			cln_valst <= 1;
			DECI <= 1;
		end
		
		if(cln_valst & !cdc_reg_oe)
		begin
			cln_valst <= 0;
			//VALST <= 1;
		end
		
//************************************************************************************** dma 			
		
		
		
		if(dma_addr_inc)dma_addr_inc <= 0;
		if(dma_addr_inc)dma_addr <= dma_addr + 2;
		
		if(regs_we_hi & reg_addr == 9'h004)//dma dst
		begin
			dma_dst[2:0] <= sub_data[10:8];
			dma_addr <= 0;
			DSR <= 0;
			EDT <= 0;
			//cdc_dma <= 0;
		end

		if(cdc_reg_we & cdc_reg_addr == 6)//trigger
		begin
			if(DOUTEN)cdc_dma <= 1;
			DSR <= 0; //try batmen and robin if change DSR or EDT
			EDT <= 0; 
			//DTEI <=1;
		end
		
		if(cdc_reg_we & cdc_reg_addr == 7)//DTACK
		begin
			DTEI <=1;
		end
		
		
		if(DSR & (cdc_host_rd | !soft_dma))
		begin
			DSR <= 0;
		end
		
		if(!DOUTEN)
		begin
			cdc_dma <= 0;
			dma_we <= 0;
			DTEI <= 1;
		end
		
		//if((!dma_ce_main & !dma_ce_sub) | !cdc_dma)dma_data_ok <= 0;
		
		if(!cdc_dma)
		begin
			dma_state <= 0;
			dma_delay <= 8;
			dma_we <= 0;
		end
			else
		begin
			if(dma_delay)dma_delay <= dma_delay - 1;
		end
		
//*************************************************************************************** 16bit dma		
		if(cdc_dma & !dma_dst_pcm & !dma_delay)
		case(dma_state)
			0:begin
				dma_dat[15:8] <= cdc_buff_do[7:0];
				DA <= DA + 1;
				dma_state <= dma_state + 1;
			end
			1:begin
				dma_dat[7:0] <= cdc_buff_do[7:0];
				if(dma_mem_ready)DA <= DA + 1;
				if(dma_mem_ready)dma_we <= 1;
				if(dma_mem_ready)dma_state <= dma_state + 1;
			end
			2:begin
				if(soft_dma)host_data[15:0] <= dma_dat[15:0];
				if(soft_dma)DSR <= 1;
				if(!dma_halt & !dma_halt_st)dma_state <= dma_state + 1;//keep we delay if dma was halted
			end
			3:begin
				
				if(DBC[11:0] == 1)
				begin
					cdc_dma <= 0;
					DTEI <= 0;
					EDT <= 1;
				end
				
				DBC[11:0] <= DBC[11:0] - (!DBC[0] ? 3 : 2);//counter is not accurate. 2=2,3=2. for now 2=2,3=4 (fixed)
				
				dma_we <= 0;
				//dma_addr <= dma_addr + 2;
				if(!soft_dma)dma_addr_inc <= 1;
				dma_state <= 0;
				//if(!soft_dma)dma_delay <= 4;
				if(!soft_dma)dma_delay <= 3;//delays should be teseted
			end
		endcase
		
//*************************************************************************************** 8 bit dma for pcm
		if(cdc_dma & dma_dst_pcm & !dma_delay)
		case(dma_state)
			0:begin
				dma_dat[7:0] <= cdc_buff_do[7:0];
				DA <= DA + 1;
				dma_state <= dma_state + 1;
			end
			1:begin
				if(dma_mem_ready)dma_we <= 1;
				if(dma_mem_ready)dma_state <= dma_state + 1;
			end
			2:begin
				dma_state <= dma_state + 1;
				//dma_delay <= 12;
			end
			3:begin
				
				if(DBC[11:0] == 0)
				begin
					cdc_dma <= 0;
					DTEI <= 0;
					EDT <= 1;
				end
				
				DBC[11:0] <= DBC[11:0] - 1;//real hardware copies len + 1 in 8 bit mode
				
				dma_we <= 0;
				//dma_addr <= dma_addr + 2;
				dma_addr_inc <= 1;
				dma_state <= 0;
				dma_delay <= 14;//delays should be teseted
			end
			
		endcase

//************************************************************************************** cdc decoder
		if(!DECEN)frame_ctr <= cdio.cfg_pha;////decoder phase reset. rex 150-450//real. should take care about large enoug delta bwtween cdd irq
			else
		if(dclk)frame_ctr <= fsync_dec ? 0 : frame_ctr + 1;
		
		
		if(!SYIEN | !DECEN)DECI <= 1;
			else
		if(fsync_dec)DECI <= 0;
			else
		if(frame_ctr == 940)DECI <= 1;
		
		if(fsync_dec)VALST <= 0;
			else
		if(frame_ctr == 2048)VALST <= 1;//just my guess
		
		if(!DECEN)
		begin
			head[0] <= 8'h01;
			head[1] <= 8'h80;
			head[2] <= 8'h00;
			head[3] <= 8'h60;
			//VALST <= 1;
		end
			else
		if(fsync_dec & cdc_data_ready)
		begin
			
				head[0] <= cdc_head[0];
				head[1] <= cdc_head[1];
				head[2] <= cdc_head[2];
				head[3] <= cdc_head[3];
				
				if(WRRQ)WA_LA <= WA_LA + 2352;
				if(WRRQ)PT <= PT + 2352;
				if(WRRQ)PT_LA <= PT;
				
				//VALST <= 0;
		end
			else
		if(fsync_dec)
		begin
			head[0] <= 8'h01;
			head[1] <= 8'h80;
			head[2] <= 8'h00;
			head[3] <= 8'h60;
			//VALST <= 0;
		end
		
	end
	
	wire fsync_dec = frame_ctr == 2351 & dclk;//real mode
	//wire fsync_dec = fsync;
	
	/*
	reg [11:0]phase;
	always @(negedge clk_asic)
	begin
		if(phase == 0)phase <= 350;		
		if(pi.map.ce_pha & pi.addr[0] == 0)phase[11:8] <= pi.dato;
		if(pi.map.ce_pha & pi.addr[0] == 1)phase[7:0]  <= pi.dato;
	end*/
	
//************************************************************************************** cdc data receiver	
	reg [7:0]cdc_head[4];
	wire cdc_we = cdio.ce_cdc & cdio.we_sync;
	wire [13:0]rd_addr = DA[13:0];
	reg [13:0]wr_addr;
	reg cdc_data_ready;
	reg cdc_tx_idle;
	
	
	always @(negedge clk_asic)
	if(rst | cdc_rst)
	begin
		cdc_data_ready <= 0;
	end
		else
	begin
		
		cdc_tx_idle <= !cdio.we;
		
		if(cdc_tx_idle)//pi_we holds during whole transfer
		begin
			wr_addr <= PT;
		end
			else
		if(cdc_we)
		begin
			wr_addr <= wr_addr + 1;
			if(cdio.addr[11:0] == 0)cdc_head[0] <= cdio.dato;
			if(cdio.addr[11:0] == 1)cdc_head[1] <= cdio.dato;
			if(cdio.addr[11:0] == 2)cdc_head[2] <= cdio.dato;
			if(cdio.addr[11:0] == 3)cdc_head[3] <= cdio.dato;
		end
		
		if(cdc_we & cdio.addr[11:0] == 2351)cdc_data_ready <= 1;
			else
		if(fsync_dec & sub_sync)cdc_data_ready <= 0;
	
	end
	
	
	reg sync_ack;
	

//************************************************************************************** 	cdc buff
	wire [7:0]cdc_buff_do;
	
	ram_dp8x cdc_buff(

		.din(cdio.dato),
		.dout(cdc_buff_do),
		.we(cdc_we), 
		.clk(clk_asic),
		.addr_r(rd_addr[13:0]),
		.addr_w(wr_addr[13:0]),
	);
	
	
endmodule







