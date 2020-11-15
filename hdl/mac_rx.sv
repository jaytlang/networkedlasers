`timescale 1ns / 1ps

module mac_rx(
              input logic clk,
              input logic reset,

              input logic phy_crsdv,
              input logic[1:0] phy_rxd,

              output logic axi_rx_valid,
              output logic[1:0] axi_rx_data
              );

    /* All parameters here */
    parameter ST_IDLE     = 3'h0;
    parameter ST_PREAMBLE = 3'h1;
    parameter ST_FCEVENT  = 3'h2;
    parameter ST_DST      = 3'h3;
    parameter ST_BADDST   = 3'h4;
    parameter ST_SRC      = 3'h5;
    parameter ST_ETYPE    = 3'h6;
    parameter ST_DATA     = 3'h7;

    // My MAC address: b8:27:eb:a4:30:73
    parameter MAC_LEN     = 24;
    parameter ETYPE_LEN   = 8;
    parameter THIS_MAC    = 48'hb8_27_eb_a4_30_73;
    parameter CRC_RESIDUE = 32'hc704dd7b;

    /* All logics here */
    logic docrcsampling;
    logic[31:0] currentcrc;
    logic[31:0] counter;
    logic[47:0] macbuf;
    logic[2:0] state;

    /* All submodules here */
    crc32_bzip2          rx_crc(.crc_reg(currentcrc),
                                .d(phy_rxd),
                                .calc(docrcsampling),
                                .init(phy_crsdv == 1'b1 && phy_rxd == 2'b11 && state == ST_PREAMBLE),
                                .d_valid(1'b1),
                                .clk(clk),
                                .reset(reset));

    // ILA: suggested debugging configuration
    // ila_0 rxila(.clk(clk), .probe0(state), .probe1(phy_rxd), .probe2(currentcrc));

    /* All clocked logic */
    always_ff @(posedge clk) begin
        if(reset == 1'b1) begin
            state <= ST_IDLE;
            docrcsampling <= 1'b0;
            counter <= 32'b0;
            macbuf <= 47'b0;
            
            axi_rx_valid <= 1'b0;
            axi_rx_data <= 2'b0;

        end else begin
            case(state)
                ST_IDLE: begin
                    axi_rx_valid <= 1'b0;
                    if(phy_crsdv == 1'b1 && phy_rxd == 2'b01) state <= ST_PREAMBLE;
                    else if(phy_crsdv == 1'b1 && phy_rxd == 2'b10) state <= ST_FCEVENT;
                end

                ST_PREAMBLE: begin
                    if(phy_crsdv == 1'b1 && phy_rxd == 2'b11) begin
                        state <= ST_DST;
                        counter <= 32'd40;
                        docrcsampling <= 1'b1;
                    end
                    else if(phy_crsdv == 1'b1 && phy_rxd == 2'b10) state <= ST_FCEVENT;
                    else if(phy_crsdv == 1'b0) state <= ST_IDLE;
                end

                ST_FCEVENT: begin
                    if(phy_crsdv == 1'b0) state <= ST_IDLE;
                end

                ST_DST: begin
                    if(phy_crsdv == 1'b0) begin
                        axi_rx_valid <= 1'b1;
                        axi_rx_data <= 2'b00;
                        state <= ST_IDLE;
                        docrcsampling <= 1'b0;
                        macbuf <= 48'b0;
                        counter <= 32'b0;
                    end else begin
                        axi_rx_valid <= 1'b1;
                        axi_rx_data <= phy_rxd;
                        if(counter == 6) begin      // 6 due to somewhat backwards byte ordering
                            // Promiscuous mode not supported; it would go here if so
                            state <= (THIS_MAC == {macbuf[47:8],phy_rxd,macbuf[5:0]}) ? ST_SRC : 
                                     ({macbuf[47:8],phy_rxd,macbuf[5:0]} == 48'hff_ff_ff_ff_ff_ff) ? ST_SRC : ST_BADDST;
                            counter <= 32'b0;
                            macbuf <= 48'b0;
                        end else begin
                            macbuf[counter +: 2] <= phy_rxd;
                            counter <= (counter == 46 | counter == 38 | counter == 30 | counter == 22 | counter == 14) ? counter - 14 : counter + 2;
                        end
                    end
                end

                ST_BADDST: begin
                    docrcsampling <= 1'b0;
                    if(phy_crsdv == 1'b0) state <= ST_IDLE;
                end

                // We WILL need this!
                ST_SRC: begin
                    if(phy_crsdv == 1'b0) begin
                        state <= ST_IDLE;
                        docrcsampling <= 1'b0;
                        counter <= 32'b0;
                        axi_rx_valid <= 1'b1;
                        axi_rx_data <= 2'b00;
                    end else begin
                        axi_rx_valid <= 1'b1;
                        axi_rx_data <= phy_rxd;
                        counter <= counter + 1;
                        if(counter == MAC_LEN - 1) begin
                            state <= ST_ETYPE;
                            counter <= 32'b0;
                        end
                    end
                end

                ST_ETYPE: begin
                    if(phy_crsdv == 1'b0) begin
                        state <= ST_IDLE;
                        docrcsampling <= 1'b0;
                        counter <= 32'b0;
                        axi_rx_valid <= 1'b1;
                        axi_rx_data <= 2'b00;
                    end else begin
                        axi_rx_valid <= 1'b1;
                        axi_rx_data <= phy_rxd;
                        counter <= counter + 1;
                        if(counter == ETYPE_LEN - 1) begin
                            state <= ST_DATA;
                            counter <= 32'b0;
                        end
                    end
                end


                ST_DATA: begin
                    if(phy_crsdv == 1'b1) begin
                        axi_rx_valid <= 1'b1;
                        axi_rx_data <= phy_rxd;
                    end else begin
                        docrcsampling <= 1'b0;
                        axi_rx_data <= (currentcrc == CRC_RESIDUE) ? 2'b11: 2'b00;
                        state <= ST_IDLE;
                        axi_rx_valid <= 1'b1;
                    end
                end

            endcase
        end
    end


endmodule


