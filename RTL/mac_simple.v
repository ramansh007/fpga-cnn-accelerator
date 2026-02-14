`timescale 1ns / 1ps

module mac_simple #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input  wire                         clk,
    input  wire                         clear,     
    input  wire                         compute,   

    input  wire signed [DATA_WIDTH-1:0] a,
    input  wire signed [DATA_WIDTH-1:0] b,

    output reg  signed [ACC_WIDTH-1:0]  acc
);

    wire signed [(2*DATA_WIDTH)-1:0] mult;
    assign mult = a * b;

    always @(posedge clk) begin
        if (clear)
            acc <= 0;
        else if (compute)
            acc <= acc + mult;
        else
            acc <= acc;   
    end

endmodule
