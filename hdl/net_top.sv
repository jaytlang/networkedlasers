`timescale 1ns / 1ps

/* Top level networking stack module */
module net_top(
    input logic         clk_100mhz,

    input logic         btnc,
    input logic[15:0]   sw,
    output logic[7:0]   ja, jb, jc, jd,

    output logic [7:0]  an,
    output logic        ca, cb, cc, cd, ce, cf, cg, dp,

    input logic         eth_crsdv,
    input logic[1:0]    eth_rxd,

    output logic        eth_txen,
    output logic[1:0]   eth_txd,
    output logic        eth_refclk,
    output logic        eth_rstn
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
    parameter ETH_ADDRSZ = 8'h06;

    // Ethernet parameters
    parameter ETH_ARP_ETYPE_1 = 8'h08;
    parameter ETH_ARP_ETYPE_2 = 8'h06;

    parameter ETH_ECHOSVC_ETYPE_1 = 8'h12;
    parameter ETH_ECHOSVC_ETYPE_2 = 8'h34;

    parameter ETH_MYADDR_1 = 8'hb8;
    parameter ETH_MYADDR_2 = 8'h27;
    parameter ETH_MYADDR_3 = 8'heb;
    parameter ETH_MYADDR_4 = 8'ha4;
    parameter ETH_MYADDR_5 = 8'h30;
    parameter ETH_MYADDR_6 = 8'h73;


    /* All logics here */
    // No reset
    logic sys_clk;
    logic sys_rst;

    logic rx_axi_valid;
    logic[1:0] rx_axi_dout;

    logic tx_axi_ready;
    logic tx_axi_valid;
    logic[1:0] tx_axi_din;

    logic[7:0] rx_pktbuf[ETH_MTU - 1:0];
    logic[10:0] rx_pktbuf_maxaddr;
    logic rx_doorbell;

    logic tx_available;

    // Reset required
    logic[7:0] tx_pktbuf[ETH_MTU - 1:0];
    logic[10:0] tx_pktbuf_maxaddr;
    logic tx_doorbell;
    logic[1:0] state;

    /* All preliminary assignments here */
    assign eth_refclk = sys_clk;
    assign sys_rst = btnc;
    assign eth_rstn = !btnc;

    /* All submodules here */
    /* Suggested [networking] ILA configurations:
    eth_ila             ila(.clk(sys_clk),
                            .probe0(state),
                            .probe1(eth_txen),
                            .probe2(eth_txd),
                            .probe3(eth_rxd));
    */

    logic [31:0] display_data;
    assign display_data = {rx_pktbuf[ETH_DATA_START], rx_pktbuf[ETH_DATA_START+1], rx_pktbuf[ETH_DATA_START+2], rx_pktbuf[ETH_DATA_START+3]};
    
    
    display_controller  dctl(.reset_in(sys_rst),
                             .clock_in(sys_clk),
                             .frame_delay(sw),
                             .pkt_buf_in(rx_pktbuf),
                             .pkt_buf_doorbell_in(rx_doorbell),

                             .x_sclk(ja[3]),
                             .x_mosi(ja[1]),
                             .x_cs(ja[0]),
                             .y_sclk(jb[3]),
                             .y_mosi(jb[1]),
                             .y_cs(jb[0]),
                             
                             .r_pwm(jc[0]),
                             .g_pwm(jc[1]),
                             .b_pwm(jc[2]),
                             .frame_sync(jc[3]));

    logic [6:0] segments;
    assign {cg, cf, ce, cd, cc, cb, ca} = segments[6:0];
    hex_display           hd(.clk_in(sys_clk),
                             .data_in(display_data),
                             .seg_out(segments),
                             .strobe_out(an));


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

        end else begin
            if(state == ST_PULL) begin
                // Don't transmit right now.
                tx_doorbell <= 0;

                // Wait for new stuff
                if(rx_doorbell == 1'b1) begin
                    // Process packets into the TX buffer immediately.
                    // They will stay valid for ~48 clock cycles, so this
                    // approach will work for some L3 protocols.

                    // Get the ethertype of the packet and check it
                    // Currently supported services are ARP and ECHOSVC

                    if(rx_pktbuf[ETH_ETYPE_MAX] == ETH_ECHOSVC_ETYPE_2 &&
                                rx_pktbuf[ETH_ETYPE_MIN] == ETH_ECHOSVC_ETYPE_1) begin
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