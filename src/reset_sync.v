module reset_sync (
	input  wire clk,
	input  wire arst_n,
	output wire rst_n            // asserts async, releases synchronously
);
	reg [1:0] q;
	always @(posedge clk or negedge arst_n)
		if (!arst_n) q <= 2'b00;
		else         q <= {q[0], 1'b1};
	assign rst_n = q[1];
endmodule