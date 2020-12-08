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

parameter ETH_IPV4_ETYPE_1 = 8'h08;
parameter ETH_IPV4_ETYPE_2 = 8'h00;

parameter ETH_MYADDR_1 = 8'hb8;
parameter ETH_MYADDR_2 = 8'h27;
parameter ETH_MYADDR_3 = 8'heb;
parameter ETH_MYADDR_4 = 8'ha4;
parameter ETH_MYADDR_5 = 8'h30;
parameter ETH_MYADDR_6 = 8'h73;

// IPv4 header
parameter IPV4_VSN_IHL = 0 + ETH_DATA_START;
parameter IPV4_VSN_TOP = 3;
parameter IPV4_VSN_BOT = 0;
parameter IPV4_IHL_TOP = 7;
parameter IPV4_IHL_BOT = 4;

parameter IPV4_TOS = 1 + ETH_DATA_START;
parameter IPV4_LEN_MIN = 2 + ETH_DATA_START;
parameter IPV4_LEN_MAX = 3 + ETH_DATA_START;
parameter IPV4_FIDX_MIN = 4 + ETH_DATA_START;
parameter IPV4_FIDX_MAX = 5 + ETH_DATA_START;

parameter IPV4_FLAGS_STARTOF = 6 + ETH_DATA_START;
parameter IPV4_FLAGS_DNF_OFFSET = 1;

parameter IPV4_FOFFSET_ROUGHMIN = 6 + ETH_DATA_START;
parameter IPV4_FOFFSET_MAX = 7 + ETH_DATA_START;
parameter IPV4_TTL = 8 + ETH_DATA_START;
parameter IPV4_PROTOCOL = 9 + ETH_DATA_START;
parameter IPV4_CSUM_MIN = 10 + ETH_DATA_START;
parameter IPV4_CSUM_MAX = 11 + ETH_DATA_START;

parameter IPV4_SRCADDR_1 = 12 + ETH_DATA_START;
parameter IPV4_SRCADDR_2 = 13 + ETH_DATA_START;
parameter IPV4_SRCADDR_3 = 14 + ETH_DATA_START;
parameter IPV4_SRCADDR_4 = 15 + ETH_DATA_START;

parameter IPV4_DSTADDR_1 = 16 + ETH_DATA_START;
parameter IPV4_DSTADDR_2 = 17 + ETH_DATA_START;
parameter IPV4_DSTADDR_3 = 18 + ETH_DATA_START;
parameter IPV4_DSTADDR_4 = 19 + ETH_DATA_START;

// IPv4 offsets
parameter IPV4_ADDRSZ = 8'h04;
parameter IPV4_DATA_START = 20 + ETH_DATA_START;

// IPv4 parameters
parameter IPV4_MYADDR_1 = 8'h0a;
parameter IPV4_MYADDR_2 = 8'h00;
parameter IPV4_MYADDR_3 = 8'h00;
parameter IPV4_MYADDR_4 = 8'h04;

parameter IPV4_UDP_PROTO = 8'h17;

// UDP over IP header
parameter UDP_SPORT_MIN = 0 + IPV4_DATA_START;
parameter UDP_SPORT_MAX = 1 + IPV4_DATA_START;
parameter UDP_DPORT_MIN = 2 + IPV4_DATA_START;
parameter UDP_DPORT_MAX = 3 + IPV4_DATA_START;
parameter UDP_PKTLEN_MIN = 4 + IPV4_DATA_START;
parameter UDP_PKTLEN_MAX = 5 + IPV4_DATA_START;
parameter UDP_DATA_START = 8 + IPV4_DATA_START;

// UDP parameters
parameter UDP_MYPORT_1 = 8'hA4;
parameter UDP_MYPORT_2 = 8'h55;

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
parameter ARP_ETH_HTYPE_1 = 8'h00;
parameter ARP_ETH_HTYPE_2 = 8'h01;
parameter ARP_IPV4_PTYPE_1 = 8'h08;
parameter ARP_IPV4_PTYPE_2 = 8'h00;
parameter ARP_ETH_HLEN = ETH_ADDRSZ;
parameter ARP_IPV4_PLEN = IPV4_ADDRSZ;

parameter ARP_HDR_END = ARP_TPA_MAX;

parameter ARP_OPCODE_REQ = 8'h01;
parameter ARP_OPCODE_RESP = 8'h02;
parameter ARP_OPCODE_UPPER = 8'h00;
