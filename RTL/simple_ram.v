`timescale 1ns / 1ps
module simple_ram #(
    parameter WIDTH = 32, 
    parameter DEPTH = 5408
)(
    input wire clk,
    input wire we,
    input wire [$clog2(DEPTH)-1:0] addr,
    input wire [WIDTH-1:0] din,
    output reg [WIDTH-1:0] dout
);
    reg [WIDTH-1:0] ram [0:DEPTH-1];

    always @(posedge clk) begin
        if (we) 
            ram[addr] <= din;
        dout <= ram[addr];
    end
endmodule