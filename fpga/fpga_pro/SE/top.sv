
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

//************************************************************************************* unused signals
	assign FCI_IO[2] 		= 1;//mcu fifo interface (unused, should be 1)
	assign FCI_IO[4] 		= 1;//mcu master mode (unused, should be 1)
	
	assign MD_SMS			= 4'bzzzz;
	assign MD_CART			= 0;
	assign MD_DTAKn		= 1'bz;
	
	assign MKEY_ACT		= 1;
	assign LED_G			= 1'bz;
	assign LED_R			= 1'bz;
	
	assign PSR1_A			= 0;
	assign PSR1_D			= 0;
	assign PSR1_CEn		= 1;
	assign SRM_A			= 0;
	assign SRM_D			= 0;
	assign SRM_CEn			= 1;
//************************************************************************************* bus controll
	assign MD_DDIR			= !MD_CELn & !MD_OEn ? 1 : 0;
	assign MD_DOEn			= 0;
	assign MD_D				= !MD_DDIR ? 16'hzzzz : !PSR0_CEn ? PSR0_D[15:0] : {BRM_D[7:0], BRM_D[7:0]};
//************************************************************************************* ROM	
	assign PSR0_A[20:0]	= MD_A[21:1];
	assign PSR0_D[15:0]	= 16'hzzzz;
	assign PSR0_LBn		= 0;
	assign PSR0_UBn		= 0;
	assign PSR0_OEn		= MD_OEn;
	assign PSR0_WEn		= 1;
	assign PSR0_CEn		= !(!MD_CELn & (!MD_A[21] | !ram_on));
//************************************************************************************* BRAM		
	assign BRM_A			= MD_A[18:1];
	assign BRM_D			= BRM_CE & !MD_OEn ? 16'hzzzz : MD_D[15:0];
	assign BRM_OEn			= MD_OEn;
	assign BRM_WEn			= !(!MD_WELn | !MD_WEHn);
	wire   BRM_CE 			= !MD_CELn & MD_A[21] & ram_on;
	assign BRM_LBn			= !(BRM_CE & (!MD_OEn | !MD_WELn));
	assign BRM_UBn			= !(BRM_CE & (!MD_OEn | !MD_WEHn));
//************************************************************************************* mapper controll registers
	wire tim_we 			= !MD_WELn & !MD_ASn & {MD_A[23:8], 8'd0} == 24'hA13000;
	
	reg MD_SRSTFn_st;
	reg [2:0]tim_we_st;
	reg ram_on;
	
	always @(posedge CLK)
	begin
		
		MD_SRSTFn_st		<= MD_SRSTFn;
		tim_we_st[2:0] 	<= {tim_we_st[1:0], tim_we};
		
		
		if(!MD_SRSTFn_st)
		begin
			ram_on 			<= 0;
		end
			else
		if(tim_we_st[2:0] == 3'b011)
		begin
			ram_on 			<= MD_D[0];//switching between rom and ram in upper area
		end
		
	end
//************************************************************************************* reset controller	
	assign FCI_IO[6] 		= BTN     ? 1'b1 : 1'b0;//return to menu
	assign MD_HRSTFn		= rst_act ? 1'b0 : 1'bz;//console reset
	
	wire rst_act;
	
	hard_reset(

		.clk(CLK),
		.rst_req(BTN),
		.rst_act(rst_act)
	);
		
endmodule


module hard_reset(

	input  clk,
	input  rst_req,
	output rst_act
);
	
	assign rst_act	= rst_ctr != 1;
	
	reg [2:0]rst_req_st;
	reg [23:0]rst_ctr;	
	
	
	always @(negedge clk)
	begin
		
		rst_req_st[1:0]	<= {rst_req_st[1:0], rst_req};
		
		if(rst_req_st == 'b001)
		begin
			rst_ctr 			<= 0;
		end
			else
		if(rst_act)
		begin
			rst_ctr 			<= rst_ctr - 1;
		end
		
	end

endmodule

