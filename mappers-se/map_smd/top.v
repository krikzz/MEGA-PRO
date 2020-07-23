
//mega everdrive pro se mapper (regular smd)

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
	assign cart = 0;
	assign dtak = 1'bz;
	
	assign sms[3:0] = 4'bzzzz;//sms mode control (unused, should be z) 
	
	assign dat_oe = 0;//bus output always enabled
	
	assign mcu_fifo_rxf = 1;//mcu fifo interface (unused, should be 1)
	assign mcu_mode = 1;//mcu master mode (unused, should be 1)
	
	assign ram1_ce = 1;//psram1 unused
	assign ram2_ce = 1;//sram unused
	
	assign mkey_oe = 1;//mkey off

	
//************************************************************************************* memory control

	wire cart_ce = !ce_lo;
	wire cart_oe = cart_ce & !oe;
	wire rom_ce = cart_ce & !ram_ce;
	wire ram_ce = cart_ce & addr[21] & ram_on;
	
	assign dat_dir = cart_ce & !oe ? 1 : 0;//data bus direction
	assign data[15:0] = !dat_dir ? 16'hzzzz : rom_ce ? ram0_data[15:0] : ram3_data[15:0];
	
	//rom
	assign ram0_data[15:0] = 16'hzzzz;
	assign ram0_addr[20:0] = addr[21:1];
	assign ram0_ce = !rom_ce;
	assign ram0_oe = 0;
	assign ram0_we = 1;
	
	//bram
	assign ram3_data[15:0] = !oe ? 16'hzzzz : data[15:0];
	assign ram3_addr[17:0] = addr[18:1];
	assign ram3_oe = !(ram_ce & !oe);
	assign ram3_we = !(ram_ce & (!we_lo | !we_hi));
	assign ram3_ub = !(!oe | !we_hi);
	assign ram3_lb = !(!oe | !we_lo);
	
//************************************************************************************* bram switch controller. equal to one used in beyond oasis.
	wire tim_we = !we_lo & !as & {addr[23:8], 8'd0} == 24'hA13000;
	reg [2:0]tim_we_st;
	reg ram_on;
	
	always @(negedge clk50, negedge rst)
	if(!rst)
	begin
		ram_on <= 0;
		tim_we_st <= 0;
	end
		else
	begin
		tim_we_st[2:0] <= {tim_we_st[1:0],tim_we};
		if(tim_we_st[2:0] == 3'b011)ram_on <= data[0];//switching between rom and ram in upper area
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

	
