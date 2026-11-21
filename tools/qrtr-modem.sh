#!/bin/sh
qrtr-lookup | awk 'NR==1 || $4 == 0'
