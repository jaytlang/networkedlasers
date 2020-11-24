-- Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2019.2.1 (lin64) Build 2729669 Thu Dec  5 04:48:12 MST 2019
-- Date        : Thu Nov 19 22:47:13 2020
-- Host        : noonian running 64-bit Pop!_OS 20.04 LTS
-- Command     : write_vhdl -force -mode synth_stub
--               /home/fischerm/GitHub/networkedlasers/ip/eth_refclk_divider/eth_refclk_divider_stub.vhdl
-- Design      : eth_refclk_divider
-- Purpose     : Stub declaration of top-level module interface
-- Device      : xc7a100tcsg324-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity eth_refclk_divider is
  Port ( 
    \out\ : out STD_LOGIC;
    reset : in STD_LOGIC;
    \in\ : in STD_LOGIC
  );

end eth_refclk_divider;

architecture stub of eth_refclk_divider is
attribute syn_black_box : boolean;
attribute black_box_pad_pin : string;
attribute syn_black_box of stub : architecture is true;
attribute black_box_pad_pin of stub : architecture is "\out\,reset,\in\";
begin
end;
