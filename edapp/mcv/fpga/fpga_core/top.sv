

module top(
	
	inout  [15:0]MD_D,
	input  [23:1]MD_A,
	input  MD_ASn,
	input  MD_CEHn,
	input  MD_CELn,
	input  MD_OEn,
	input  MD_WEHn,
	input  MD_WELn,
	input  MD_VCLK,
	input  MD_SRSTFn,
	output [3:0]MD_SMS,
	output MD_CART,
	output MD_DTAKn,
	output MD_HRSTFn,
	output MD_DDIR,
	output MD_DOEn,
	
	output MKEY_ACT,
	output MKEY_SET,
	
	inout  [7:0]BRM_D,	
	output [16:0]BRM_A,
	output BRM_OEn,
	output BRM_WEn,
	output BRM_CE,
	
	output [21:0]PSR_A,
	inout  [15:0]PSR_D,
	output PSR_OEn,
	output PSR_WEn,
	output PSR_LBn,
	output PSR_UBn,
	output PSR_CEn,
	
	inout  [6:0]FCI_IO,
	input  FCI_MOSI,
	input  FCI_SCK,
	output FCI_MISO,
	//input  DCLK,//shorted with FCI_SCK
	
	input  FPG_GPCK,
	inout  [4:0]FPG_GPIO,
	
	input  CLK,
	input  BTNn,
	output LED_FPGn,

	output PWML,
	output PWMR
	
);
	
//************************************************************************************* PSRAM
	wire [15:0]ram0_dato;
	wire [15:0]ram0_dati;
	wire [22:0]ram0_addr;
	wire ram0_oe, ram0_we_lo, ram0_we_hi, ram0_ce;
	
	
	assign ram0_dato	= PSR_D;
	assign PSR_A		= ram0_addr[22:1];
	assign PSR_D		= ram0_ce & ram0_oe ? 16'hzzzz : ram0_dati;
	assign PSR_OEn		= !ram0_oe;
	assign PSR_WEn		= !(ram0_we_lo | ram0_we_hi);
	assign PSR_LBn		= !(ram0_oe | ram0_we_lo);
	assign PSR_UBn		= !(ram0_oe | ram0_we_hi);
	assign PSR_CEn		= !ram0_ce;
//************************************************************************************* BRAM

	wire [15:0]ram3_dato;
	wire [15:0]ram3_dati;
	wire [22:0]ram3_addr;
	wire ram3_oe, ram3_we_lo, ram3_we_hi, ram3_ce;
	
	assign ram3_dato	= {BRM_D[7:0], BRM_D[7:0]};
	assign BRM_D 		= ram3_ce & ram3_oe ? 8'hzz : ram3_dati[7:0];
	assign BRM_A		= ram3_addr[16:0];
	assign BRM_CE		= ram3_ce;
	assign BRM_OEn		= !ram3_oe;
	assign BRM_WEn		= !(ram3_we_lo | ram3_we_hi);
//************************************************************************************* audio
	wire snd_on;
	wire snd_clk;
	wire snd_next_sample;
	wire [8:0]snd_phase;
	wire signed[15:0]snd_r;
	wire signed[15:0]snd_l;
		
	audio_out_ds audio_out_inst(

		.clk(CLK),
		.snd_on(snd_on),
		.snd_clk(snd_clk),
		.snd_next_sample(snd_next_sample),
		.snd_phase(snd_phase),
		.snd_i_l(snd_l),
		.snd_i_r(snd_r),
		
		.snd_o_l(PWML),
		.snd_o_r(PWMR)
		
	);
//************************************************************************************* var
	wire led_r, led_g;
	assign LED_FPGn	= led_r | led_g ? 0 : 1'bz;
		
	
	wire [15:0]cpu_dati;
	wire [15:0]cpu_dato;
	assign MD_D 		= MD_DDIR == 0	? 16'hzzzz : cpu_dati;
	assign cpu_dato	= MD_D;
//*************************************************************************************
	
	mega_ed mega_ed_inst(

		.cpu_dati(cpu_dati),
		.cpu_dato(cpu_dato),
		.cpu_addr(MD_A),
		.as(MD_ASn),
		.cas(), 
		.ce_lo(MD_CELn), 
		.ce_hi(MD_CEHn),
		.clk50(CLK),
		.vclk(MD_VCLK),
		.eclk(0),
		.oe(MD_OEn),
		.rst(MD_SRSTFn),
		.we_lo(MD_WELn),
		.we_hi(MD_WEHn),
		
		.cart(MD_CART),
		.dtak(MD_DTAKn),
		.hrst(MD_HRSTFn),
		.sms(MD_SMS),
		
		.dat_dir(MD_DDIR), 
		.dat_oe(MD_DOEn),
		
		.spi_miso(FCI_MISO),
		.spi_mosi(FCI_MOSI), 
		.spi_sck(FCI_SCK),
		.spi_ss(FCI_IO[1]),
		
		.mcu_fifo_rxf(FCI_IO[2]), 
		.mcu_mode(FCI_IO[4]),
		.mcu_sync(FCI_IO[5]), 
		.mcu_rst(FCI_IO[6]),
		.mcu_mdp(FCI_IO[0]),
		.mcu_busy(FCI_IO[3]),
			
		.ram0_dato(ram0_dato),
		.ram0_dati(ram0_dati),
		.ram0_addr(ram0_addr),
		.ram0_oe(ram0_oe),
		.ram0_we_lo(ram0_we_lo),
		.ram0_we_hi(ram0_we_hi),
		.ram0_ce(ram0_ce),
		
		.ram3_dato(ram3_dato),
		.ram3_dati(ram3_dati),
		.ram3_addr(ram3_addr),
		.ram3_oe(ram3_oe),
		.ram3_we_lo(ram3_we_lo),
		.ram3_we_hi(ram3_we_hi),
		.ram3_ce(ram3_ce),
		
		.gpclk(FPG_GPCK),
		.gpio(FPG_GPIO),
		
		.snd_on(snd_on),
		.snd_clk(snd_clk),
		.snd_next_sample(snd_next_sample),
		.snd_phase(snd_phase),
		.snd_l(snd_l),
		.snd_r(snd_r),
		
		.mkey_oe(MKEY_ACT),
		.mkey_we(MKEY_SET), 
		.led_r(led_r),
		.led_g(led_g),
		
		.btn(!BTNn)

	);
	

endmodule
