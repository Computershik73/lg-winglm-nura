"""Minimal QMI-over-QRTR client helpers (Python, no deps)."""
import select
import socket
import struct
import time

AF_QIPCRTR = 42
QRTR_PORT_CTRL = 0xFFFFFFFE
QRTR_TYPE_NEW_SERVER = 4
QRTR_TYPE_NEW_LOOKUP = 10


def lookup(service, timeout=3.0):
    """return (node, port) of the first server of a QMI service"""
    ctrl = socket.socket(AF_QIPCRTR, socket.SOCK_DGRAM)
    node = ctrl.getsockname()[0]
    ctrl.sendto(struct.pack('<IIIII', QRTR_TYPE_NEW_LOOKUP, service, 0, 0, 0) + bytes(12),
                (node, QRTR_PORT_CTRL))
    end = time.time() + timeout
    try:
        while time.time() < end:
            r, _, _ = select.select([ctrl], [], [], max(0, end - time.time()))
            if not r:
                break
            pkt, _ = ctrl.recvfrom(64)
            if len(pkt) < 20:
                continue
            cmd, svc, inst, nd, port = struct.unpack_from('<IIIII', pkt)
            if cmd == QRTR_TYPE_NEW_SERVER and svc == service and (nd or port):
                return (nd, port)
    finally:
        ctrl.close()
    raise RuntimeError('QMI service %d not found' % service)


def tlvs_parse(data):
    out = {}
    off = 0
    while off + 3 <= len(data):
        t, ln = struct.unpack_from('<BH', data, off)
        out[t] = data[off + 3:off + 3 + ln]
        off += 3 + ln
    return out


def tlv(t, payload):
    return struct.pack('<BH', t, len(payload)) + payload


class Client:
    def __init__(self, service, name=None):
        self.service = service
        self.name = name or str(service)
        self.addr = lookup(service)
        self.sock = socket.socket(AF_QIPCRTR, socket.SOCK_DGRAM)
        self.txn = 0
        self.indications = []

    def request(self, msg_id, tlv_bytes=b'', timeout=30.0):
        self.txn = (self.txn % 0xFFFF) + 1
        txn = self.txn
        self.sock.sendto(struct.pack('<BHHH', 0, txn, msg_id, len(tlv_bytes)) + tlv_bytes, self.addr)
        end = time.time() + timeout
        while time.time() < end:
            r, _, _ = select.select([self.sock], [], [], max(0, end - time.time()))
            if not r:
                break
            pkt, _ = self.sock.recvfrom(65536)
            if len(pkt) < 7:
                continue
            typ, rtxn, mid, ln = struct.unpack_from('<BHHH', pkt)
            body = tlvs_parse(pkt[7:7 + ln])
            if typ == 2 and rtxn == txn and mid == msg_id:
                res, err = struct.unpack_from('<HH', body.get(2, bytes(4)))
                return res, err, body
            if typ == 4:
                self.indications.append((mid, body))
        raise TimeoutError('%s msg %#x: no response' % (self.name, msg_id))

    def poll_indications(self, timeout=0.0):
        end = time.time() + timeout
        while True:
            r, _, _ = select.select([self.sock], [], [], max(0, end - time.time()))
            if not r:
                break
            pkt, _ = self.sock.recvfrom(65536)
            typ, rtxn, mid, ln = struct.unpack_from('<BHHH', pkt)
            if typ == 4:
                self.indications.append((mid, tlvs_parse(pkt[7:7 + ln])))
        ind, self.indications = self.indications, []
        return ind

    def close(self):
        self.sock.close()
