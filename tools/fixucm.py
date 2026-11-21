import sys
for p in sys.argv[1:]:
    lines = open(p, newline='').read().split('\n')
    out = []
    for l in lines:
        if "name='EAR PA GAIN'" in l:
            l = '\t\tcset "name=\'EAR PA GAIN\' G_0_DB"'
        out.append(l)
    open(p, 'w', newline='').write('\n'.join(out))
    print(p, sum(1 for l in out if 'EAR PA GAIN' in l))
