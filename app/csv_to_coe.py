input_filename = 'output/0.csv'
output_filename = 'output/0.coe'

def zero_pad(input_str, length):
    return '0'*(length - len(input_str)) + input_str

with open(input_filename, 'r') as input_file:
    input_lines = input_file.readlines()

output_lines = ['memory_initialization_radix=16;\n','memory_initialization_vector=\n']

for input_line_number, input_line in enumerate(input_lines):
    i, x, y, r, g, b = [format(int(i), 'x') for i in input_line.split(',')]

    if input_line_number == len(input_lines) - 1:
        output_lines.append( zero_pad(x, 4) + zero_pad(y, 4) + zero_pad(r, 2) + zero_pad(g,2) + zero_pad(b,2) + ';')

    else:
        output_lines.append( zero_pad(x, 4) + zero_pad(y, 4) + zero_pad(r, 2) + zero_pad(g,2) + zero_pad(b,2) + ',\n')


with open(output_filename, 'w') as output_file:
    output_file.writelines(output_lines)