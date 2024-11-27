


module top(
	
	inout  [15:0]MD_D,
	input  [23:1]MD_A,
	input  MD_ASn,
	input  MD_CASn,
	input  MD_CEHn,
	input  MD_CELn,
	input  MD_OEn,
	input  MD_WEHn,
	input  MD_WELn,
	input  MD_VCLK,
	input  MD_ECLK,
	input  MD_SRSTFn,
	output MD_CART,
	output MD_DTAKn,
	output MD_HRSTFn,
	output [3:0]MD_SMS,
	
	output MD_DDIR,
	output MD_DOEn,
	
	output MKEY_ACT,
	output MKEY_SET,
	
	output [21:0]PSR0_A,
	inout  [15:0]PSR0_D,
	output PSR0_OEn,
	output PSR0_WEn,
	output PSR0_LBn,
	output PSR0_UBn,
	output PSR0_CEn,
	
	output [21:0]PSR1_A,
	inout  [15:0]PSR1_D,
	output PSR1_OEn,
	output PSR1_WEn,
	output PSR1_LBn,
	output PSR1_UBn,
	output PSR1_CEn,
	
	output [17:0]SRM_A,
	inout  [15:0]SRM_D,
	output SRM_OEn,
	output SRM_WEn,
	output SRM_LBn,
	output SRM_UBn,
	output SRM_CEn,
	
	output [17:0]BRM_A,
	inout  [15:0]BRM_D,	
	output BRM_OEn,
	output BRM_WEn,
	output BRM_LBn,
	output BRM_UBn,
	
	inout  [9:0]FCI_IO,
	input  FCI_MOSI,
	input  FCI_SCK,
	output FCI_MISO,
	//input  DCLK,//shorted with FCI_SCK
	
	input  FPG_GPCK,
	inout  [4:0]FPG_GPIO,
	
	input  CLK,
	input  BTN,
	output LED_G,
	output LED_R,
	
	output DAC_MCLK, 
	output DAC_LRCK, 
	output DAC_SCLK, 
	output DAC_SDIN
	
);
	
//************************************************************************************* PSRAM0
	wire [15:0]ram0_dato;
	wire [15:0]ram0_dati;
	wire [22:0]ram0_addr;
	wire ram0_oe, ram0_we_lo, ram0_we_hi, ram0_ce;
	
	
	assign ram0_dato	= PSR0_D;
	assign PSR0_A		= ram0_addr[22:1];
	assign PSR0_D		= ram0_ce & ram0_oe ? 16'hzzzz : ram0_dati;
	assign PSR0_OEn	= !ram0_oe;
	assign PSR0_WEn	= !(ram0_we_lo | ram0_we_hi);
	assign PSR0_LBn	= !(ram0_oe    | ram0_we_lo);
	assign PSR0_UBn	= !(ram0_oe    | ram0_we_hi);
	assign PSR0_CEn	= !ram0_ce;
	
//************************************************************************************* PSRAM1	
	wire [15:0]ram1_dato;
	wire [15:0]ram1_dati;
	wire [22:0]ram1_addr;
	wire ram1_oe, ram1_we_lo, ram1_we_hi, ram1_ce;
	
	
	assign ram1_dato	= PSR1_D;
	assign PSR1_A		= ram1_addr[22:1];
	assign PSR1_D		= ram1_ce & ram1_oe ? 16'hzzzz : ram1_dati;
	assign PSR1_OEn	= !ram1_oe;
	assign PSR1_WEn	= !(ram1_we_lo | ram1_we_hi);
	assign PSR1_LBn	= !(ram1_oe    | ram1_we_lo);
	assign PSR1_UBn	= !(ram1_oe    | ram1_we_hi);
	assign PSR1_CEn	= !ram1_ce;
//************************************************************************************* SRAM
	wire [15:0]ram2_dato;
	wire [15:0]ram2_dati;
	wire [22:0]ram2_addr;
	wire ram2_oe, ram2_we_lo, ram2_we_hi, ram2_ce;
	
	
	assign ram2_dato	= SRM_D;
	assign SRM_A		= ram2_addr[22:1];
	assign SRM_D		= ram2_ce & ram2_oe ? 16'hzzzz : ram2_dati;
	assign SRM_OEn		= !ram2_oe;
	assign SRM_WEn		= !(ram2_we_lo | ram2_we_hi);
	assign SRM_LBn		= !(ram2_oe    | ram2_we_lo);
	assign SRM_UBn		= !(ram2_oe    | ram2_we_hi);
	assign SRM_CEn		= !ram2_ce;
//************************************************************************************* BRAM
	wire [15:0]ram3_dato;
	wire [15:0]ram3_dati;
	wire [22:0]ram3_addr;
	wire ram3_oe, ram3_we_lo, ram3_we_hi, ram3_ce;
	
	assign ram3_dato	= BRM_D;
	assign BRM_A		= ram3_addr[22:1];
	assign BRM_D		= ram3_ce & ram3_oe ? 16'hzzzz : ram3_dati;
	assign BRM_OEn		= !ram3_oe;
	assign BRM_WEn		= !(ram3_we_lo | ram3_we_hi);
	assign BRM_LBn		= !(ram3_oe    | ram3_we_lo);
	assign BRM_UBn		= !(ram3_oe    | ram3_we_hi);
//************************************************************************************* audio
	wire snd_on;
	wire snd_clk;
	wire snd_next_sample;
	wire [8:0]snd_phase;
	wire signed[15:0]snd_r;
	wire signed[15:0]snd_l;
	
	assign DAC_SCLK	= 1;
	
	audio_out_i2s audio_out_inst(

		.clk(CLK),
		.snd_on(snd_on),
		.snd_clk(snd_clk),
		.snd_next_sample(snd_next_sample),
		.snd_phase(snd_phase),
		.snd_i_l(snd_l),
		.snd_i_r(snd_r),
		
		
		.dac_mclk(DAC_MCLK),
		.dac_lrck(DAC_LRCK),
		.dac_sdin(DAC_SDIN)
	);
//************************************************************************************* var
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
		.cas(MD_CASn), 
		.ce_lo(MD_CELn), 
		.ce_hi(MD_CEHn),
		.clk50(CLK),
		.vclk(MD_VCLK),
		.eclk(MD_ECLK),
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
		
		.ram1_dato(ram1_dato),
		.ram1_dati(ram1_dati),
		.ram1_addr(ram1_addr),
		.ram1_oe(ram1_oe),
		.ram1_we_lo(ram1_we_lo),
		.ram1_we_hi(ram1_we_hi),
		.ram1_ce(ram1_ce),
		
		.ram2_dato(ram2_dato),
		.ram2_dati(ram2_dati),
		.ram2_addr(ram2_addr),
		.ram2_oe(ram2_oe),
		.ram2_we_lo(ram2_we_lo),
		.ram2_we_hi(ram2_we_hi),
		.ram2_ce(ram2_ce),
		
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
		.led_r(LED_R),
		.led_g(LED_G),
		
		.btn(BTN)

	);
	
endmodule
