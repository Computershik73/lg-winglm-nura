#!/bin/sh
grep -aE ":(MMPF[A-Za-z_]*|LRtp[A-Za-z_]*|MMPFNode[A-Za-z_]*)\.(cpp|c):" /tmp/qdb.txt | grep -aiE "socket|SockPos|network|ip addr|ipaddr|iface|netpolicy|dss|profile|bind|port" | cut -d: -f5- | cut -c1-200 | sort -u | head -120
