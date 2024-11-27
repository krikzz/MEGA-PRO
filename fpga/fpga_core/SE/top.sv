

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
	inout  MD_SRSTFn,
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
	
	input  FPG_GPCK,
	inout  [4:0]FPG_GPIO,
	
	input  CLK,
	input  BTNn,
	output LED_FPGn,

	output PWML,
	output PWMR
	
);
	
	
//************************************************************************************* unused signals
	assign FCI_IO[2] 		= 1;//mcu fifo interface (unused, should be 1)
	assign FCI_IO[4] 		= 1;//mcu master mode (unused, should be 1)
	
	assign MD_SMS			= 4'bzzzz;
	assign MD_CART			= 0;
	assign MD_DTAKn		= 1'bz;
	
	assign MKEY_ACT		= 1;
	assign MD_SRSTFn 		= 1'bz;
	assign LED_FPGn		= 1'bz;
//************************************************************************************* bus controll
	assign MD_DDIR			= !MD_CELn & !MD_OEn ? 1 : 0;
	assign MD_DOEn			= 0;
	assign MD_D				= !MD_DDIR ? 16'hzzzz : !PSR_CEn ? PSR_D[15:0] : {BRM_D[7:0], BRM_D[7:0]};
//************************************************************************************* ROM	
	assign PSR_A[20:0]	= MD_A[21:1];
	assign PSR_D[15:0]	= 16'hzzzz;
	assign PSR_LBn			= 0;
	assign PSR_UBn			= 0;
	assign PSR_OEn			= MD_OEn;
	assign PSR_WEn			= 1;
	assign PSR_CEn			= !(!MD_CELn & (!MD_A[21] | !ram_on));
//************************************************************************************* BRAM		
	assign BRM_A			= MD_A[17:1];
	assign BRM_D			= BRM_CE & !MD_OEn ? 8'hzz : MD_D[7:0];
	assign BRM_OEn			= MD_OEn;
	assign BRM_WEn			= MD_WELn;
	assign BRM_CE 			= !MD_CELn & MD_A[21] & ram_on;
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
	assign FCI_IO[6] 		= !BTNn   ? 1'b1 : 1'b0;//return to menu
	assign MD_HRSTFn		= rst_act ? 1'b0 : 1'bz;//console reset
	
	wire rst_act;
	
	hard_reset(

		.clk(CLK),
		.rst_req(!BTNn),
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

