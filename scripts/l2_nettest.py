#!/usr/bin/python3
# Dumb L2 testing script.
# Useful to verify that the host Ethernet
# controller is picking up everything correctly.
#
# The "suggested ILAs" in the networking stack
# will help with this role on the TX side, and
# also help with less coarse-grained debug techniques.
#
# Head over to Wireshark and check that every sent
# packet has an ACK to verify the configuration. Pls
# run as root

from scapy.all import *;

src_mac = "2c:f0:5d:04:22:10"
dst_mac = "b8:27:eb:a4:30:73"
ifc = "enp70s0"

############

echosvc_etype = 0x1234

mypkt = Ether()
mypkt.src = src_mac
mypkt.dst = dst_mac
mypkt.type = 0x1234

mypkt = mypkt / "a"
for i in range(200):
    mypkt.load = "a" * i
    sendp(mypkt, iface=ifc)
