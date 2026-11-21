#!/bin/bash
set -e
K=$HOME/lg-winglm-nura/pmaports/device/testing/linux-lg-winglm
T=$(mktemp -d); mkdir -p $T/a/sound/soc $T/b/sound/soc
cp /home/user/winglm/kernel/sound/soc/soc-ops.c $T/a/sound/soc/; cp $T/a/sound/soc/soc-ops.c $T/b/sound/soc/
python3 - $T/b/sound/soc/soc-ops.c <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
old1 = "\tval = ucontrol->value.integer.value[0];\n\tif (mc->platform_max && val > mc->platform_max)\n\t\treturn -EINVAL;\n\tif (val > max)\n\t\treturn -EINVAL;\n\tif (val < 0)\n\t\treturn -EINVAL;\n\tval_mask = mask << shift;\n\tval = (val + min) & mask;"
new1 = old1.replace("\tif (val > max)\n", "\tif (val > max - min)\n")
old2 = "\t\tif (val2 > max)\n\t\t\treturn -EINVAL;\n\n\t\tval_mask = mask << rshift;\n\t\tval2 = (val2 + min) & mask;"
new2 = old2.replace("if (val2 > max)", "if (val2 > max - min)")
assert s.count(old1) == 1 and s.count(old2) == 1
s = s.replace(old1, new1).replace(old2, new2)
open(p, "w").write(s)
PY
cd $T
{
cat <<'H'
From: winglm port
Subject: [PATCH] ASoC: ops: fix the bounds check of _sx controls

The values of an _sx control go from 0 to max - min (what info reports,
0..124 for the WCD/bolero digital gains declared with -84, 40), but put
rejected everything above max (40): only -84..-44 dB could be set, 0 dB
not at all. Same fix as upstream 698813ba8c58 ("ASoC: ops: Fix bounds
check for _sx controls").
---
H
diff -u a/sound/soc/soc-ops.c b/sound/soc/soc-ops.c || true
} > $K/0005-asoc-ops-fix-bounds-check-for-sx-controls.patch
grep -c "^[-+]	" $K/0005-asoc-ops-fix-bounds-check-for-sx-controls.patch
