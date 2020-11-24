// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.2.1 (lin64) Build 2729669 Thu Dec  5 04:48:12 MST 2019
// Date        : Thu Nov 19 22:47:13 2020
// Host        : noonian running 64-bit Pop!_OS 20.04 LTS
// Command     : write_verilog -force -mode synth_stub
//               /home/fischerm/GitHub/networkedlasers/ip/eth_refclk_divider/eth_refclk_divider_stub.v
// Design      : eth_refclk_divider
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a100tcsg324-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
module eth_refclk_divider(out, reset, in)
/* synthesis syn_black_box black_box_pad_pin="out,reset,in" */;
  output out;
  input reset;
  input in;
endmodule
