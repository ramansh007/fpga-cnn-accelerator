`timescale 1ns / 1ps

module weight_rom_2 #(
    parameter NUM_FILTERS = 8,
    parameter DATA_WIDTH = 8
)(
    input wire clk, 
    input wire [$clog2(NUM_FILTERS)-1:0] addr,
    output reg [(9*DATA_WIDTH)-1:0] data_out 
);

    // 72-bit wide ROM
    (* rom_style = "distributed" *)
    reg [(9*DATA_WIDTH)-1:0] rom [0:NUM_FILTERS-1];

    // Use Absolute Address
    initial begin
        $readmemh("export/weights.mem", rom);
    end

    // SYNCHRONOUS READ (Clocked)
    always @(posedge clk) begin
        data_out <= rom[addr];
    end

endmodule