`timescale 1ns / 1ps

module ipv4_csum(input logic clk,
                 input logic rst,
                 
                 input logic[7:0] pktbuf[1517:0],
                 input logic pkt_valid,
                 
                 output logic[31:0] csum,
                 output logic csum_valid
                 );
                 
    `include "offsets.svh"
    
    /* All parameters here */
    parameter ST_WAIT = 2'b00;
    parameter ST_CALC = 2'b01;
    parameter ST_FINISH = 2'b11;
    
    /* All logics */
    logic[1:0] state;
    logic[3:0] counter;
    logic[3:0] i;
    
    /* All clocked logic */
    always_ff @(posedge clk) begin
        if(rst == 1'b1) begin
            csum <= 0;
            csum_valid <= 0;
            state <= ST_WAIT;
            i <= 0;
            counter <= 0;
        end else if(state == ST_WAIT) begin
            if(pkt_valid == 1'b1) begin
            
                // Grab the IHL and load it into the counter
                // This has already been validated, i.e. the IHL isn't
                // outside of the bounds imposed by IPv4 header
                // Multiply * 32 bit words, divide into bytes from bits => 32/8 => 4
                counter <= pktbuf[IPV4_VSN_IHL][IPV4_IHL_TOP:IPV4_IHL_BOT] * 4;
                state <= ST_CALC;
                csum <= 0;
            
            end else begin
                csum <= 0;
                state <= ST_WAIT;
                counter <= 0;
            end
            csum_valid <= 0;
            i <= 0;
            
        // Compute the IPV4 checksum, asserting csum_valid
        // for a single cycle when completed. Then, reset.
        end else if(state == ST_CALC) begin
            // Last cycle?
            if(counter < 2) begin
                // Add the leftover byte, if any
                if(counter == 1) csum <= csum + pktbuf[ETH_DATA_START + i];
                state <= ST_FINISH;
            end else begin
                i <= i + 2;
                counter <= counter - 2;
                csum <= csum + pktbuf[ETH_DATA_START + i] + pktbuf[ETH_DATA_START + i + 1];
            end    
            csum_valid <= 0;
        
        end else if(state == ST_FINISH) begin
            if(csum >> 16 != 0) begin
                csum <= (csum & 16'hffff) + (csum >> 16);
            end
            
            if(pkt_valid == 1'b0) state <= ST_WAIT;
            counter <= 0;
            i <= 0;
            csum_valid <= 1;
        end
    end
    
endmodule