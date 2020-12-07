# Laser Projector Preprocessor
#
# Used to turn arbitary images and video into laser trajectories, that are either sent over the network to a
# FPGA or stored locally as a CSV, PNG, or COE file.
#
# fischerm@mit.edu, Fall 2020


from sys import argv
import cv2
import numpy as np
import trajectory_planner as tp
import os
#import pandas as pd
from scapy.all import *

if len(argv) == 1:
    raise SystemExit("No options specified. Try 'laser.py -h' for more information.")

if '-h' in argv:
    print("""Usage: python3 laser.py [OPTION]
    -i      input source (required). path to file if source is a file, or number if webcam.
    -o      output destination. path to directory, but use -n for streaming to projector.
    -t      output file type. options include any combination of 'png' or 'csv' or 'coe'.
    -n      network address of the laser, if it's output is desired.

examples:
    python3 app/laser.py -i input.jpg -o output/ -n f0:0d:be:ef:ba:be
    python3 app/laser.py -i 0 -n f0:0d:be:ef:ba:be""")
    exit()

if '-i' not in argv:
    raise SystemExit("No input file specified, specify one with -i or run 'laser.py -h' for more information.")

if '-t' in argv and '-o' not in argv:
    raise SystemExit("Output type specified, but no output directory specified. Specify one with -o or run 'laser.py -h' for more information.")

#if '-o' not in argv and '-n' not in argv:
#    raise SystemExit("No output destination specified, specify one with -o or -n or run 'laser.py -h' for more information")

# Set capture to whatever was passed in with the -i option
#cv2.setUseOptimized(True) # no idea if this does anything but hahaa openCV go brrrrr
input_filename = argv[argv.index('-i') + 1]
try:
    source = int(input_filename)
except:
    source = input_filename

cap = cv2.VideoCapture(source)
if (cap.isOpened() == False):
    raise SystemExit(f"Error opening input file {input_filename}")


# Set output directory to whatever was passed in with the -o option
output_directory = argv[argv.index('-o') + 1] if '-o' in argv else None

# Set output type to whatever was passed in with the -t option
output_types = []
for arg in argv[argv.index('-t')+1:]:
    if len(arg) != 2 and '-' not in arg:
        output_types.append(arg)
    else:
        break

# Set network address to whatever was passed in with the -n option
network_address = argv[argv.index('-n') + 1] if '-n' in argv else None

def prep_frame(frame, desired_x_resolution, desired_y_resolution):
    # idea is that we can send a code to the DAC between 0 and 2*16 - 1
    # however we can take in inputs of arbitrary size and resolution, so to make
    # image processing not take forever we want to resize the image to some reasonable
    # resolution (like 512x512) and then run trajectory planning on that, and then
    # rescale afterwards to some desired image size

    # this function resizes the image so that it fits within a frame of specified size
    # it does preserve aspect ratio and doesn't add any bordering, so while
    # the x or y of the returned image will be at maximum, they both won't be unless
    # the image is already at the desired aspect ratio

    x_resolution = frame.shape[0]
    y_resolution = frame.shape[1]

    x_scale_factor = desired_x_resolution/x_resolution
    y_scale_factor = desired_y_resolution/y_resolution

    if x_scale_factor > y_scale_factor:
        return cv2.resize(frame, None, fx=y_scale_factor, fy=y_scale_factor)

    else:
        return cv2.resize(frame, None, fx=x_scale_factor, fy=x_scale_factor)

def save_png(path, image):
    files = [i for i in os.listdir(path) if '.png' in i]
    filename = f'{path}/{len(files)}.png'
    cv2.imwrite(filename, image)

def save_csv(path, trajectory):
    files = [i for i in os.listdir(path) if '.csv' in i]
    filename = f'{path}/{len(files)}.csv'
    pd.DataFrame(trajectory.astype(int)).to_csv(filename, header=False)

def zero_pad(input_str, length):
    return '0'*(length - len(input_str)) + input_str

def save_coe(path, trajectory):
    files = [i for i in os.listdir(path) if '.coe' in i]
    filename = f'{path}/{len(files)}.coe'

    output_lines = ['memory_initialization_radix=16;\n','memory_initialization_vector=\n']

    input_lines = trajectory.tolist()

    for input_line_number, input_line in enumerate(input_lines):
        x, y, r, g, b = [format(int(i), 'x') for i in input_line]

        if input_line_number == len(input_lines) - 1:
            output_lines.append( zero_pad(x, 4) + zero_pad(y, 4) + zero_pad(r, 2) + zero_pad(g,2) + zero_pad(b,2) + ';')

        else:
            output_lines.append( zero_pad(x, 4) + zero_pad(y, 4) + zero_pad(r, 2) + zero_pad(g,2) + zero_pad(b,2) + ',\n')

    with open(filename, 'w') as output_file:
        output_file.writelines(output_lines)

def save_traj(path, trajectory):
    files = [i for i in os.listdir(path) if '.traj' in i]
    filename = f'{path}/{len(files)}.traj'

    output_lines = []

    input_lines = trajectory.tolist()
    for input_line_number, input_line in enumerate(input_lines):
        x, y, r, g, b = [int(i) for i in input_line]

        control = '02' if input_line_number == len(input_lines) - 1 else '01'

        x = format(65535 - (x*128), 'x')
        y = format(65535 - (y*128), 'x') # mirror y because galvos are oriented wierdly
        r = format(r, 'x')
        g = format(g, 'x')
        b = format(b, 'x')

        output_lines.append(control + zero_pad(x, 4) + zero_pad(y, 4) + zero_pad(r, 2) + zero_pad(g,2) + zero_pad(b,2) + '\n')

    with open(filename, 'w') as output_file:
        output_file.writelines(output_lines)

def send_trajectory(trajectory, iface):
    input_lines = trajectory.tolist()
    packet_list = []

    # Packet format is as follows:
    # Control (1 byte) - either 0x01 for adding to framebuffer, or 0x02 to swap framebuffers. Other values are invalid.
    # x (2 bytes)
    # y (2 bytes)
    # r (1 byte)
    # g (1 byte)
    # b (1 byte)

    # Total: 8 bytes

    for input_line_number, input_line in enumerate(input_lines):
        x, y, r, g, b = [int(i) for i in input_line]

        control = '02' if input_line_number == len(input_lines) - 1 else '01'

        x = format(65535 - (x*128), 'x')
        y = format(65535 - (y*128), 'x') # mirror y because galvos are oriented wierdly
        r = format(r, 'x')
        g = format(g, 'x')
        b = format(b, 'x')

        data = control + zero_pad(x, 4) + zero_pad(y, 4) + zero_pad(r, 2) + zero_pad(g,2) + zero_pad(b,2)

        packet = Ether()
        packet.dst = "b8:27:eb:a4:30:73"
        packet.type = 0x1234
        packet = packet / bytes.fromhex(data)
        packet_list.append(packet)
        #print(control, x, y, r, g, b)
        #sendp(packet_list, iface=iface)
        #exit()
    sendpfast(packet_list[:-1:6] + [packet_list[-1]], pps = 1000, iface=iface)


while(cap.isOpened()):
    ret, frame = cap.read()
    frame = prep_frame(frame, 512, 512)
    if ret == True:
        # Canny filtering
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)        # Converting the image to grayscale.
        gray_filtered = cv2.bilateralFilter(gray, 7, 50, 50)  # Smoothing without removing edges.
        edges = cv2.Canny(gray, 30, 120)                      # Applying the canny filter
        edges_filtered = cv2.Canny(gray_filtered, 60, 120)

        # Trajectory Planning
        blur = cv2.blur(frame,(5,5))
        trajectory, degeneracies = tp.calculate_trajectory(edges_filtered)
        colorized_trajectory = tp.colorize_trajectory(blur, trajectory)
        rendered_trajectory = tp.draw_trajectory(np.zeros_like(frame), colorized_trajectory)

        # Stacking the images to print them together for comparison
        edges_filtered_colored = cv2.cvtColor(edges_filtered, cv2.COLOR_GRAY2BGR)
        #planned_colored = cv2.cvtColor(planned, cv2.COLOR_GRAY2BGR)
        images = np.hstack((frame, edges_filtered_colored, rendered_trajectory))


        # Save the frame if option specified
        if 'png' in output_types:
            save_png(output_directory, rendered_trajectory)

        if 'csv' in output_types:
            save_csv(output_directory, colorized_trajectory)

        if 'coe' in output_types:
            save_coe(output_directory, colorized_trajectory)

        if 'traj' in output_types:
            save_traj(output_directory, colorized_trajectory)

        # Write frame over the network if option specified
        if '-n' in argv:
            send_trajectory(colorized_trajectory, 'enx106530b80573')

        # Display the resulting frame
        cv2.imshow('Frame', images)

        if cv2.waitKey(25) & 0xFF == ord('q'): # Press Q to exit
            break

    else:
        break

cap.release()
cv2.destroyAllWindows()
