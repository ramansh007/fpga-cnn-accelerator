`timescale 1ns / 1ps

module max_pooling_unit #(
    parameter DATA_WIDTH = 32,
    parameter IMG_HEIGHT = 28,
    parameter IMG_WIDTH  = 28,
    parameter NUM_FILTERS = 8
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   start,       // Trigger to start pooling
    output reg                    done,        // High when all pooling is finished
    
    output reg  [31:0]            ram_addr,    
    input  wire [DATA_WIDTH-1:0]  ram_data,    
    
    output reg                    valid_out,
    output reg [DATA_WIDTH-1:0]   data_out
);

    // Geometry Parameters
    localparam OUT_H = IMG_HEIGHT - 2;
    localparam OUT_W = IMG_WIDTH - 2;
    localparam TOTAL_WINDOWS = OUT_H * OUT_W;
    localparam RAM_DEPTH = NUM_FILTERS * OUT_H * OUT_W;
    
    localparam POOL_H = OUT_H / 2;
    localparam POOL_W = OUT_W / 2;

    // Registers
    reg [$clog2(NUM_FILTERS)-1:0] pool_f;
    reg [$clog2(POOL_H)-1:0]      pool_r;
    reg [$clog2(POOL_W)-1:0]      pool_c;
    reg signed [DATA_WIDTH-1:0]   val0, val1, val2, val3;
    reg signed [DATA_WIDTH-1:0]   max_temp;

    // Address Helper
    function [$clog2(RAM_DEPTH)-1:0] get_addr;
        input integer f, r, c;
        begin
            get_addr = (f * TOTAL_WINDOWS) + (r * OUT_W) + c;
        end
    endfunction

    // FSM
    localparam IDLE       = 4'd0,
               FETCH_INIT = 4'd1,
               FETCH_0    = 4'd2,
               WAIT_0     = 4'd3,
               FETCH_1    = 4'd4,
               WAIT_1     = 4'd5,
               FETCH_2    = 4'd6,
               WAIT_2     = 4'd7,
               FETCH_3    = 4'd8,
               WAIT_3     = 4'd9,
               COMPARE    = 4'd10;

    reg [3:0] state;

    always @(posedge clk ) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            valid_out <= 0;
            pool_f <= 0; pool_r <= 0; pool_c <= 0;
        end else begin
            valid_out <= 0;
            done <= 0;

            case (state)
                IDLE: begin
                    if (start) begin
                        pool_f <= 0; pool_r <= 0; pool_c <= 0;
                        state <= FETCH_INIT;
                    end
                end

                FETCH_INIT: begin
                    ram_addr <= get_addr(pool_f, pool_r*2, pool_c*2);
                    state <= WAIT_0;
                end
                
                // Pipeline for reading val0
                WAIT_0: state <= FETCH_1;
                FETCH_1: begin
                    val0 <= ram_data;
                    ram_addr <= get_addr(pool_f, pool_r*2, pool_c*2 + 1);
                    state <= WAIT_1;
                end
                
                // Pipeline for reading val1
                WAIT_1: state <= FETCH_2;
                FETCH_2: begin
                    val1 <= ram_data;
                    ram_addr <= get_addr(pool_f, pool_r*2 + 1, pool_c*2);
                    state <= WAIT_2;
                end
                
                // Pipeline for reading val2
                WAIT_2: state <= FETCH_3;
                FETCH_3: begin
                    val2 <= ram_data;
                    ram_addr <= get_addr(pool_f, pool_r*2 + 1, pool_c*2 + 1);
                    state <= WAIT_3;
                end
                
                // Read val3 and Compare
                WAIT_3: state <= COMPARE;
                COMPARE: begin
                    val3 <= ram_data;
                    
                    // Max Calculation
                    max_temp = (val0 > val1) ? val0 : val1;
                    if (val2 > max_temp) max_temp = val2;
                    if (ram_data > max_temp) max_temp = ram_data; // ram_data is val3 here
                    
                    data_out  <= max_temp;
                    valid_out <= 1;

                    // Loop Logic
                    if (pool_c == POOL_W - 1) begin
                        pool_c <= 0;
                        if (pool_r == POOL_H - 1) begin
                            pool_r <= 0;
                            if (pool_f == NUM_FILTERS - 1) begin
                                done <= 1;
                                state <= IDLE;
                            end else begin
                                pool_f <= pool_f + 1;
                                state <= FETCH_0; 
                            end
                        end else begin
                            pool_r <= pool_r + 1;
                            state <= FETCH_0;
                        end
                    end else begin
                        pool_c <= pool_c + 1;
                        state <= FETCH_0;
                    end
                end
                
                FETCH_0: begin
                    ram_addr <= get_addr(pool_f, pool_r*2, pool_c*2);
                    state <= WAIT_0;
                end
            endcase
        end
    end
endmodule