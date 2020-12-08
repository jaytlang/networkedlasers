`timescale 1ns / 1ps

/* Top level networking stack module */
module netstack(
    input logic         sys_clk,
    input logic         sys_rst,
    
    input logic         eth_crsdv,
    input logic[1:0]    eth_rxd,

    output logic        eth_txen,
    output logic[1:0]   eth_txd,
    output logic        eth_refclk,
    output logic        eth_rstn,

    output logic[15:0] errno,
    output logic[7:0] databuf[1517:0],
    output logic[15:0] databuf_len,
    output logic databuf_valid
    );
    
    `include "offsets.svh"
    `include "errno.svh"

    /* All parameters here */
    parameter ST_PULL = 2'b00;
    parameter ST_PROC = 2'b01;
    parameter ST_PUSH = 2'b10;
    parameter ST_CONFIRM = 2'b11;
    
    /* All logics here */
    // No reset

    logic rx_axi_valid;
    logic[1:0] rx_axi_dout;

    logic tx_axi_ready;
    logic tx_axi_valid;
    logic[1:0] tx_axi_din;

    logic[7:0] rx_pktbuf[ETH_MTU - 1:0];
    logic[10:0] rx_pktbuf_maxaddr;
    logic rx_doorbell;

    logic tx_available;
    
    logic csum_out_valid;
    logic[31:0] csum_out;

    // Reset required
    logic[7:0] tx_pktbuf[ETH_MTU - 1:0];
    logic[10:0] tx_pktbuf_maxaddr;
    logic tx_doorbell;
    logic[1:0] state;

    logic[7:0] arp_mha[ETH_ADDRSZ-1:0];
    logic[7:0] arp_mpa[IPV4_ADDRSZ-1:0];
    
    logic csum_in_valid;

    /* All preliminary assignments here */    
    assign eth_refclk = sys_clk;
    assign eth_rstn = ~sys_rst;

    /* Suggested ILA configurations:
    eth_ila             ila(.clk(sys_clk),
                            .probe0(state),
                            .probe1(csum_in_valid),
                            .probe2(csum_out),
                            .probe3(csum_out_valid),
                            .probe4(eth_rxd));
    */
                            
    ipv4_csum           ipcsum(.clk(sys_clk),
                               .rst(sys_rst),
                               .pktbuf(rx_pktbuf),
                               .pkt_valid(csum_in_valid),
                               .csum(csum_out),
                               .csum_valid(csum_out_valid));

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
            foreach(databuf[i]) databuf[i] <= 0;
            databuf_valid <= 0;
            databuf_len <= 0;
            
            foreach(tx_pktbuf[i]) tx_pktbuf[i] <= 0;
            tx_pktbuf_maxaddr <= 0;
            tx_doorbell <= 0;
            state <= ST_PULL;
            errno[15:0] <= EIDLE;
            
            csum_in_valid <= 0;

            foreach(arp_mha[i]) arp_mha[i] <= 0;
            foreach(arp_mpa[i]) arp_mpa[i] <= 0;

        end else begin
            if(state == ST_PULL) begin
                // Don't transmit right now.
                tx_doorbell <= 0;

                // Wait for new stuff
                if(rx_doorbell == 1'b1) begin
                    // Process packets into the buffer immediately.
                    // They will stay valid for ~48 clock cycles, so this
                    // approach will work for us.
                    
                    // Immediately, clear out the databuf and set it to invalid,
                    // so there's some hang time to reset the framebuffer etc.
                    foreach(databuf[i]) databuf[i] <= 0;
                    databuf_valid <= 0;
                    databuf_len <= 0;
        
                    // Get the ethertype of the packet and check it
                    // Currently supported services are ARP, ECHOSVC, IPv4

                    if(rx_pktbuf[ETH_ETYPE_MAX] == ETH_ARP_ETYPE_2 &&
                       rx_pktbuf[ETH_ETYPE_MIN] == ETH_ARP_ETYPE_1) begin

                        // ADDRESS RESOLUTION PROTOCOL v4
                        // If the H/PTYPE or H/PLEN fields don't match, drop the packet
                        if(rx_pktbuf[ARP_HTYPE_MAX] != ARP_ETH_HTYPE_2) state <= ST_CONFIRM;
                        else if(rx_pktbuf[ARP_HTYPE_MIN] != ARP_ETH_HTYPE_1) state <= ST_CONFIRM;

                        else if(rx_pktbuf[ARP_PTYPE_MAX] != ARP_IPV4_PTYPE_2) state <= ST_CONFIRM;
                        else if(rx_pktbuf[ARP_PTYPE_MIN] != ARP_IPV4_PTYPE_1) state <= ST_CONFIRM;

                        else if(rx_pktbuf[ARP_HLEN_OFF] != ARP_ETH_HLEN) state <= ST_CONFIRM;
                        else if(rx_pktbuf[ARP_PLEN_OFF] != ARP_IPV4_PLEN) state <= ST_CONFIRM;

                        // Valid ARP packet received for Ethernet + IPv4.
                        // Proceed to process it.
                        else begin
                            // If we are the TPA, update the mapping.
                            if(rx_pktbuf[ARP_TPA_MAX] == IPV4_MYADDR_4 &&
                               rx_pktbuf[ARP_TPA_MAX - 1] == IPV4_MYADDR_3 &&
                               rx_pktbuf[ARP_TPA_MAX - 2] == IPV4_MYADDR_2 &&
                               rx_pktbuf[ARP_TPA_MAX - 3] == IPV4_MYADDR_1) begin

                                arp_mha <= rx_pktbuf[ARP_SHA_MAX:ARP_SHA_MIN];  // Thoughts and prayers
                                arp_mpa <= rx_pktbuf[ARP_SPA_MAX:ARP_SPA_MIN];
                                
                                errno[15:0] <= EARPQ;

                                // If this is a request, issue a reply.
                                // Form a from-scratch reply in the tx_pktbuf and ring the doorbell
                                if(rx_pktbuf[ARP_OPCODE_MAX] == ARP_OPCODE_REQ &&
                                   rx_pktbuf[ARP_OPCODE_MIN] == ARP_OPCODE_UPPER) begin

                                    // MAC header
                                    tx_pktbuf[ETH_DST_MAX:ETH_DST_MIN] <= rx_pktbuf[ARP_SHA_MAX:ARP_SHA_MIN];

                                    tx_pktbuf[ETH_SRC_MIN + 5] <= ETH_MYADDR_6; // ETH_SRC_MAX
                                    tx_pktbuf[ETH_SRC_MIN + 4] <= ETH_MYADDR_5;
                                    tx_pktbuf[ETH_SRC_MIN + 3] <= ETH_MYADDR_4;
                                    tx_pktbuf[ETH_SRC_MIN + 2] <= ETH_MYADDR_3;
                                    tx_pktbuf[ETH_SRC_MIN + 1] <= ETH_MYADDR_2;
                                    tx_pktbuf[ETH_SRC_MIN + 0] <= ETH_MYADDR_1;

                                    tx_pktbuf[ETH_ETYPE_MAX:ETH_ETYPE_MIN] <= rx_pktbuf[ETH_ETYPE_MAX:ETH_ETYPE_MIN];

                                    // ARP header
                                    tx_pktbuf[ARP_HTYPE_MAX:ARP_HTYPE_MIN] <= rx_pktbuf[ARP_HTYPE_MAX:ARP_HTYPE_MIN];
                                    tx_pktbuf[ARP_PTYPE_MAX:ARP_PTYPE_MIN] <= rx_pktbuf[ARP_PTYPE_MAX:ARP_PTYPE_MIN];
                                    tx_pktbuf[ARP_HLEN_OFF] <= rx_pktbuf[ARP_HLEN_OFF];
                                    tx_pktbuf[ARP_PLEN_OFF] <= rx_pktbuf[ARP_PLEN_OFF];
                                    tx_pktbuf[ARP_OPCODE_MIN] <= ARP_OPCODE_UPPER;
                                    tx_pktbuf[ARP_OPCODE_MAX] <= ARP_OPCODE_RESP;

                                    // ARP body: S/TPA, S/THA
                                    tx_pktbuf[ARP_SHA_MIN + 5] <= ETH_MYADDR_6;
                                    tx_pktbuf[ARP_SHA_MIN + 4] <= ETH_MYADDR_5;
                                    tx_pktbuf[ARP_SHA_MIN + 3] <= ETH_MYADDR_4;
                                    tx_pktbuf[ARP_SHA_MIN + 2] <= ETH_MYADDR_3;
                                    tx_pktbuf[ARP_SHA_MIN + 1] <= ETH_MYADDR_2;
                                    tx_pktbuf[ARP_SHA_MIN + 0] <= ETH_MYADDR_1;

                                    tx_pktbuf[ARP_THA_MAX:ARP_THA_MIN] <= rx_pktbuf[ARP_SHA_MAX:ARP_SHA_MIN];

                                    tx_pktbuf[ARP_SPA_MIN + 0] <= IPV4_MYADDR_1;
                                    tx_pktbuf[ARP_SPA_MIN + 1] <= IPV4_MYADDR_2;
                                    tx_pktbuf[ARP_SPA_MIN + 2] <= IPV4_MYADDR_3;
                                    tx_pktbuf[ARP_SPA_MIN + 3] <= IPV4_MYADDR_4;

                                    tx_pktbuf[ARP_TPA_MAX:ARP_TPA_MIN] <= rx_pktbuf[ARP_SPA_MAX:ARP_SPA_MIN];

                                    // Done. Send the packet with proper padding
                                    tx_pktbuf_maxaddr <= ARP_HDR_END;
                                    state <= ST_PUSH;
                                end else begin
                                    state <= ST_CONFIRM;
                                end
                            end else begin
                                state <= ST_CONFIRM;
                            end

                        end

                    end else if(rx_pktbuf[ETH_ETYPE_MAX] == ETH_IPV4_ETYPE_2 &&
                                rx_pktbuf[ETH_ETYPE_MIN] == ETH_IPV4_ETYPE_1) begin
                                
                        // Configure the packet for reception: validate some basic
                        // parameters before sending it on to processing
                        // Is the version IPv4? If not drop
                        if(rx_pktbuf[IPV4_VSN_IHL][IPV4_VSN_TOP:IPV4_VSN_BOT] != 4) begin
                            state <= ST_CONFIRM;
                            errno[15:0] <= ENOV4;
                        end
                        
                        // Is the IHL at least 5 (*32 bits) => at least 20 bytes?
                        if(rx_pktbuf[IPV4_VSN_IHL][IPV4_IHL_TOP:IPV4_IHL_BOT] < 5) begin
                            errno[15:0] <= ESHDR;
                            state <= ST_CONFIRM;
                        end
                        
                        // Is the TTL zero? If so, drop the packet.
                        // If/when we implement full ICMP, send a time exceeded back
                        if(rx_pktbuf[IPV4_TTL] == 0) begin
                            state <= ST_CONFIRM;
                            errno[15:0] <= EDEAD;
                        end
                        
                        // Is the protocol UDP? We don't do anything else.
                        if(rx_pktbuf[IPV4_PROTOCOL] != IPV4_UDP_PROTO) begin
                            errno[15:0] <= EPROT;
                            state <= ST_CONFIRM;
                        end
                        
                        // Does the packet utilize fragmentation? If so, drop
                        if(rx_pktbuf[IPV4_FLAGS_STARTOF][IPV4_FLAGS_DNF_OFFSET] != 1) begin
                            errno[15:0] <= EFRAG;
                            state <= ST_CONFIRM;
                        end
                        
                        // Are we the intended receiver, or is the packet a broadcast packet?
                        if((rx_pktbuf[IPV4_DSTADDR_4] != IPV4_MYADDR_4 ||
                            rx_pktbuf[IPV4_DSTADDR_3] != IPV4_MYADDR_3 ||
                            rx_pktbuf[IPV4_DSTADDR_2] != IPV4_MYADDR_2 ||
                            rx_pktbuf[IPV4_DSTADDR_1] != IPV4_MYADDR_1) &&
                           (rx_pktbuf[IPV4_DSTADDR_4] != 8'hff ||
                            rx_pktbuf[IPV4_DSTADDR_3] != 8'hff ||
                            rx_pktbuf[IPV4_DSTADDR_2] != 8'hff ||
                            rx_pktbuf[IPV4_DSTADDR_1] != 8'hff)) begin
                            
                            // If the above fails, we are not the intended receiver,
                            // drop the packet entirely
                            errno[15:0] <= EPDST;
                            state <= ST_CONFIRM;
                            
                        end else begin
                            // Initial checks pass
                            // Start checksum calculation, move to processing state
                            csum_in_valid <= 1;
                            state <= ST_PROC;
                        end
                    end else if(rx_pktbuf[ETH_ETYPE_MAX] == ETH_ECHOSVC_ETYPE_2 &&
                                rx_pktbuf[ETH_ETYPE_MIN] == ETH_ECHOSVC_ETYPE_1) begin
                                
                        // Echo service. Ethertype 1234.
                        // Swap MAC address and ping the client back.
                        tx_pktbuf[ETH_DST_MAX:ETH_DST_MIN] <= rx_pktbuf[ETH_SRC_MAX:ETH_SRC_MIN];
                        tx_pktbuf[ETH_SRC_MAX:ETH_SRC_MIN] <= rx_pktbuf[ETH_DST_MAX:ETH_DST_MIN];
                        tx_pktbuf[ETH_MTU - 1:ETH_ETYPE_MIN] <= rx_pktbuf[ETH_MTU - 1:ETH_ETYPE_MIN];

                        tx_pktbuf_maxaddr <= rx_pktbuf_maxaddr;
                        state <= ST_PUSH;
                        errno[15:0] <= EECHO;

                    end else begin
                        // Unknown ethertype. Drop packet.
                        state <= ST_CONFIRM;
                        errno[15:0] <= EETYP;
                    end
                end // else don't do anything lol

            // IP Offload Engine sits here
            // Checks off the checksum and then dissects what's inside.
            end else if(state == ST_PROC) begin
                // No valid data on the input side,
                // wait for clocked output
                csum_in_valid <= 0;
                if(csum_out_valid == 1) begin
                    // Verify the checksum against the input.
                    if(csum_out != 0) begin
                        state <= ST_CONFIRM;
                        errno[15:0] <= ECSUM;
                    end else begin
                        // Handle UDP. Particularly, check that the destination
                        // port is 0xA455 ;) Disregard the UDP checksum, and set
                        // databuf_len to be the proper length-of-packet to kill off
                        // padding + header data.
                        if(rx_pktbuf[UDP_DPORT_MIN] != UDP_MYPORT_1 ||
                           rx_pktbuf[UDP_DPORT_MAX] != UDP_MYPORT_2) begin
                            errno[15:0] <= EPORT;
                            state <= ST_CONFIRM;
                        end else begin
                            // Packet is GOOD!
                            if(rx_pktbuf[UDP_DATA_START] == 8'h02) errno[15:0] <= EGOOD;
                            
                            // Set databuf here. Treat it as ephemerally
                            // as the RX packet buffer. Obtain its length
                            // by taking the length bit of the UDP header,
                            // and subtracting the 8 bytes of header
                            
                            // Still not sure if this is correct now. Only
                            // thing I can confirm is that UDP packets are in
                            // fact checking out via IPv4 checksum and CRC32, plus
                            // port stuffs.
                            databuf_len <= {rx_pktbuf[UDP_PKTLEN_MIN],rx_pktbuf[UDP_PKTLEN_MAX]} - 8;
                            databuf_valid <= 1;
                            foreach(rx_pktbuf[i]) databuf[i] <= (i + UDP_DATA_START >= ETH_MTU) ? 0
                                                                    : rx_pktbuf[i + UDP_DATA_START];
                            state <= ST_CONFIRM;
                        end
                        
                    end
                
                end
            
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
