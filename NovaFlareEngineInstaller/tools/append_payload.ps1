# ============================================================
#  append_payload.ps1
#  Appends a payload file to an exe (self-extracting style):
#    [exe][payload bytes]["NFPL0100"][u64 payload offset][u64 payload length]
#  usage: powershell -ExecutionPolicy Bypass -File append_payload.ps1 -Exe app.exe -Payload payload.rar
# ============================================================
param(
  [Parameter(Mandatory = $true)][string]$Exe,
  [Parameter(Mandatory = $true)][string]$Payload
)

$exePath = (Resolve-Path $Exe).Path
$payPath = (Resolve-Path $Payload).Path
$exeLen = (Get-Item $exePath).Length

$fs = [System.IO.File]::Open($exePath, [System.IO.FileMode]::Append)
try {
  $in = [System.IO.File]::OpenRead($payPath)
  try {
    $buf = New-Object byte[] (4 * 1024 * 1024)
    while ($true) {
      $n = $in.Read($buf, 0, $buf.Length)
      if ($n -le 0) { break }
      $fs.Write($buf, 0, $n)
    }
  } finally {
    $in.Dispose()
  }
  $magic = [System.Text.Encoding]::ASCII.GetBytes('NFPL0100')
  $fs.Write($magic, 0, $magic.Length)
  $off = [System.BitConverter]::GetBytes([uint64]$exeLen)
  $len = [System.BitConverter]::GetBytes([uint64](Get-Item $payPath).Length)
  $fs.Write($off, 0, 8)
  $fs.Write($len, 0, 8)
} finally {
  $fs.Dispose()
}
Write-Output ("appended {0} bytes to {1}" -f (Get-Item $payPath).Length, $exePath)
