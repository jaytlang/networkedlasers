`timescale 1ns / 1ps

module mac_rx_ifc(
                  input logic clk,
                  input logic rst,

                  input logic rx_axi_valid,
                  input logic[1:0] rx_axi_data,

                  output logic[1517:0][7:0] pktbuf,
                  output logic[10:0] pktbuf_maxaddr,
                  output logic doorbell
    );

    /* All parameters here */
    parameter ST_WAIT   = 1'b0;
    parameter ST_RX     = 1'b1;

    /* All logics here */
    logic[10:0] pktbuf_addr;
    logic[2:0] bytectr;
    logic state;

    /* All preliminary assignments here */

    /* All submodules here */

    /* All clocked logic here */
    always_ff @(posedge clk) begin
        if(rst == 1'b1) begin
            pktbuf <= 0;
            pktbuf_maxaddr <= 0;
            pktbuf_addr <= 0;
            bytectr <= 0;
            doorbell <= 0;
            state <= ST_WAIT;
        end else begin
            if(state == ST_WAIT) begin
                if(rx_axi_valid == 1'b1) begin
                    state <= ST_RX;
                    bytectr <= 2;
                    pktbuf[pktbuf_addr][bytectr +: 2] <= rx_axi_data;
                    pktbuf_addr <= 0;
                    pktbuf_maxaddr <= 0;
                    doorbell <= 0;

                end else begin
                    state <= ST_WAIT;
                    bytectr <= 0;
                    // Keep the pktbuf the same
                    pktbuf_addr <= 0;
                    // No change to maxaddr
                    // No change to doorbell
                end
            end else begin
                if(rx_axi_valid == 1'b0) begin
                    // Pktbuf remains untouched
                    // Collect some garbage
                    bytectr <= 0;
                    pktbuf_addr <= 0;
                    state <= ST_RX;

                    // CRC check
                    if(rx_axi_data != 2'b11) begin
                        pktbuf_maxaddr <= 0;
                        doorbell <= 0;
                    end else begin
                        // Strip the CRC and mark the packet valid
                        pktbuf_maxaddr <= pktbuf_addr - 5;
                        doorbell <= 1;
                    end
                end else begin
                    // Counter management
                    if(bytectr == 6) begin
                        bytectr <= 0;
                        pktbuf_addr <= pktbuf_addr + 1;
                    end else begin
                        bytectr <= bytectr + 2;
                        // No change to pktbuf addressing
                    end

                    // Insert the new nibble
                    pktbuf[pktbuf_addr][bytectr +: 2] <= rx_axi_data;
                    state <= ST_RX;
                    doorbell <= 0;
                    // Maxaddr unchanged
                end
            end
        end
    end

endmodule
