


module irq_ctrl(
	input rst, clk_asic, sub_sync, 
	input [6:1]ireq,
	input [6:1]imsk,
	input [2:0]cpu_fc,
	output reg [2:0]cpu_ipl,
	output reg cpu_vpa,
	input [3:1]cpu_addr,
	input cpu_oe,
	output [6:1]irq_pend_out
);
	
	initial cpu_ipl[2:0] = 3'b111;
	
	assign irq_pend_out[6:1] = irq_pend;
	
	wire [6:1]irq_pend;
	wire [6:1]irq_ack;
	wire [6:1]ireq_on = ireq[6:1] & imsk[6:1];
	wire cpu_space = !cpu_oe & cpu_fc[1:0] == 2'b11;
	
	assign irq_ack[1] = cpu_space & cpu_addr[3:1] == 1;
	assign irq_ack[2] = cpu_space & cpu_addr[3:1] == 2;
	assign irq_ack[3] = cpu_space & cpu_addr[3:1] == 3;
	assign irq_ack[4] = cpu_space & cpu_addr[3:1] == 4;
	assign irq_ack[5] = cpu_space & cpu_addr[3:1] == 5;
	assign irq_ack[6] = cpu_space & cpu_addr[3:1] == 6;
	
	irq_request req1(ireq_on[1], irq_pend[1], irq_ack[1], clk_asic, sub_sync, rst);
	irq_request req2(ireq_on[2], irq_pend[2], irq_ack[2], clk_asic, sub_sync, rst);
	irq_request req3(ireq_on[3], irq_pend[3], irq_ack[3], clk_asic, sub_sync, rst);
	irq_request req4(ireq_on[4], irq_pend[4], irq_ack[4], clk_asic, sub_sync, rst);
	irq_request req5(ireq_on[5], irq_pend[5], irq_ack[5], clk_asic, sub_sync, rst);
	irq_request req6(ireq_on[6], irq_pend[6], irq_ack[6], clk_asic, sub_sync, rst);
	
	always @(negedge clk_asic)
	if(sub_sync)
	begin
	
		cpu_vpa <= !cpu_space;
		
		if(irq_pend[6])cpu_ipl <= (6 ^ 3'b111);
			else
		if(irq_pend[5])cpu_ipl <= (5 ^ 3'b111);
			else
		if(irq_pend[4])cpu_ipl <= (4 ^ 3'b111);
			else
		if(irq_pend[3])cpu_ipl <= (3 ^ 3'b111);
			else
		if(irq_pend[2])cpu_ipl <= (2 ^ 3'b111);
			else
		if(irq_pend[1])cpu_ipl <= (1 ^ 3'b111);
			else
		cpu_ipl <= 3'b111;
		
	end
	


endmodule



module irq_request(

	input req_in,
	output reg req_out,
	input ack,
	
	input clk,
	input sub_sync,
	input rst
);
	
	wire req_edge = req_in_st[1:0] == 2'b01;
	reg [1:0]req_in_st;
	
	always @(negedge clk)
	if(rst)
	begin
		req_in_st <= 0;
		req_out <= 0;
	end
		else
	begin
	
		req_in_st[1:0] <= {req_in_st[0], req_in};
		
		if(ack)req_out <= 0;
			else
		if(req_edge)req_out <= 1;
	end
	
endmodule

