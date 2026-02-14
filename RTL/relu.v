`timescale 1ns / 1ps

module relu #(
    parameter WIDTH = 32
)(
    input  wire signed [WIDTH-1:0] din,
    output wire signed [WIDTH-1:0] dout
);
    assign dout = (din[WIDTH-1]) ? {WIDTH{1'b0}} : din;
    
endmodule
