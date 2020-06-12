
//mega everdrive pro se mapper (ssf)

module top(

	//cpu bus
	inout [15:0]data,
	input [23:1]addr,
	input as, cas, ce_lo, ce_hi, clk50, vclk, eclk, oe, rst, we_lo, we_hi, 
	output cart, dtak, hrst,  
	output [3:0]sms,
	
	//bus transceiver
	output dat_dir, dat_oe,
	
	//mcu spi
	output spi_miso,
	input  spi_mosi, spi_sck,
	input spi_ss,
	
	//mcu control
	output mcu_fifo_rxf, mcu_mode, mcu_sync, mcu_rst,
	input mcu_busy,

	//psram 0
	inout [15:0]ram0_data,
	output [21:0]ram0_addr,
	output ram0_oe, ram0_we, ram0_ub, ram0_lb, ram0_ce,
	
	//psram 1
	inout [15:0]ram1_data,
	output [21:0]ram1_addr,
	output ram1_oe, ram1_we, ram1_ub, ram1_lb, ram1_ce,
	
	//sram
	inout [15:0]ram2_data,
	output [17:0]ram2_addr,
	output ram2_oe, ram2_we, ram2_ub, ram2_lb, ram2_ce,
	
	//bram
	inout [15:0]ram3_data,
	output [17:0]ram3_addr,
	output ram3_oe, ram3_we, ram3_ub, ram3_lb, 

	//mcu io bus
	inout [3:0]xbus,
	
	//gpio
	input gpclk,
	inout [4:0]gpio,
	
	//dac i2s bus
	output dac_mclk, dac_lrck, dac_sclk, dac_sdin,
	
	//megakey and leds
	output mkey_oe, mkey_we, led_r, led_g,
	input btn

);

	
//************************************************************************************* unused signals designation
	assign dtak = 1'bz;
	
	assign sms[3:0] = 4'bzzzz;//sms mode control (unused, should be z) 
	
	assign dat_oe = 0;//bus output always enabled
	
	assign mcu_fifo_rxf = 1;//mcu fifo interface (unused, should be 1)
	assign mcu_mode = 1;//mcu master mode (unused, should be 1)
	
	assign ram2_ce = 1;//sram unused
	
	assign mkey_oe = 1;//mkey off

	
//************************************************************************************* memory control
	wire cart_ce = !ce_lo;
	wire cart_oe = cart_ce & !oe;
	wire rom_ce0 = cart_ce & rom_addr[23] == 0;
	wire rom_ce1 = cart_ce & rom_addr[23] == 1 & rom_addr[22:19] != 4'hf;
	wire ram_ce  = cart_ce & rom_addr[23] == 1 & rom_addr[22:19] == 4'hf;//ram mapped to last bank
	
	assign dat_dir = cart_ce & !oe ? 1 : 0;//data bus direction
	
	assign data[15:0] = 
	!dat_dir ? 16'hzzzz : 
	rom_ce0 ? ram0_data[15:0] : 
	rom_ce1 ? ram1_data[15:0] : 
	ram3_data[15:0];
	
	//rom 0-8MB
	assign ram0_data[15:0] = rom_ce0 & !oe ? 16'hzzzz : data[15:0];
	assign ram0_addr[21:0] = rom_addr[22:1];
	assign ram0_ce = !rom_ce0;
	assign ram0_oe = !(rom_ce0 & !oe);
	assign ram0_we = !(rom_ce0 & wr_on & (!we_lo | !we_hi));
	assign ram0_ub = !(!oe | !we_hi);
	assign ram0_lb = !(!oe | !we_lo);
	
	//rom 8-16MB
	assign ram1_data[15:0] = rom_ce1 & !oe ? 16'hzzzz : data[15:0];
	assign ram1_addr[21:0] = rom_addr[22:1];
	assign ram1_ce = !rom_ce1;
	assign ram1_oe = !(rom_ce1 & !oe);
	assign ram1_we = !(rom_ce1 & wr_on & (!we_lo | !we_hi));
	assign ram1_ub = !(!oe | !we_hi);
	assign ram1_lb = !(!oe | !we_lo);
	
	//bram
	assign ram3_data[15:0] = ram_ce & !oe ? 16'hzzzz : data[15:0];
	assign ram3_addr[17:0] = rom_addr[18:1];
	assign ram3_oe = !(ram_ce & !oe);
	assign ram3_we = !(ram_ce & wr_on & (!we_lo | !we_hi));
	assign ram3_ub = !(!oe | !we_hi);
	assign ram3_lb = !(!oe | !we_lo);
//************************************************************************************* ssf registerts
	wire tim_we = !we_lo & !as & {addr[23:4], 4'd0} == 24'hA130F0;
	wire tim_we_sync = tim_we_st[3:0] == 4'b0111;
	
	assign cart  = ssf_ctrl[0];
	assign led_r = ssf_ctrl[1];
	wire   wr_on = ssf_ctrl[2];
	
	wire [23:0]rom_addr = {ssf_bank[addr[21:19]][4:0], addr[18:1], 1'b0};
	
	reg [3:0]tim_we_st;
	reg [4:0]ssf_bank[8];
	reg [3:0]ssf_ctrl;
	
	always @(negedge clk50, negedge rst)
	if(!rst)
	begin
		tim_we_st <= 0;
		
		ssf_bank[0] <= 0;
		ssf_bank[1] <= 1;
		ssf_bank[2] <= 2;
		ssf_bank[3] <= 3;
		ssf_bank[4] <= 4;
		ssf_bank[5] <= 5;
		ssf_bank[6] <= 6;
		ssf_bank[7] <= 7;
		
		ssf_ctrl <= 0;
	end
		else
	begin
	
		tim_we_st[3:0] <= {tim_we_st[2:0],tim_we};
		
		if(tim_we_sync & addr[3:1] == 0)
		begin
			if(data[15]){ssf_ctrl[3:0], ssf_bank[0][4:0]} <= {data[14:11], data[4:0]};
		end
		
		if(tim_we_sync & addr[3:1] != 0)
		begin
			ssf_bank[addr[3:1]][4:0] <= data[4:0];
		end
		

	end
	
//************************************************************************************* reset controller	
	assign mcu_rst = btn;//return to menu using on-board button
	assign hrst = hrst_int ? 0 : 1'bz;
	wire hrst_int;
	
	hard_reset hrst_inst(
		.clk(clk50),
		.rst_in(0), 
		.rst_out(hrst_int)
	);
	
	
endmodule


module hard_reset(
	input clk,
	input rst_in,
	output rst_out
);
	
	assign rst_out = rst_ctr != 0;
	
	reg [1:0]rst_st;
	reg [23:0]rst_ctr;
	
	initial rst_st[1:0] = 2'b01;
	
	always @(negedge clk)
	begin
		
		rst_st[1:0] <= {rst_st[0], rst_in};
		
		if(rst_st[1:0] == 2'b01)rst_ctr <= 1;
			else
		if(rst_ctr != 0)rst_ctr <= rst_ctr + 1;
		
	end

endmodule

	
