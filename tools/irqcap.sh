#!/bin/sh
# Print total counts of touch/key related interrupts, wait, print again.
secs="${1:-20}"
snap() {
	grep -iE 'touch|sw42|gpio.keys|volume|pon|qupv3|i2c|spi' /proc/interrupts |
		awk '{s=0; for (i = 2; i <= 9; i++) s += $i; $2=$3=$4=$5=$6=$7=$8=$9=""; print s, $0}' |
		tr -s ' ' | cut -c1-120
}
snap > /tmp/irq_before.txt
sleep "$secs"
snap > /tmp/irq_after.txt
echo "count_before -> count_after : irq"
paste -d'|' /tmp/irq_before.txt /tmp/irq_after.txt |
	awk -F'|' '{split($1, a, " "); split($2, b, " "); d = b[1] - a[1];
		printf "%8d -> %8d %s%s\n", a[1], b[1], (d > 0 ? "[+" d "] " : ""), substr($2, length(b[1]) + 2)}'
