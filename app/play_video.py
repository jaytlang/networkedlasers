from sys import argv
from os import listdir
from scapy.all import *
import _pickle as pickle

# find files to load
if len(argv) == 1:
    raise SystemExit("No input directory specified.")

path = argv[1] if argv[1][-1] == '/' else argv[1] + '/'
files = [i for i in listdir(path) if i.endswith('.traj')]  

num = lambda name: int(name.split('.')[0]) 

files = sorted(files, key=num)

#s = conf.L2socket(iface='enx106530b80573')

# read all files into memory (yes this is bad but I'm just doing some testing here)
'''data = []
for filename in files:
    with open(path + filename, 'r') as file:
        data.append(file.readlines())

packet_list = []
for data_block in data:
    
    for input_line in data_block:
        packet = Ether()
        packet.dst = "b8:27:eb:a4:30:73"
        packet.type = 0x1234
        packet = packet / bytes.fromhex(input_line)
        packet_list.append(packet)

pickle.dump(packet_list, open( "app/save.pkl", "wb" ) )'''

packet_list = pickle.load(open('app/save.pkl', 'rb'))

while True:
    print(sendpfast(packet_list, pps = 500000, iface='enx106530b80573', parse_results=1))