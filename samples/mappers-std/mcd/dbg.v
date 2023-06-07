

module dbg_led(

	input clk_asic,
	input led_in,
	output led_out, 
	input sync
);

	assign led_out = ctr != 0;

	reg [3:0]ctr;
	reg led_st;
	
	always @(negedge clk_asic)
	begin
		
		led_st <= led_in;
		
		if(led_st)ctr <= 1;
			else
		if(sync & ctr != 0)ctr <= ctr + 1;
		
		
	end

endmodule


module dbg2(
	
	input rst,
	input clk_asic, sub_sync,
	input [15:0]sub_do, sub_di,
	input [23:0]sub_addr,
	input sub_we_lo, sub_we_hi, sub_oe, sub_as,
	input regs_ce_sub,
	output sub_halt,
	output uart_tx,
	
	input [14:0]regs_addr_sub,
	input [15:0]reg_8002_do, reg_8032_do,
	
	input [15:0]main_din,
	input [15:0]main_dout,
	input [17:0]main_addr,
	input regs_ce_main, main_oe, main_we_lo, main_we_hi
);

	
	reg uart_we;
	reg [3:0]state;
	reg [3:0]tx_ctr;
	reg [7:0]dbg_data[8];
	
	wire ce_pram = {sub_addr[23:19], 19'd0} == 0;
	wire ce_wram_lo = {sub_addr[23:18], 18'd0} == 24'h080000;
	wire ce_wram_hi = {sub_addr[23:17], 17'd0} == 24'h0C0000;
	wire ce_regs = {sub_addr[23:15], 15'd0} ==    24'hFF8000;
	wire ce_regs_cdd = (regs_addr_sub >= 8'h38 & regs_addr_sub <= 8'h4A) & regs_ce_sub;
	wire ce_regs_com = (regs_addr_sub >= 8'h0e & regs_addr_sub <= 8'h2E) & regs_ce_sub;
	
	wire dbg_io = (!sub_we_lo | !sub_we_hi | !sub_oe) & !sub_as & (sub_addr == 24'hff8004 | sub_addr == 24'hff8006 | sub_addr == 24'hff8002);// & !ce_pram & !ce_wram_lo & !ce_wram_hi & !ce_regs_com & !ce_regs_cdd;
	
	//wire dbg_io_main
	
	reg [7:0]delay;
	
	assign sub_halt = state!= 0 & !ack;
	reg ack;
	
	reg regs_ce_main_st;
	reg regs_oe_main_st;
	reg regs_we_main_st;
	reg main_set_mod_st;
	wire main_set_mod = regs_we_main_st & main_addr[15:0] == 16'h2002;
	
	
	reg [15:0]main_mem_mod;
	reg [15:0]main_mctr;
	
	always @(negedge clk_asic)
	begin
	
		regs_ce_main_st <= regs_ce_main;
		regs_oe_main_st <= regs_ce_main & !main_oe;
		regs_we_main_st <= regs_ce_main & (!main_we_lo | !main_we_hi);
		
		main_set_mod_st <= main_set_mod;
		
		if(main_set_mod & !main_set_mod_st)
		begin
			main_mem_mod <= main_dout;
			main_mctr <= main_mctr + 1;
		end
		
		if(!dbg_io)ack <= 0;
	
		if(delay)delay <= delay - 1;
			else
		
		case(state)
				0:if(sub_sync)begin
				
					if(dbg_io)tx_ctr <= 0;
					
					if(dbg_io)delay <= 2;
					if(dbg_io)ack <= 1;
					
					dbg_data[0] <= 8'hA8 | {sub_we_hi, sub_we_lo, sub_oe};
					dbg_data[1] <= sub_addr[7:0];
					
					/*
					if(sub_addr == 24'hff8002)
					begin
						dbg_data[2] <= {main_mctr[3:0], main_mem_mod[3:0]};
						dbg_data[3] <= !sub_oe ? sub_di[7:0] : sub_do[7:0];
						if(dbg_io)state <= state + 2;
					end
						else
					begin
						dbg_data[2] <= !sub_oe ? sub_di[15:8] : sub_do[15:8];
						dbg_data[3] <= !sub_oe ? sub_di[7:0] : sub_do[7:0];
						if(dbg_io)state <= state + 1;
					end*/
					
					dbg_data[2] <= reg_8002_do[15:8];
					dbg_data[3] <= reg_8002_do[7:0];
					if(dbg_io)state <= state + 2;
					
					
				 end
				1:begin
					

					if(!sub_oe)dbg_data[2] <= sub_di[15:8];
					if(!sub_oe)dbg_data[3] <= sub_di[7:0];
							
					state <= state + 1;
				end
				2:begin
					uart_we <= 1;
					state <= state + 1;
				end
				3:begin
					uart_we <= 0;
					state <= state + 1;
				end
				4:begin
					state <= state + 1;
				end
				5:begin
					if(uart_txe)state <= state + 1;
				end
				6:begin
					state <= tx_ctr == 3 ? 0 : 2;
					tx_ctr <= tx_ctr + 1;
				end
				7:begin
					//delay <= 4;
					state <= 0;
				end
		endcase
	
	end
	
	
	wire uart_txe;
	
	uart_txm uart_inst(
	
		.data(dbg_data[tx_ctr]),
		.clk(clk_asic), 
		.wr(uart_we),
		.tx(uart_tx),
		.txe(uart_txe)
	);

endmodule

module dbg(
	
	input rst,
	input clk_asic, clk_sub,
	input [15:0]sub_do, sub_di,
	input [23:0]sub_addr,
	input sub_we_lo, sub_we_hi, sub_oe,
	input [2:0]sub_irq,
	
	input regs_ce_sub,
	
	output sub_halt, 
	output uart_tx,
	input dbg_off
	
);
	
	
	assign sub_halt = tx_state != 0 & dbg_regs;
	
	reg [1:0]irq_st;
	reg [3:0]tx_ctr;
	reg [3:0]tx_state;
	reg uart_we;
	
	wire [15:0]hdr = 16'hA500 | mode | rw << 2;
	reg [15:0]cpu_dat;
	reg [15:0]reg_addr;
	reg [23:0]mem_addr;
	reg [1:0]mode;
	reg [1:0]rw;
	
	
	wire prg_ce = !sub_oe & sub_addr < 24'h80000;
	wire irq_act = sub_irq != 3'b111;
	
	wire cdc_rd = regs_addr_sub == 8'h42 & sub_do[11:8] == 3;
	wire skip_regs = cdc_rd ? 0 : regs_addr_sub == 9'h00E | (regs_addr_sub >= 8'h38 & regs_addr_sub <= 8'h4A) | (regs_addr_sub >= 8'h10 & regs_addr_sub <= 8'h2E);
	
	wire [8:0]regs_addr_sub = sub_addr[8:0];
	wire dbg_regs = regs_ce_sub & !skip_regs;
	wire dbg_mem = 0;//!sub_oe & sub_addr < 24'h6000;
	wire dbg_irq = irq_st == 2'b01;
	
	
	wire [7:0]tx_buff[9];
	assign tx_buff[0][7:0] = hdr[15:8];
	assign tx_buff[1][7:0] = hdr[7:0];
	assign tx_buff[2][7:0] = cpu_dat[15:8];
	assign tx_buff[3][7:0] = cpu_dat[7:0];
	assign tx_buff[4][7:0] = reg_addr[15:8];
	assign tx_buff[5][7:0] = reg_addr[7:0];
	assign tx_buff[6][7:0] = mem_addr[23:16];
	assign tx_buff[7][7:0] = mem_addr[15:8];
	assign tx_buff[8][7:0] = mem_addr[7:0];
	
	reg txe_st;
	
	always @(negedge clk_sub)txe_st <= uart_txe;
	
	always @(negedge clk_sub)
	if(rst | dbg_off)
	begin
		mode <= 0;
		irq_st <= 0;
		tx_state <= 0;
		uart_we <= 0;
	end
		else
	begin
	
		irq_st[1:0] <= {irq_st[0], irq_act};
	
		if(mode == 0 & dbg_regs & !sub_oe)
		begin
			mode <= 1;
			reg_addr <= sub_addr;
			cpu_dat <= sub_di;
			rw[0] <= !sub_we_hi;
			rw[1] <= !sub_we_lo;
		end
			else
		if(mode == 0 & dbg_regs & (!sub_we_lo | !sub_we_hi))
		begin
			mode <= 2;
			reg_addr <= sub_addr;
			cpu_dat <= sub_do;
			rw[1] <= !sub_we_hi;
			rw[0] <= !sub_we_lo;
		end
			else
		if(mode == 0 & dbg_irq)
		begin
			mode <= 3;
			cpu_dat <= sub_irq ^ 3'b111;
		end
		
		if(!dbg_irq & !dbg_regs & mode != 0 & tx_state == 0)tx_state <= 1;
		
		
		//if((mode == 1 | mode == 2) & prg_ce & tx_state == 0)
		if(mode == 0 & prg_ce & tx_state == 0 & sub_addr < 24'h6000)
		begin
			mem_addr <= sub_addr;
			
		end
		
		
		case(tx_state)
			0:begin
				tx_ctr <= 0;
				uart_we <= 0;
			end
			1:begin
				uart_we <= 1;
				tx_state <= tx_state + 1;
			end
			2:begin
				uart_we <= 0;
				tx_state <= tx_state + 1;
			end
			3:begin
				if(txe_st)tx_state <= tx_state + 1;
			end
			4:begin
			
				if(tx_ctr == 8)
				begin
					tx_state <= 0;
					mode <= 0;
				end
					else
				begin
					tx_state <= 1;
					tx_ctr <= tx_ctr + 1;
				end
				
			end
		endcase
	
	end
	
	wire uart_txe;
	
	uart_txm uart_inst(
	
		.data(tx_buff[tx_ctr]),
		.clk(clk_asic), 
		.wr(uart_we),
		.tx(uart_tx),
		.txe(uart_txe)
	);

endmodule

