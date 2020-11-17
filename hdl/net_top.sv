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

    /* Ethernet header */
    parameter ETH_DST_MIN = 0;
    parameter ETH_DST_MAX = 5;
    parameter ETH_SRC_MIN = 6;
    parameter ETH_SRC_MAX = 11;
    parameter ETH_ETYPE_MIN = 12;
    parameter ETH_ETYPE_MAX = 13;

    /* Ethernet offsets */
    parameter ETH_DATA_START = 14;
    parameter ETH_MTU = 1518;
    parameter ETH_ADDRSZ = 6;

    /* Ethernet parameters */
    parameter ETH_ECHOSVC_ETYPE = 16'h1234;
    parameter ETH_MYADDR = 48'hb8_27_eb_a4_30_73;

    // No reset
    logic sys_clk;
    logic sys_rst;

    logic rx_axi_valid;
    logic[1:0] rx_axi_dout;

    logic tx_axi_ready;
    logic tx_axi_valid;
    logic[1:0] tx_axi_din;

    logic[1517:0][7:0] rx_pktbuf;
    logic[10:0] rx_pktbuf_maxaddr;
    logic rx_doorbell;

    logic tx_available;

    /* DEBUG
    logic[15:0] eth_vitro_type;
    */

    // Reset required
    logic[1517:0][7:0] tx_pktbuf;
    logic[10:0] tx_pktbuf_maxaddr;
    logic tx_doorbell;
    logic[1:0] state;


    /* All preliminary assignments here */
    assign eth_refclk = sys_clk;
    assign sys_rst = btnc;
    assign eth_rstn = !btnc;
    /*
    assign eth_vitro_type = rx_pktbuf[ETH_ETYPE_MAX:ETH_ETYPE_MIN];
    */

    /* All submodules here */
    /*
    eth_ila             ila(.clk(sys_clk),
                            .probe0(state),
                            .probe1(eth_txen),
                            .probe2(eth_txd),
                            .probe3(eth_rxd),
                            .probe4(eth_vitro_type));
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
        if(sys_rst == 1'b1) begin
            tx_pktbuf <= 0;
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

                    // Echo server: flip MAC addresses for response tx.
                    // Service type is 0x1234
                    if(rx_pktbuf[ETH_ETYPE_MAX:ETH_ETYPE_MIN] == ETH_ECHOSVC_ETYPE) begin
                        tx_pktbuf[5:0] <= rx_pktbuf[11:6];
                        tx_pktbuf[11:6] <= rx_pktbuf[5:0];
                        tx_pktbuf[1517:12] <= rx_pktbuf[1517:12];

                        tx_pktbuf_maxaddr <= rx_pktbuf_maxaddr;
                        state <= ST_PUSH;

                    // Unknown ethertype, drop the packet
                    end else begin
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
