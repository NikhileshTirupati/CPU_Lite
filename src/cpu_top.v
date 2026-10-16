module cpu_top #(
    parameter INIT_FILE = "prog.mem"
)(
    input  wire clk,
    input  wire mem_clk,
    input  wire rst_n,
    output wire halted
);

    // ============================================================
    // Core <-> memory interconnect
    // ============================================================
    wire [11:0] pc;
    wire [31:0] inst_if;

    wire        mem_read_mem;
    wire        mem_write_mem;
    wire [31:0] mem_addr_mem;
    wire [31:0] store_data_mem;
    wire [31:0] dmem_rdata;
    wire        mem_ready;

    // ============================================================
    // CPU core (IF/ID/EX/MEM/WB pipeline, hazard + forwarding)
    // ============================================================
    cpu_core u_core (
        .clk            (clk),
        .rst_n          (rst_n),

        .pc             (pc),
        .inst_if        (inst_if),

        .mem_read_mem   (mem_read_mem),
        .mem_write_mem  (mem_write_mem),
        .mem_addr_mem   (mem_addr_mem),
        .store_data_mem (store_data_mem),
        .dmem_rdata     (dmem_rdata),
        .mem_ready      (mem_ready),

        .halted         (halted)
    );

    // ============================================================
    // Instruction memory
    // ============================================================
    program_memory #(
        .INIT_FILE(INIT_FILE)
    ) u_imem (
        .addr (pc),
        .inst (inst_if)
    );

    // ============================================================
    // Data memory system (L1 cache + CDC + data memory)
    // ============================================================
    memory_system u_mem (
        .clk       (clk),
        .mem_clk   (mem_clk),
        .rst_n     (rst_n),

        .req_read  (mem_read_mem),
        .req_write (mem_write_mem),

        .addr      (mem_addr_mem[13:0]),
        .wdata     (store_data_mem),

        .rdata     (dmem_rdata),
        .ready     (mem_ready)
    );

endmodule