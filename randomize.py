import random
import sys

def randomize(
    in_file,
    out_file):
    # Read in list and populate array
    dirs = []
    i = open(in_file, 'r')
    for line in i:
        dirs.append(line)
    # Randomize order
    random.shuffle(dirs)
    # Write to output file
    o_clear = open(out_file, 'w')
    o_clear.write("")
    o = open(out_file, 'a')
    for elem in dirs:
        o.write(elem)
    # Cleanup
    i.close()
    o.close()

if __name__ == "__main__":
    in_file = sys.argv[1]
    out_file = sys.argv[2]
    randomize(
        in_file,
        out_file
    )
