
`include "../base/defs.v"

module map_fmv(

	output [`BW_MAP_OUT-1:0]mapout,
	input [`BW_MAP_IN-1:0]mapin,
	input clk
);
	
	`include "../base/mapio.v"
	`include "../base/sys_cfg.v"
	`include "../base/pi_bus.v"

		
	assign dtack = 1;
	assign mask_off = 1;
//*************************************************************************************
	assign mem_addr[`ROM0][20:0] = cpu_addr[20:0];
	assign mem_oe[`ROM0] = rom_ce & !oe_as;
	
	assign mem_di[`SRAM][15:0] = srm_di[15:0];
	assign mem_addr[`SRAM][18:0] = srm_addr[18:0];
	assign mem_oe[`SRAM] = srm_oe;
	assign mem_we_hi[`SRAM] = srm_we & srm_addr[0] == 0;
	assign mem_we_lo[`SRAM] = srm_we & srm_addr[0] == 1;
	
	assign map_oe = cart_ce & !oe_as;
	assign map_do[15:0] = rom_ce ? mem_do[`ROM0][15:0] : srm_do[15:0];
	
	assign led_r = pi_we & pi_ce_srm;
	
	wire cart_ce = !ce_hi;
	wire rom_ce = cart_ce & cpu_addr[21] == 0;
	wire ram_ce = cart_ce & cpu_addr[21] == 1;
	
	wire pi_ce_srm = {pi_addr[24:18], 18'd0} == 25'h1F80000;//mcu address space
	wire pi_we_srm = pi_ce_srm & pi_we_sync;
	
	//player uses 2x64K buffers for data streaming. Graphics chunk size 40448 bytes, data over this size goes to the pcm_fifo.
	//dual port ram buffer for fmv data.
	reg [15:0]srm_do;
	reg [15:0]srm_di;
	reg [18:0]srm_addr;
	reg srm_we;
	reg srm_oe;
	reg [1:0]srm_state;
	reg srm_oe_st;
	
	always @(negedge clk)
	begin
		
		srm_oe_st <= srm_oe;
		if(srm_oe & srm_oe_st)srm_do <= mem_do[`SRAM][15:0];

	
		case(srm_state)
			0:begin
			
				if(pi_we_srm)
				begin
					srm_addr <= pi_addr[18:0];
					srm_di <= {pi_do[7:0], pi_do[7:0]};
					srm_oe <= 0;
					srm_state <= srm_state + 1;
				end
					else
				begin
					srm_oe <= 1;
					srm_addr <= cpu_addr[18:0];
				end

			end
			1:begin
				srm_we <= 1;
				srm_state <= srm_state + 1;
			end
			2:begin
				srm_we <= 0;
				srm_state <= 0;
			end
			default:begin
				srm_state <= 0;
			end
			
		endcase
		
	end

	
//*************************************************************************************	
	wire [15:0]pcm_l, pcm_r;
	
	pcm_fifo fifo_inst(
		.clk(clk),
		.lrck(dac_lrck),
		.rst(map_rst),
		.mapin(mapin),
		.pcm_l(pcm_l), 
		.pcm_r(pcm_r)
	);
	
	
	dac_cs4344 dac_inst(
		.mclk(dac_mclk), 
		.lrck(dac_lrck),
		.sclk(dac_sclk),
		.sdin(dac_sdin),
		.vol_r(pcm_r),
		.vol_l(pcm_l),
		.clk(clk),
		.rst(map_rst)
	);


//40448	
endmodule

module pcm_fifo(
	input clk,
	input lrck, rst,
	input [`BW_MAP_IN-1:0]mapin,
	output reg [15:0]pcm_l, pcm_r
);

	`include "../base/map_in.v"
	`include "../base/pi_bus.v"
	
	
	wire buff_ce = {pi_addr[24:18], 18'd0} == 25'h1F80000;
	wire buff_we = buff_ce & pi_we_sync;
	wire pcm_ce  = buff_ce & pi_addr[15:0] >= 40448;
	wire pcm_we  = pcm_ce & pi_we_sync;
	
	
	reg [12:0]fifo_rd_addr;
	reg [12:0]fifo_wr_addr;
	reg [15:0]din_buff;
	reg lrck_st;
	
	always @(negedge clk)
	if(rst)
	begin
		fifo_rd_addr <= 0;
		fifo_wr_addr <= 0;
		lrck_st <= lrck;
	end
		else
	begin
	
		lrck_st <= lrck;
				
		if(lrck != lrck_st & fifo_rd_addr[12:1] != fifo_wr_addr[12:1])
		begin
			fifo_rd_addr <= fifo_rd_addr + 2;
			if(fifo_rd_addr[1] == 0)pcm_l <= ram_do;
			if(fifo_rd_addr[1] == 1)pcm_r <= ram_do;
		end
		
		
		if(pcm_we)
		begin
			if(fifo_wr_addr[0] == 0)din_buff[7:0] <= pi_do[7:0];
			fifo_wr_addr <= fifo_wr_addr + 1;
		end
		
		
	end
	
	
	wire [15:0]ram_do;
	wire [15:0]ram_di = {pi_do[7:0], din_buff[7:0]};
	
	
	ram_dp16 ram_inst(
	
		.addr_a(fifo_rd_addr[12:1]), 
		.dout_a(ram_do), 
		.clk_a(clk), 
		
		.din_b(ram_di), 
		.addr_b(fifo_wr_addr[12:1]), 
		.we_b(pcm_we & fifo_wr_addr[0] == 1), 
		.clk_b(clk)
	);


endmodule


module dac_cs4344(
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
	assign sdin = vol_bit;
	
	wire next_bit = ctr[3:0] == 4'b1111;
	wire next_vol = next_bit & bit_ctr == 15;
	wire [3:0]bit_ctr = ctr[7:4];
	wire aclk = clk_ctr >= (CLK_DIV - CLK_INC);

	
	reg [15:0]ctr;
	reg [15:0]vol;
	reg vol_bit;
	reg [21:0]clk_ctr;
	reg signed[24:0]over_r, over_l;
	
	
	parameter CLK_DIV = 2214425;
	parameter CLK_INC = 1000000;
	
		
	always @(negedge clk)
	if(rst)
	begin
		clk_ctr <= 0;
		ctr <= 0;
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


