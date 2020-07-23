
//mega everdrive pro se mapper (sms)

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
	
	assign dat_oe = 0;//bus output always enabled
	
	assign mcu_fifo_rxf = 1;//mcu fifo interface (unused, should be 1)
	assign mcu_mode = 1;//mcu master mode (unused, should be 1)
	
	assign ram1_ce = 1;//psram1 unused
	assign ram2_ce = 1;//sram unused
	
	assign mkey_oe = 1;//mkey off

//************************************************************************************* memory control
	
	wire cart_oe = (rom_area | ram_area) & !oe;
	wire [15:0]rom_data8 = sms_addr[0] == 0 ? {ram0_data[15:8], ram0_data[15:8]} : {ram0_data[7:0], ram0_data[7:0]} ;
	wire [15:0]ram_data8 = sms_addr[0] == 0 ? {ram3_data[15:8], ram3_data[15:8]} : {ram3_data[7:0], ram3_data[7:0]};
	
	assign dat_dir = cart_oe ? 1 : 0;//data bus direction
	
	assign data[15:0] = !dat_dir ? 16'hzzzz : ram_area ? ram_data8 : rom_data8;
	
	//rom
	assign ram0_addr[12:0] = sms_addr[13:1];
	assign ram0_addr[20:13] = 
	{sms_addr[15:10], 10'd0} == 16'h0000 ? 0 : 
	{sms_addr[15:14], 14'd0} == 16'h0000 ? sms_bank[0][7:0] : 
	{sms_addr[15:14], 14'd0} == 16'h4000 ? sms_bank[1][7:0] : sms_bank[2][7:0];
	
	assign ram0_data[15:0] = 16'hzzzz;
	assign ram0_ce = !(rom_area);
	assign ram0_oe = !(rom_area & !oe);
	assign ram0_we = 1;
	
	//bram
	assign ram3_data[15:0] = !oe ? 16'hzzzz : {data[7:0], data[7:0]};
	assign ram3_addr[14:0] = {sms_ram_bank, sms_addr[13:0]};
	assign ram3_oe = !(ram_area & !oe);
	assign ram3_we = !(ram_area & !we_lo);
	assign ram3_ub = !(!oe | (!we_lo & sms_addr[0] == 0));
	assign ram3_lb = !(!oe | (!we_lo & sms_addr[0] == 1));
	
	assign sms[3:0] = {1'b0, btn, 2'b01};
//************************************************************************************* mapper registers

	wire [15:0]sms_addr = addr[16:1];
	wire sms_ce = !addr[18];
	wire rom_area = sms_ce & {sms_addr[15:14], 14'd0} != 16'hc000 & !ram_area;
	wire ram_area = sms_ce & {sms_addr[15:14], 14'd0} == 16'h8000 & sms_ram_flag;

	reg [7:0]sms_bank[3];
	reg sms_ram_bank;
	reg sms_ram_flag;


	always @(negedge clk50)
	if(hrst_int)
	begin
		sms_bank[0] <= 0;
		sms_bank[1] <= 1;
		sms_bank[2] <= 2;
		sms_ram_bank <= 0;
		sms_ram_flag <= 0;
	end
		else
	if(we_sync & sms_ce)
	begin
		if(sms_addr[15:0] == 16'hfffc){sms_ram_flag, sms_ram_bank} <= data[3:2];
		if(sms_addr[15:0] == 16'hfffd)sms_bank[0][7:0] <= data[7:0];
		if(sms_addr[15:0] == 16'hfffe)sms_bank[1][7:0] <= data[7:0];
		if(sms_addr[15:0] == 16'hffff)sms_bank[2][7:0] <= data[7:0];
	end

	
	wire we_sync = we_st[3:0] == 4'b1000;
	reg [3:0]we_st;
	
	always @(negedge clk50)
	begin
		we_st[3:0] <= {we_st[2:0], we_lo};
	end
	
//************************************************************************************* reset controller	
	assign mcu_rst = 0;
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

	
