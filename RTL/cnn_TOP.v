`timescale 1ns / 1ps

module cnn_TOP #(
    parameter IMG_WIDTH  = 28,
    parameter IMG_HEIGHT = 28,
    parameter DATA_WIDTH = 8,
    parameter ACC_WIDTH  = 32,
    parameter NUM_FILTERS = 8
)(
    input  wire                       clk,
    input  wire                       rst_n,
    input  wire                       start,
    output wire                       done,       
    input  wire [DATA_WIDTH-1:0]      pixel_data,
    output wire                       axis_ready, // output Flow Control
    output wire                       output_valid, 
    output wire signed [ACC_WIDTH-1:0] result
);

    // =========================================================================
    // Internal Wires / Interconnects
    // =========================================================================
    // Controller Signals
    wire ctrl_addr_clear, ctrl_conv_start, ctrl_ram_we;
    wire ctrl_inc_filter, ctrl_inc_window, ctrl_pool_start;
    wire ctrl_is_streaming, ctrl_is_shifting;
    wire status_win_valid, status_conv_done, status_last_filter;
    wire status_done_all_win, status_pool_done;

    // Data Signals
    wire [7:0] w0, w1, w2, w3, w4, w5, w6, w7, w8;
    wire [(9*DATA_WIDTH)-1:0] rom_data_flat;
    wire signed [ACC_WIDTH-1:0] conv_result, relu_out;
    wire [$clog2(NUM_FILTERS)-1:0] filter_cnt;
    wire [31:0] write_addr, pool_read_addr, ram_addr_mux;
    wire [ACC_WIDTH-1:0] ram_dout;
    wire pixel_accept_enable;

    // =========================================================================
    // 1. Main Controller (The Brain)
    // =========================================================================
    cnn_controller main_fsm (
        .clk(clk), .rst_n(rst_n), .start(start),
        
        // Status Inputs
        .win_valid(status_win_valid),
        .conv_done(status_conv_done),
        .last_filter(status_last_filter),
        .done_all_windows(status_done_all_win),
        .pool_done(status_pool_done),
        
        // Control Outputs
        .addr_clear(ctrl_addr_clear),
        .conv_start(ctrl_conv_start),
        .ram_we(ctrl_ram_we),
        .inc_filter(ctrl_inc_filter),
        .inc_window(ctrl_inc_window),
        .pool_start(ctrl_pool_start),
        .is_streaming(ctrl_is_streaming),
        .is_shifting(ctrl_is_shifting)
    );

    // =========================================================================
    // 2. Sliding Window Unit (Input Buffer)
    // =========================================================================
    assign pixel_accept_enable = ctrl_is_shifting || (ctrl_is_streaming && !status_win_valid);
    assign axis_ready = pixel_accept_enable;

    sliding_window_3x3 #(.IMG_WIDTH(IMG_WIDTH)) win_mod (
        .clk(clk), .rst_n(rst_n), 
        .pixel_valid(pixel_accept_enable), 
        .pixel_in(pixel_data),
        .win_valid(status_win_valid), 
        .w0(w0), .w1(w1), .w2(w2), .w3(w3), .w4(w4), .w5(w5), .w6(w6), .w7(w7), .w8(w8)
    );

    // =========================================================================
    // 3. Processing Core (Weights + Conv + ReLU)
    // =========================================================================
    weight_rom_2 #(.NUM_FILTERS(NUM_FILTERS), .DATA_WIDTH(DATA_WIDTH)) w_rom (
        .clk(clk),
        .addr(filter_cnt),
        .data_out(rom_data_flat)
    );

    conv3x3_serial #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH)) conv_mod (
        .clk(clk), .rst_n(rst_n), .start(ctrl_conv_start),
        .a0(w0), .a1(w1), .a2(w2), .a3(w3), .a4(w4), .a5(w5), .a6(w6), .a7(w7), .a8(w8),
        .w0(rom_data_flat[71:64]), .w1(rom_data_flat[63:56]), .w2(rom_data_flat[55:48]), 
        .w3(rom_data_flat[47:40]), .w4(rom_data_flat[39:32]), .w5(rom_data_flat[31:24]), 
        .w6(rom_data_flat[23:16]), .w7(rom_data_flat[15:8]), .w8(rom_data_flat[7:0]),
        .result(conv_result), .done(status_conv_done)
    );

    relu #(.WIDTH(ACC_WIDTH)) relu_mod (.din(conv_result), .dout(relu_out));

    // =========================================================================
    // 4. Address Generator (Coordinate Logic)
    // =========================================================================
    address_generator #(.IMG_HEIGHT(IMG_HEIGHT), .IMG_WIDTH(IMG_WIDTH), .NUM_FILTERS(NUM_FILTERS)) addr_gen (
        .clk(clk), .rst_n(rst_n), 
        .clear(ctrl_addr_clear),
        .inc_filter(ctrl_inc_filter), 
        .inc_window(ctrl_inc_window),
        .filter_cnt(filter_cnt), 
        .write_addr(write_addr), 
        .last_filter(status_last_filter),
        .done_all(status_done_all_win)
    );

    // =========================================================================
    // 5. Feature Map Buffer (BRAM)
    // =========================================================================
    // If Pooling is active (pool_start triggered), use pool address. Else use write address.
    assign ram_addr_mux = (ctrl_ram_we) ? write_addr : pool_read_addr;

    simple_ram #(.WIDTH(ACC_WIDTH), .DEPTH(NUM_FILTERS*(IMG_HEIGHT-2)*(IMG_WIDTH-2))) block_ram_inst (
        .clk(clk),
        .we(ctrl_ram_we), 
        .addr(ram_addr_mux), 
        .din(relu_out), 
        .dout(ram_dout)
    );

    // =========================================================================
    // 6. Max Pooling Unit 
    // =========================================================================
    max_pooling_unit #(.DATA_WIDTH(ACC_WIDTH), .IMG_HEIGHT(IMG_HEIGHT), .IMG_WIDTH(IMG_WIDTH), .NUM_FILTERS(NUM_FILTERS)) pool_inst (
        .clk(clk), .rst_n(rst_n), 
        .start(ctrl_pool_start), 
        .done(status_pool_done),
        .ram_addr(pool_read_addr), 
        .ram_data(ram_dout), 
        .valid_out(output_valid), 
        .data_out(result)
    );
    
    // Final Done Signal
    assign done = status_pool_done;

endmodule