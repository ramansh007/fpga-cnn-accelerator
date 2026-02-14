`timescale 1ns / 1ps

module conv3x3_serial #(
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32
)(
    input  wire clk,
    input  wire rst_n,
    input  wire start,

    input  wire signed [DATA_WIDTH-1:0] a0,a1,a2,
    input  wire signed [DATA_WIDTH-1:0] a3,a4,a5,
    input  wire signed [DATA_WIDTH-1:0] a6,a7,a8,

    input  wire signed [DATA_WIDTH-1:0] w0,w1,w2,
    input  wire signed [DATA_WIDTH-1:0] w3,w4,w5,
    input  wire signed [DATA_WIDTH-1:0] w6,w7,w8,

    output reg  signed [ACC_WIDTH-1:0] result,
    output reg  done
);

    // FSM states
    localparam IDLE  = 3'd0,
               CLEAR = 3'd1,
               LOAD  = 3'd2,
               BUSY  = 3'd3,
               DONE  = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] idx;

    // MAC control
    reg clear;
    reg compute;
    reg signed [DATA_WIDTH-1:0] a_sel, b_sel;
    wire signed [ACC_WIDTH-1:0] acc;

    mac_simple #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH)
    ) mac_u (
        .clk(clk),
        .clear(clear),
        .compute(compute),
        .a(a_sel),
        .b(b_sel),
        .acc(acc)
    );

    // FSM 
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // FSM next-state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE  : if (start) next_state = CLEAR;
            CLEAR : next_state = LOAD;
            LOAD  : next_state = BUSY;
            BUSY  : if (idx == 8) next_state = DONE;
            DONE  : next_state = IDLE;
            default : next_state = IDLE;
        endcase
    end

    // FSM outputs and control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idx     <= 0;
            clear   <= 0;
            compute <= 0;
            done    <= 0;
            result  <= 0;
        end else begin
            clear   <= 0;
            compute <= 0;
            done    <= 0;

            case (state)
                IDLE: begin
                    idx <= 0;
                end

                CLEAR: begin
                    clear <= 1;
                    idx   <= 0;
                end

                // First MAC: uses a0,w0 — no idx increment
                LOAD: begin
                    compute <= 1;
                end

                // Remaining MACs: a1..a8
                BUSY: begin
                    compute <= 1;
                    if (idx < 8)
                        idx <= idx + 1;
                end

                DONE: begin
                    clear <= 1;
                    result <= acc;
                    done   <= 1;
                end
            endcase
        end
    end

    always @(*) begin
        case (idx)
            0: begin a_sel = a0; b_sel = w0; end
            1: begin a_sel = a1; b_sel = w1; end
            2: begin a_sel = a2; b_sel = w2; end
            3: begin a_sel = a3; b_sel = w3; end
            4: begin a_sel = a4; b_sel = w4; end
            5: begin a_sel = a5; b_sel = w5; end
            6: begin a_sel = a6; b_sel = w6; end
            7: begin a_sel = a7; b_sel = w7; end
            8: begin a_sel = a8; b_sel = w8; end
            default: begin a_sel = 0; b_sel = 0; end
        endcase
    end

endmodule
