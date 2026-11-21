import os, struct, sys
# like the shell's Bluetooth switch (gsd-rfkill): RFKILL_OP_CHANGE_ALL for type bluetooth
block = sys.argv[1] == "block"
fd = os.open("/dev/rfkill", os.O_RDWR)
os.write(fd, struct.pack("IBBBB", 0, 2, 3, 1 if block else 0, 0))  # idx, type=BLUETOOTH, op=CHANGE_ALL, soft, hard
os.close(fd)
