import sys, subprocess
sys.argv = [sys.argv[0], sys.argv[1], '-', 'noop'] + sys.argv[2:]
exec(open('/mnt/c/Users/User/AppData/Local/Temp/claude/09dffbddec4c1633/dd1f1da9-6870-4ea2-9c9e-29465f940410/scratchpad/elfx.py').read().split("if sys.argv[2] == '-':")[0])
want = sys.argv[4]
addr = {n: v for n, v in syms.values()}
byaddr = {}
for n, v in syms.values():
    if v:
        byaddr.setdefault(v, n)
va = addr[want]
names = subprocess.run(['c++filt'], input='\n'.join(byaddr.values()), capture_output=True, text=True).stdout.split('\n')
dem = dict(zip(byaddr.values(), names))
for i in range(2, 60):
    v = u64(va + 8 * i)
    n = byaddr.get(v, '') if isinstance(v, int) else v
    print('%4d %s %s' % ((i - 2) * 8, hex(v) if isinstance(v, int) else v, dem.get(n, n)))
