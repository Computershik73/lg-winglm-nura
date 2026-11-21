#!/usr/bin/env python3
# Send one QMI request (single uint32 TLV 0x01) to a QRTR service and print
# the response.  usage: qmivss.py SERVICE MSG_ID VALUE [HOLD_SECONDS]
import socket, struct, sys, time, subprocess

AF_QIPCRTR = 42
QRTR_PORT_CTRL = 0xfffffffe
QRTR_TYPE_NEW_LOOKUP = 10
QRTR_TYPE_NEW_SERVER = 4


def lookup(service):
    s = socket.socket(AF_QIPCRTR, socket.SOCK_DGRAM)
    node = s.getsockname()[0]
    s.sendto(struct.pack('<IIII', QRTR_TYPE_NEW_LOOKUP, service, 0, 0) + bytes(16),
             (node, QRTR_PORT_CTRL))
    s.settimeout(3)
    res = []
    try:
        while True:
            d, _ = s.recvfrom(64)
            t, svc, inst, n, p = struct.unpack_from('<IIIII', d)
            if t != QRTR_TYPE_NEW_SERVER or (svc == 0 and n == 0):
                break
            res.append((svc, inst, n, p))
    except socket.timeout:
        pass
    s.close()
    return res


def main():
    svc = int(sys.argv[1], 0)
    msg = int(sys.argv[2], 0)
    val = int(sys.argv[3], 0)
    hold = float(sys.argv[4]) if len(sys.argv) > 4 else 0
    srv = lookup(svc)
    print('servers:', srv)
    if not srv:
        sys.exit(1)
    _, inst, node, port = srv[0]
    s = socket.socket(AF_QIPCRTR, socket.SOCK_DGRAM)
    tlv = struct.pack('<BHI', 0x01, 4, val)
    pkt = struct.pack('<BHHH', 0, 1, msg, len(tlv)) + tlv
    s.sendto(pkt, (node, port))
    s.settimeout(5)
    t_end = time.time() + max(hold, 5)
    while time.time() < t_end:
        try:
            d, _ = s.recvfrom(4096)
        except socket.timeout:
            continue
        typ, txn, mid, ln = struct.unpack_from('<BHHH', d)
        print('rx type %d txn %d msg 0x%x len %d: %s' % (typ, txn, mid, ln, d[7:7 + 48].hex()))
        if typ == 2 and txn == 1 and hold == 0:
            break
    s.close()


main()
