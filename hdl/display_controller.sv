`timescale 1ns / 1ps

module display_controller(
    input logic         reset_in,
    input logic         clock_in,
    input logic [15:0]  frame_delay,

    input logic [7:0]   pkt_buf_in [1518 - 1:0], // ETH_MTU - 1
    input logic         pkt_buf_doorbell_in,

    output logic x_sclk,
    output logic x_mosi,
    output logic x_cs,
    output logic y_sclk,
    output logic y_mosi,
    output logic y_cs,

    output logic r_pwm,
    output logic g_pwm,
    output logic b_pwm,

    output logic frame_sync
    );

    // Number of bits to allocate for X, Y, R, G, B data
    parameter X_LENGTH = 16;
    parameter Y_LENGTH = 16;

    parameter B_LENGTH = 8;
    parameter G_LENGTH = 8;
    parameter R_LENGTH = 8;

    // BRAM framebuffer
    logic        bram_select; // 0 to read from 0 and write to 1, 1 to read from 1 and write to 0
    logic [14:0] bram_0_addr, bram_1_addr;
    logic [14:0] bram_0_max_addr, bram_1_max_addr;
    logic [63:0] bram_0_data_in, bram_1_data_in;
    logic [63:0] bram_0_data_out, bram_1_data_out;

    blk_mem_gen_0 bram0 (.addra(bram_0_addr),
                         .clka(clock_in),
                         .dina(bram_0_data_in),
                         .douta(bram_0_data_out),
                         .wea(bram_select),
                         .ena(1));

    blk_mem_gen_0 bram1 (.addra(bram_1_addr),
                        .clka(clock_in),
                        .dina(bram_1_data_in),
                        .douta(bram_1_data_out),
                        .wea(!bram_select),
                        .ena(1));

    // Data extraction from packet buffer
    logic [63:0] current_flattened_packet;
    assign current_flattened_packet = {pkt_buf_in[0], pkt_buf_in[1],
                                       pkt_buf_in[2], pkt_buf_in[3],
                                       pkt_buf_in[4], pkt_buf_in[5],
                                       pkt_buf_in[6], pkt_buf_in[7]};

    // SPI controllers
    logic x_start, y_start;
    logic x_busy, y_busy;
    logic [15:0] x, y;
    logic [7:0] r, g, b;

    spi x_spi_controller(
            .reset_in(reset_in),
            .clock_in(clock_in),
            .data_in(x),
            .data_length_in(X_LENGTH),
            .start_in(x_start),
            .busy_out(x_busy),

            .sclk_out(x_sclk),
            .mosi_out(x_mosi),
            .cs_out(x_cs));

    spi y_spi_controller(
            .reset_in(reset_in),
            .clock_in(clock_in),
            .data_in(y),
            .data_length_in(Y_LENGTH),
            .start_in(y_start),
            .busy_out(y_busy),

            .sclk_out(y_sclk),
            .mosi_out(y_mosi),
            .cs_out(y_cs));

    // PWM controllers

    pwm r_pwm_controller(
            .reset_in(reset_in),
            .clock_in(clock_in),
            .value(r),
            .pwm_out(r_pwm));

    pwm g_pwm_controller(
            .reset_in(reset_in),
            .clock_in(clock_in),
            .value(g),
            .pwm_out(g_pwm));

    pwm b_pwm_controller(
            .reset_in(reset_in),
            .clock_in(clock_in),
            .value(b),
            .pwm_out(b_pwm));

    // State Machine
    logic [18:0] frame_delay_counter;
    logic old_pkt_buf_doorbell; // Used to track when the packet doorbell changes

    always_ff @(posedge clock_in) begin
        if(reset_in) begin
            bram_select <= 0;

            bram_0_addr <= 0;
            bram_1_addr <= 0;
            bram_0_max_addr <= 0;
            bram_1_max_addr <= 0;
            bram_0_data_in <= 0;
            bram_1_data_in <= 0;

            old_pkt_buf_doorbell <= 0;

            frame_delay_counter <= 0;
            x_start <= 0;
            y_start <= 0;
            frame_sync <= 0;
        end else begin
            // state machine that takes data from the packet buffer and stashes it in BRAM

            if (pkt_buf_doorbell_in && !old_pkt_buf_doorbell) begin
                // load into BRAM
                if(bram_select) begin
                    bram_0_data_in <= current_flattened_packet;
                    bram_0_addr <= bram_0_addr + 1;
                    bram_0_max_addr <= bram_0_addr + 1;
                end else begin
                    bram_1_data_in <= current_flattened_packet;
                    bram_1_addr <= bram_1_addr + 1;
                    bram_1_max_addr <= bram_1_addr + 1;
                end

                // switch BRAM if we need to
                if (current_flattened_packet[63:56] == 8'h02) begin
                    if(bram_select) begin
                        bram_1_max_addr <= 0;
                        bram_1_addr <= 0;
                    end else begin
                        bram_0_max_addr <= 0;
                        bram_0_addr <= 0;
                    end
                    bram_select <= !bram_select;
                end
            end
            old_pkt_buf_doorbell <= pkt_buf_doorbell_in;

            // state machine that gets pulls data from the active BRAM and writes it to the display
            frame_delay_counter <= frame_delay_counter + 1;

            if(frame_delay_counter == frame_delay - 2) begin
                r = bram_select ? bram_1_data_out[7:0] : bram_0_data_out[7:0];
                g = bram_select ? bram_1_data_out[15:8] : bram_0_data_out[15:8];
                b = bram_select ? bram_1_data_out[23:16] : bram_0_data_out[23:16];
                y = bram_select ? bram_1_data_out[39:24] : bram_0_data_out[39:24];
                x = bram_select ? bram_1_data_out[55:40] : bram_0_data_out[55:40];

                x_start <= 1;
                y_start <= 1;
            end

            if(frame_delay_counter == frame_delay - 1) begin
                x_start <= 0;
                y_start <= 0;
                frame_sync <= ~frame_sync;
            end

            if(frame_delay_counter == frame_delay) begin
                frame_delay_counter <= 0;
                // update bram address, wrapping around if necessary
                if(!bram_select) begin
                    if(bram_0_addr == bram_0_max_addr) begin
                        bram_0_addr <= 0;
                    end else begin
                        bram_0_addr <= bram_0_addr + 1;
                    end
                end

                if(bram_select) begin
                    if(bram_1_addr == bram_1_max_addr) begin
                        bram_1_addr <= 0;
                    end else begin
                        bram_1_addr <= bram_1_addr + 1;
                    end
                end
            end
        end
    end
endmodule