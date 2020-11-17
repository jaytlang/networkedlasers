`timescale 1ns / 1ps

/* Top level networking stack module */
module net_top_tx(
    input logic         clk_100mhz,

    input logic         btnc,
    input logic         btnu,

    input logic         eth_crsdv,
    input logic[1:0]    eth_rxd,

    output logic        eth_txen,
    output logic[1:0]   eth_txd,
    output logic        eth_refclk,
    output logic        eth_rstn,

    output logic[15:0] led
    );

    /* All parameters here */
    parameter ST_PULL = 2'd0;
    parameter ST_PUSH = 2'd1;
    parameter ST_CONFIRM = 2'd2;

    // Ethernet header
    parameter ETH_DST_MIN = 0;
    parameter ETH_DST_MAX = 5;
    parameter ETH_SRC_MIN = 6;
    parameter ETH_SRC_MAX = 11;
    parameter ETH_ETYPE_MIN = 12;
    parameter ETH_ETYPE_MAX = 13;

    // Ethernet offsets
    parameter ETH_DATA_START = 14;
    parameter ETH_MTU = 1518;
    parameter ETH_ADDRSZ = 6;

    // Ethernet parameters
    parameter ETH_ARP_ETYPE = 16'h0806;
    parameter ETH_ECHOSVC_ETYPE = 16'h1234;
    parameter ETH_MYADDR_0 = 8'hb8;
    parameter ETH_MYADDR_1 = 8'h27;
    parameter ETH_MYADDR_2 = 8'heb;
    parameter ETH_MYADDR_3 = 8'ha4;
    parameter ETH_MYADDR_4 = 8'h30;
    parameter ETH_MYADDR_5 = 8'h73;

    // IPv4 offsets
    parameter IPV4_ADDRSZ = 4;

    // IPv4 parameters
    parameter IPV4_MYADDR = 32'hc0a80002;

    // ARPv4 over Ethernet header
    parameter ARP_HTYPE_MIN = 0 + ETH_DATA_START;
    parameter ARP_HTYPE_MAX = 1 + ETH_DATA_START;
    parameter ARP_PTYPE_MIN = 2 + ETH_DATA_START;
    parameter ARP_PTYPE_MAX = 3 + ETH_DATA_START;
    parameter ARP_HLEN_OFF = 4 + ETH_DATA_START;
    parameter ARP_PLEN_OFF = 5 + ETH_DATA_START;
    parameter ARP_OPCODE_MIN = 6 + ETH_DATA_START;
    parameter ARP_OPCODE_MAX = 7 + ETH_DATA_START;

    parameter ARP_SHA_MIN = 8 + ETH_DATA_START;
    parameter ARP_SHA_MAX = 13 + ETH_DATA_START;
    parameter ARP_SPA_MIN = 14 + ETH_DATA_START;
    parameter ARP_SPA_MAX = 17 + ETH_DATA_START;
    parameter ARP_THA_MIN = 18 + ETH_DATA_START;
    parameter ARP_THA_MAX = 23 + ETH_DATA_START;
    parameter ARP_TPA_MIN = 24 + ETH_DATA_START;
    parameter ARP_TPA_MAX = 27 + ETH_DATA_START;

    // ARPv4 parameters
    parameter ARP_ETH_HTYPE = 16'b01;
    parameter ARP_IPV4_PTYPE = 16'h0800;
    parameter ARP_ETH_HLEN = ETH_ADDRSZ;
    parameter ARP_IPV4_PLEN = IPV4_ADDRSZ;
    parameter ARP_HDR_END = ARP_TPA_MAX + 1;

    parameter ARP_REQ_OPCODE = 16'd1;
    parameter ARP_RESP_OPCODE = 16'd2;


    /* All logics here */
    // No reset
    logic sys_clk;
    logic sys_rst;

    logic rx_axi_valid;
    logic[1:0] rx_axi_dout;

    logic tx_axi_ready;
    logic tx_axi_valid;
    logic[1:0] tx_axi_din;
    logic[7:0] rx_pktbuf[1517:0];

    logic[7:0] rx_pktbuf[ETH_MTU - 1:0];
    logic[10:0] rx_pktbuf_maxaddr;
    logic rx_doorbell;

    logic tx_available;

    // Reset required
    logic[7:0] tx_pktbuf[ETH_MTU - 1:0];
    logic[10:0] tx_pktbuf_maxaddr;
    logic tx_doorbell;
    logic[1:0] state;

    logic[7:0] arp_mha[ETH_ADDRSZ-1:0];
    logic[7:0] arp_mpa[IPV4_ADDRSZ-1:0];

    /* All preliminary assignments here */
    assign eth_refclk = sys_clk;
    assign sys_rst = btnc;
    assign eth_rstn = !btnc;

    /* All submodules here */
    /* Suggested ILA configuration:
    eth_ila             ila(.clk(sys_clk),
                            .probe0(state),
                            .probe1(eth_txen),
                            .probe2(eth_txd),
                            .probe3(eth_rxd));
    */

    eth_refclk_divider  erd(.in(clk_100mhz),
                            .out(sys_clk),
                            .reset(sys_rst));

    mac_tx              resptx(.clk(sys_clk),
                               .reset(sys_rst),
                               .axi_valid(tx_axi_valid),
                               .axi_din(tx_axi_din),
                               .axi_ready(tx_axi_ready),
                               .phy_txen(eth_txen),
                               .phy_txd(eth_txd));

    mac_rx                reqrx(.clk(sys_clk),
                                .reset(sys_rst),
                                .phy_crsdv(eth_crsdv),
                                .phy_rxd(eth_rxd),
                                .axi_rx_valid(rx_axi_valid),
                                .axi_rx_data(rx_axi_dout));


    mac_rx_ifc          rcvifc(.clk(sys_clk),
                               .rst(sys_rst),
                               .rx_axi_valid(rx_axi_valid),
                               .rx_axi_data(rx_axi_dout),
                               .pktbuf(rx_pktbuf),
                               .pktbuf_maxaddr(rx_pktbuf_maxaddr),
                               .doorbell(rx_doorbell));

    mac_tx_ifc          tsmifc(.clk(sys_clk),
                               .rst(sys_rst),
                               .tx_axi_valid(tx_axi_valid),
                               .tx_axi_data(tx_axi_din),
                               .tx_axi_ready(tx_axi_ready),
                               .pktbuf(tx_pktbuf),
                               .pktbuf_maxaddr(tx_pktbuf_maxaddr),
                               .doorbell(tx_doorbell),
                               .available(tx_available));

    /* Clocked logic here */
    always_ff @(posedge sys_clk) begin

        /* Main system runtime loop */
        if(sys_rst == 1'b1) begin
            foreach(tx_pktbuf[i]) tx_pktbuf[i] <= 0;
            tx_pktbuf_maxaddr <= 0;
            tx_doorbell <= 0;
            state <= ST_PULL;

            foreach(arp_mha[i]) arp_mha[i] <= 0;
            foreach(arp_mpa[i]) arp_mpa[i] <= 0;

        end else begin
            if(state == ST_PULL) begin
                // Don't transmit right now.
                tx_doorbell <= 0;

                // Wait for new stuff
                if(rx_doorbell == 1'b1) begin
                    // Process packets into the TX buffer immediately.
                    // They will stay valid for ~48 clock cycles, so this
                    // approach will work for some L3 protocols.
		    //
                    // Get the ethertype of the packet and check it
                    // Currently supported services are ARP and ECHOSVC
                    if(rx_pktbuf[ETH_ETYPE_MAX:ETH_ETYPE_MIN] == ETH_ARP_ETYPE) begin
                        // ADDRESS RESOLUTION PROTOCOL v4
                        // If the H/PTYPE or H/PLEN fields don't match, drop the packet
                        if(rx_pktbuf[ARP_HTYPE_MAX:ARP_HTYPE_MIN] != ARP_ETH_HTYPE) state <= ST_CONFIRM;
                        else if(rx_pktbuf[ARP_PTYPE_MAX:ARP_PTYPE_MIN] != ARP_IPV4_PTYPE) state <= ST_CONFIRM;
                        else if(rx_pktbuf[ARP_HLEN_OFF] != ARP_ETH_HLEN) state <= ST_CONFIRM;
                        else if(rx_pktbuf[ARP_PLEN_OFF] != ARP_IPV4_PLEN) state <= ST_CONFIRM;

                        // Valid ARP packet received for Ethernet + IPv4.
                        else begin
                            // If we are the TPA, or the SPA matches our table, update the mapping.
                            if(rx_pktbuf[ARP_TPA_MAX:ARP_TPA_MIN] == IPV4_MYADDR ||
                               rx_pktbuf[ARP_SPA_MAX:ARP_SPA_MIN] == arp_mpa) begin

                                arp_mha <= rx_pktbuf[ARP_SHA_MAX:ARP_SHA_MIN];
                                arp_mpa <= rx_pktbuf[ARP_SPA_MAX:ARP_SPA_MIN];
                            end

                            // If we are the TPA, and this is a request, issue a reply.
                            // Form a from-scratch reply in the tx_pktbuf and ring the doorbell
                            if(rx_pktbuf[ARP_TPA_MAX:ARP_TPA_MIN] == IPV4_MYADDR &&
                               rx_pktbuf[ARP_OPCODE_MAX:ARP_OPCODE_MIN] == ARP_REQ_OPCODE) begin

                                // MAC header
                                tx_pktbuf[ETH_DST_MAX:ETH_DST_MIN] <= rx_pktbuf[ARP_SHA_MAX:ARP_SHA_MIN];

                                tx_pktbuf[ETH_SRC_MIN] <= ETH_MYADDR_0;
                                tx_pktbuf[ETH_SRC_MIN + 1] <= ETH_MYADDR_1;
                                tx_pktbuf[ETH_SRC_MIN + 2] <= ETH_MYADDR_2;
                                tx_pktbuf[ETH_SRC_MIN + 3] <= ETH_MYADDR_3;
                                tx_pktbuf[ETH_SRC_MIN + 4] <= ETH_MYADDR_4;
                                tx_pktbuf[ETH_SRC_MIN + 5] <= ETH_MYADDR_5;

                                tx_pktbuf[ETH_ETYPE_MAX:ETH_ETYPE_MIN] <= rx_pktbuf[ETH_ETYPE_MAX:ETH_ETYPE_MIN];

                                // ARP header
                                tx_pktbuf[ARP_HTYPE_MAX:ARP_HTYPE_MIN] <= rx_pktbuf[ARP_HTYPE_MAX:ARP_HTYPE_MIN];
                                tx_pktbuf[ARP_PTYPE_MAX:ARP_PTYPE_MIN] <= rx_pktbuf[ARP_PTYPE_MAX:ARP_PTYPE_MIN];
                                tx_pktbuf[ARP_HLEN_OFF] <= rx_pktbuf[ARP_HLEN_OFF];
                                tx_pktbuf[ARP_PLEN_OFF] <= rx_pktbuf[ARP_PLEN_OFF];
                                tx_pktbuf[ARP_OPCODE_MIN] <= ARP_RESP_OPCODE;
                                tx_pktbuf[ARP_OPCODE_MAX] <= 0;

                                // ARP body: S/TPA, S/THA
                                tx_pktbuf[ARP_SHA_MIN] <= ETH_MYADDR_0;
                                tx_pktbuf[ARP_SHA_MIN + 1] <= ETH_MYADDR_1;
                                tx_pktbuf[ARP_SHA_MIN + 2] <= ETH_MYADDR_2;
                                tx_pktbuf[ARP_SHA_MIN + 3] <= ETH_MYADDR_3;
                                tx_pktbuf[ARP_SHA_MIN + 4] <= ETH_MYADDR_4;
                                tx_pktbuf[ARP_SHA_MIN + 5] <= ETH_MYADDR_5;

                                tx_pktbuf[ARP_THA_MAX:ARP_THA_MIN] <= rx_pktbuf[ARP_SHA_MAX:ARP_SHA_MIN];

                                tx_pktbuf[ARP_SPA_MIN] <= IPV4_MYADDR[7:0];
                                tx_pktbuf[ARP_SPA_MIN + 1] <= IPV4_MYADDR[15:8];
                                tx_pktbuf[ARP_SPA_MIN + 2] <= IPV4_MYADDR[23:16];
                                tx_pktbuf[ARP_SPA_MIN + 3] <= IPV4_MYADDR[31:24];

                                tx_pktbuf[ARP_TPA_MAX:ARP_TPA_MIN] <= rx_pktbuf[ARP_SPA_MAX:ARP_SPA_MIN];

                                // Done. Send the packet.
                                tx_pktbuf_maxaddr <= ARP_HDR_END;
                                state <= ST_PUSH;
                            end

                            // Else, drop the packet from here.
                        end


                    end else if(rx_pktbuf[ETH_ETYPE_MAX:ETH_ETYPE_MIN] == ETH_ECHOSVC_ETYPE) begin
                        // Echo service. Ethertype 1234.
                        // Swap MAC address and ping the client back.
                        tx_pktbuf[ETH_DST_MAX:ETH_DST_MIN] <= rx_pktbuf[ETH_SRC_MAX:ETH_SRC_MIN];
                        tx_pktbuf[ETH_SRC_MAX:ETH_SRC_MIN] <= rx_pktbuf[ETH_DST_MAX:ETH_DST_MIN];
                        tx_pktbuf[ETH_MTU - 1:ETH_ETYPE_MIN] <= rx_pktbuf[ETH_MTU - 1:ETH_ETYPE_MIN];

                        tx_pktbuf_maxaddr <= rx_pktbuf_maxaddr;
                        state <= ST_PUSH;

                    end else begin
                        // Unknown ethertype. Drop packet.
                        state <= ST_CONFIRM;
                    end
                end // else don't do anything lol

            end else if(state == ST_PUSH) begin
                if(tx_available == 1'b1) begin

                    // tx_pktbuf already set. Go!
                    // tx_pktbuf_maxaddr also already set
                    tx_doorbell <= 1'b1;
                    state <= ST_CONFIRM;

                end // else do nothing

            // Block until new data comes in
            end else if(state == ST_CONFIRM) begin
                tx_doorbell <= 1'b0;
                if(rx_doorbell == 1'b0) state <= ST_PULL;
            end
        end
    end
endmodule
