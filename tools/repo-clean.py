#!/usr/bin/python3
"""Make ~/lg-wing-port/tools independent of this machine's paths."""
import os
import re
import subprocess

R = os.path.expanduser('~/lg-wing-port')
SCRATCHPAD = '$HOME/lg-wing-port/tools'
SCRATCH_ROOT = ('/mnt/c/MICD/profiles/d19bc6bc-1286-4caf-9fe1-c0fc5c4175a3/scratch-workspaces/'
                '7f4c33e3-713d-4694-9eaa-57d6e1528aa0/4559bdd3-f3f8-4a6b-afb9-1e62cbd0b548/'
                'scratch-2026-11-13-581527')

files = subprocess.run(['git', 'grep', '-lI', '-e', SCRATCHPAD, '-e', SCRATCH_ROOT, '--', 'tools'],
                       cwd=R, capture_output=True, text=True).stdout.split()
for f in files:
    p = os.path.join(R, f)
    s = open(p).read()
    if f.endswith('.py'):
        s = s.replace("open('%s/elfx.py')" % SCRATCHPAD,
                      "open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'elfx.py'))")
        if 'import os' not in s:
            s = s.replace('import sys', 'import os\nimport sys', 1)
    s = s.replace(SCRATCHPAD, '$HOME/lg-wing-port/tools')
    s = s.replace(SCRATCH_ROOT, '$HOME/lg-wing-port')
    open(p, 'w').write(s)
    print('cleaned', f)

# EDL restore: machine-specific locations become parameters
p = os.path.join(R, 'tools/edl-restore.ps1')
s = open(p).read()
s = s.replace("$ErrorActionPreference = 'Stop'\n",
              "# usage: edl-restore.ps1 -Prog <prog_ufs_firehose_sm7250_lge.elf> -Out <dir with boot image>"
              " -Gpt <dir with the fh_gpt_* dumps of your QFIL backup>\n"
              "param([Parameter(Mandatory)] [string]$Prog, [Parameter(Mandatory)] [string]$Out,"
              " [Parameter(Mandatory)] [string]$Gpt)\n"
              "$ErrorActionPreference = 'Stop'\n", 1)
s = re.sub(r"\$prog = '[^']*'", "$prog = $Prog", s)
s = re.sub(r"\$O = '[^']*'", "$O = $Out", s)
s = re.sub(r"\$G = '[^']*'", "$G = $Gpt", s)
open(p, 'w').write(s)
print('parametrized tools/edl-restore.ps1')
left = subprocess.run(['git', 'grep', '-nIE', r'scratchpad/|scratch-2026|C:.Users.User', '--', 'tools'],
                      cwd=R, capture_output=True, text=True).stdout
print('left:', left or 'none')
