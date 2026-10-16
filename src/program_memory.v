module program_memory #(
	parameter ADDR_WIDTH = 12,
	parameter INST_WIDTH = 32,
	parameter DEPTH      = 4096,
	parameter INIT_FILE  = "prog.hex"
)(
	input  wire [ADDR_WIDTH-1:0] addr,
	output wire [INST_WIDTH-1:0] inst
);
	reg [INST_WIDTH-1:0] mem [0:DEPTH-1];
	integer i;
	initial begin
		for (i = 0; i < DEPTH; i = i + 1) mem[i] = 0;
		$readmemh(INIT_FILE, mem);
	end
	assign inst = mem[addr];
endmodule