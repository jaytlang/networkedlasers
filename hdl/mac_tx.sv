`timescale 1ns / 1ps

module mac_tx(
    input logic         clk,
    input logic         reset,

    input logic         axi_valid,
    input logic[1:0]    axi_din,
    output logic        axi_ready,

    output logic        phy_txen,
    output logic[1:0]   phy_txd
    );

    /* All parameters first */
    parameter ST_IDLE           = 3'h0;
    parameter ST_PREAMBLE       = 3'h1;
    parameter ST_DATA           = 3'h2;
    parameter ST_PAD            = 3'h3;
    parameter ST_VERIFY         = 3'h4;
    parameter ST_IFRAME_GAP     = 3'h5;

    parameter PREAMBLE_DIBITS   = 32;
    parameter MIN_DATA_DIBITS   = 184;
    parameter CRC_DIBITS        = 16;
    parameter IFG_PERIOD        = 48;

    /* All logics here */
    logic[31:0] counter;
    logic[2:0]  state;
    logic       is_calculation_cycle;
    logic       is_valid_cycle;
    logic       soft_reset;

    logic[31:0] cumulative_crc;
    logic[1:0]  stepwise_crc;

    /* All preliminary assignments here */

    /* All submodules here */
    crc32_bzip2     tx_crc(.clk(clk),
                           .reset(reset),
                           .d(axi_din),
                           .d_valid(is_valid_cycle),
                           .calc(is_calculation_cycle),
                           .init(soft_reset),
                           .crc_reg(cumulative_crc),
                           .crc(stepwise_crc));
    /*
    Suggested ILA configuration:
    tx_ila          tila(.clk(clk),
                         .probe0(axi_din),
                         .probe1(state),
                         .probe2(phy_txd),
                         .probe3(axi_valid),
                         .probe4(phy_txen),
                         .probe5(stepwise_crc),
                         .probe6(counter));
    */

    /* All clocked logic here */
    always_ff @(posedge clk) begin
        if(reset == 1'b1) begin
            axi_ready <= 1'b0;
            phy_txen <= 1'b0;
            phy_txd <= 2'b0;

            counter <= 32'd1;
            state <= ST_IDLE;
            is_calculation_cycle <= 1'b0;
            is_valid_cycle <= 1'b0;
            soft_reset <= 1'b0;

        end else begin
            if(state == ST_IDLE) begin
                if(axi_valid == 1'b1) begin
                    state <= ST_PREAMBLE;
                end else begin
                    state <= ST_IDLE;
                end

                counter <= 32'd1;
                axi_ready <= 1'b0;
                phy_txen <= 1'b0;
                phy_txd <= 2'b0;

                is_calculation_cycle <= 1'b0;
                is_valid_cycle <= 1'b0;
                soft_reset <= 1'b1;

            end else if(state == ST_PREAMBLE) begin
                if(counter == PREAMBLE_DIBITS) begin
                    phy_txd <= 2'b11;
                    counter <= 32'd0;
                    state <= ST_DATA;
                    soft_reset <= 1'b0;
                    axi_ready <= 1'b1;
                    is_calculation_cycle <= 1'b1;
                    is_valid_cycle <= 1'b1;
                end else begin
                    phy_txd <= 2'b01;
                    counter <= counter + 1;
                    state <= ST_PREAMBLE;
                    soft_reset <= 1'b1;
                    axi_ready <= 1'b0;
                    is_calculation_cycle <= 1'b0;
                    is_valid_cycle <= 1'b0;
                end

                phy_txen <= 1'b1;

            end else if(state == ST_DATA) begin
                if(axi_valid == 1'b0) begin

                    if(counter < MIN_DATA_DIBITS) begin
                        state <= ST_PAD;
                        phy_txd <= 2'b00;
                        counter <= counter + 1;
                        is_calculation_cycle <= 1'b1;
                    end else begin

                        state <= ST_VERIFY;
                        phy_txd <= stepwise_crc;
                        counter <= 32'd1;
                        is_calculation_cycle <= 1'b0;
                    end

                    axi_ready <= 1'b0;

                end else begin
                    state <= ST_DATA;
                    phy_txd <= axi_din;
                    counter <= counter + 1;
                    is_calculation_cycle <= 1'b1;
                    axi_ready <= 1'b1;
                end
                is_valid_cycle <= 1'b1;
                phy_txen <= 1'b1;
                soft_reset <= 1'b0;


            end else if(state == ST_PAD) begin
                if(counter < MIN_DATA_DIBITS) begin
                    phy_txd <= 2'b00;
                    counter <= counter + 1;
                    state <= ST_PAD;
                    is_calculation_cycle <= 1'b1;
                end else begin
                    phy_txd <= stepwise_crc;
                    counter <= 32'd1;
                    state <= ST_VERIFY;
                    is_calculation_cycle <= 1'b0;
                end

                is_valid_cycle <= 1'b1;
                axi_ready <= 1'b0;
                phy_txen <= 1'b1;
                soft_reset <= 1'b0;


            end else if(state == ST_VERIFY) begin
                if(counter < CRC_DIBITS) begin
                    phy_txen <= 1'b1;
                    phy_txd <= stepwise_crc;
                    counter <= counter + 1;
                    state <= ST_VERIFY;
                    soft_reset <= 1'b0;
                    is_valid_cycle <= 1'b1;
                end else begin
                    phy_txen <= 1'b1;
                    phy_txd <= stepwise_crc;
                    counter <= 32'd1;
                    state <= ST_IFRAME_GAP;
                    soft_reset <= 1'b1;
                    is_valid_cycle <= 1'b0;
                end

                axi_ready <= 1'b0;
                is_calculation_cycle <= 1'b0;

            end else if(state == ST_IFRAME_GAP) begin
                if(counter == IFG_PERIOD) begin
                    counter <= 32'd1;
                    state <= ST_IDLE;
                end else begin
                    counter <= counter + 1;
                    state <= ST_IFRAME_GAP;
                end

                axi_ready <= 1'b0;
                phy_txen <= 1'b0;
                phy_txd <= 2'b00;
                is_calculation_cycle <= 1'b0;
                is_valid_cycle <= 1'b0;
                soft_reset <= 1'b1;

            end
        end
    end
endmodule
