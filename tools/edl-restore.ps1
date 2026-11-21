# Restore boot_a (LUN4 @ sector 67974) from pmos-out\boot-r4.img over EDL.
# usage: edl-restore.ps1 -Prog <prog_ufs_firehose_sm7250_lge.elf> -Out <dir with boot image> -Gpt <dir with the fh_gpt_* dumps of your QFIL backup>
param([Parameter(Mandatory)] [string]$Prog, [Parameter(Mandatory)] [string]$Out, [Parameter(Mandatory)] [string]$Gpt)
$ErrorActionPreference = 'Stop'
$qpst = 'C:\Program Files (x86)\Qualcomm\QPST\bin'
$fh = "$qpst\fh_loader.exe"
$sahara = "$qpst\QSaharaServer.exe"
$prog = $Prog
$O = $Out
$W = "$O\edl"
$G = $Gpt
$img = 'boot-r4.img'
$exp = '4AADBD717180AE207E7B9F9BD7C82EB76112F04CF1A658532B521638D238A76B'

New-Item -ItemType Directory -Force $W | Out-Null
Set-Location $W
$h = (Get-FileHash "$O\$img").Hash
if ($h -ne $exp) { "ABORT: image hash $h"; exit 1 }
$sectors = [int]((Get-Item "$O\$img").Length / 4096)
"image OK, $sectors sectors"

$dev = Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match 'VID_05C6&PID_9008' }
if (-not $dev) { 'NO EDL DEVICE'; exit 1 }
$com = [regex]::Match($dev.FriendlyName, 'COM\d+').Value
"port=$com"

# load the firehose programmer (Sahara); harmless if it is already running
$s = & $sahara -p "\\.\$com" -s "13:$prog" 2>&1
($s | Select-String -Pattern 'Sahara protocol completed|ERROR|failed' | Select-Object -First 3) -join "`n"
Start-Sleep -Seconds 2

$common = @("--port=\\.\$com", '--memoryname=ufs', '--noprompt', '--zlpawarehost=1')

Remove-Item -ErrorAction SilentlyContinue "$W\chk_gpt4.bin"
& $fh @common --convertprogram2read --sendimage=chk_gpt4.bin --lun=4 --start_sector=1 --num_sectors=1 2>&1 | Out-Null
$a = (Get-FileHash "$W\chk_gpt4.bin" -ErrorAction SilentlyContinue).Hash
$b = (Get-FileHash "$G\fh_gpt_header_4").Hash
if ($a -ne $b) { "ABORT: LUN4 GPT mismatch ($a)"; exit 1 }
'LUN4 GPT OK'

$out = & $fh @common "--search_path=$O" "--sendimage=$img" --lun=4 --start_sector=67974 2>&1
($out | Select-String -Pattern '<program>|SUCCESS|ERROR' | Select-Object -Last 3) -join "`n"

Remove-Item -ErrorAction SilentlyContinue "$W\rb_boot.bin"
& $fh @common --convertprogram2read --sendimage=rb_boot.bin --lun=4 --start_sector=67974 "--num_sectors=$sectors" 2>&1 | Out-Null
$rb = (Get-FileHash "$W\rb_boot.bin").Hash
if ($rb -ne $exp) { "VERIFY FAILED: $rb"; exit 1 }
'boot_a VERIFY OK'

& $fh @common --reset 2>&1 | Out-Null
'reset sent'
