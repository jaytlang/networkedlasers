`timescale 1ns / 1ps

module mac_tx_ifc(
                  input logic clk,
                  input logic rst,

                  input logic tx_axi_ready,
                  output logic tx_axi_valid,
                  output logic[1:0] tx_axi_data,

                  input logic[7:0] pktbuf[1517:0],
                  input logic[10:0] pktbuf_maxaddr,
                  input logic doorbell,
                  output logic available
    );

    /* All parameters here */
    parameter ST_WAIT   = 1'b0;
    parameter ST_TX     = 1'b1;

    /* All logics here */
    logic[2:0] bytectr;
    logic[10:0] pktbuf_addr;
    logic state;

    /* All preliminary assignments here */

    /* All submodules here */

    /* All clocked logic here */
    always_ff @(posedge clk) begin
        if(rst == 1'b1) begin
            bytectr <= 0;
            pktbuf_addr <= 0;
            tx_axi_valid <= 0;
            tx_axi_data <= 0;
            state <= ST_WAIT;
            available <= 1;
        end else begin
            if(state == ST_WAIT) begin

                if(doorbell == 1'b1) begin
                    // Prepare for transit
                    state <= ST_TX;
                    pktbuf_addr <= 0;
                    bytectr <= 0;
                    available <= 0;
                end else begin
                    // Idle time
                    state <= ST_WAIT;
                    pktbuf_addr <= 0;
                    bytectr <= 0;
                    available <= 1;
                end

                tx_axi_valid <= 0;
                tx_axi_data <= 0;

            end else begin
                available <= 0;
                // Can send new data down the line
                if(tx_axi_ready == 1'b1) begin

                    // Need to advance the counts
                    if(bytectr == 6) begin
                        bytectr <= 0;
                        pktbuf_addr <= pktbuf_addr + 1;

                        // Are we done?
                        if(pktbuf_addr == pktbuf_maxaddr) begin
                            state <= ST_WAIT;
                            tx_axi_valid <= 1'b0;
                        end else begin
                            state <= ST_TX;
                            tx_axi_valid <= 1'b1;
                        end

                        // Regardless, update the data as if we r advancing
                        tx_axi_data <= pktbuf[pktbuf_addr + 1][1:0];

                    // Don't need to advance the counts
                    end else begin
                        bytectr <= bytectr + 2;
                        tx_axi_valid <= 1'b1;
                        state <= ST_TX;
                        tx_axi_data <= pktbuf[pktbuf_addr][bytectr + 2 +: 2];
                        // No change to pktbuf_addr
                    end

                // Can't send new data down the line yet
                end else begin
                    tx_axi_valid <= 1'b1;
                    state <= ST_TX;
                    tx_axi_data <= pktbuf[pktbuf_addr][bytectr +: 2];
                    // No change to bytectr, pktbuf_addr
                end
            end
        end
    end


endmodule