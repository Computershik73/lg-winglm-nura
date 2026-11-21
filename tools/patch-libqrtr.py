import sys, os
p = os.path.join(sys.argv[1], "lib/qrtr.c")
s = open(p).read()
old = '''	if (qrtr_getname(sock, &sq))
		return -1;

	memset(&pkt, 0, sizeof(pkt));

	pkt.cmd = cpu_to_le32(QRTR_TYPE_NEW_SERVER);
	pkt.server.service = cpu_to_le32(service);
	pkt.server.instance = cpu_to_le32(instance << 8 | version);

	return qrtr_sendto(sock, sq.sq_node, QRTR_PORT_CTRL, &pkt, sizeof(pkt));'''
new = '''	if (qrtr_getname(sock, &sq))
		return -1;

	/* Get our port now: the announcement below carries it */
	if (sq.sq_port == 0) {
		sq.sq_family = AF_QIPCRTR;
		if (bind(sock, (struct sockaddr *)&sq, sizeof(sq)) < 0 ||
		    qrtr_getname(sock, &sq))
			return -1;
	}

	memset(&pkt, 0, sizeof(pkt));

	pkt.cmd = cpu_to_le32(QRTR_TYPE_NEW_SERVER);
	pkt.server.service = cpu_to_le32(service);
	pkt.server.instance = cpu_to_le32(instance << 8 | version);
	/*
	 * Name the server's node and port: downstream (CAF) kernels drop a
	 * NEW_SERVER for "node 0" once a remote node 0 (the modem) exists
	 * as not forwardable, so services registered after the modem came up
	 * were never seen.
	 */
	pkt.server.node = cpu_to_le32(sq.sq_node);
	pkt.server.port = cpu_to_le32(sq.sq_port);

	return qrtr_sendto(sock, sq.sq_node, QRTR_PORT_CTRL, &pkt, sizeof(pkt));'''
assert s.count(old) == 1, "anchor"
s = s.replace(old, new)
open(p, "w").write(s)
print("patched libqrtr")
