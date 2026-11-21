#!/bin/sh
grep -E ":rfc[^:]*\.(c|cpp):" /tmp/qdb.txt | grep -iE "hwid|hw_id|fsid|eeprom|factory|proff|card_config|override|1878" | cut -d: -f2- | cut -c1-200 | head -60
