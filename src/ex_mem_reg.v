module ex_mem_reg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,

    // ============================================================
    // Data/control inputs from EX
    // ============================================================
    input  wire [31:0] alu_result_in,
    input  wire [31:0] mem_addr_in,
    input  wire [31:0] store_data_in,
    input  wire [3:0]  rd_in,

    input  wire        reg_write_in,
    input  wire        mem_read_in,
    input  wire        mem_write_in,

    // ============================================================
    // Outputs to MEM
    // ============================================================
    output reg [31:0]  alu_result_mem,
    output reg [31:0]  mem_addr_mem,
    output reg [31:0]  store_data_mem,
    output reg [3:0]   rd_mem,

    output reg         reg_write_mem,
    output reg         mem_read_mem,
    output reg         mem_write_mem
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alu_result_mem <= 32'd0;
            mem_addr_mem   <= 32'd0;
            store_data_mem <= 32'd0;
            rd_mem         <= 4'd0;

            reg_write_mem  <= 1'b0;
            mem_read_mem   <= 1'b0;
            mem_write_mem  <= 1'b0;
        end
        else if (en) begin
            alu_result_mem <= alu_result_in;
            mem_addr_mem   <= mem_addr_in;
            store_data_mem <= store_data_in;
            rd_mem         <= rd_in;

            reg_write_mem  <= reg_write_in;
            mem_read_mem   <= mem_read_in;
            mem_write_mem  <= mem_write_in;
        end
    end

endmodule