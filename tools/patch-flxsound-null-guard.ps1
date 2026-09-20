# NovaFlare Engine - FlxSound.updateTransform() null-pointer crash fix patch
#
# Crash evidence (novaflare-native-crash-v1 native crash log):
#   SIGSEGV / fault_address=0x30, faulting instruction `str d0, [x8, #0x30]`, x8 == NULL.
#   Offline reverse engineering identified the crashing function as
#   flixel::sound::FlxSound_obj::updateTransform(); x8 came from this->_transform
#   (object offset +0xd8), i.e. `_transform.volume = ...` executed while _transform == null
#   (SoundTransform.volume lives at +0x30).
#
#   Call chain: Lua playSound / setSoundVolume -> FunkinLua closure -> SoundFrontEnd.play
#               -> FlxSound.set_volume -> FlxSound.updateTransform  (crash site)
#
#   Root cause: _transform is only ever set to null in FlxSound.destroy(). But
#   SoundFrontEnd.destroy() (called on every state switch via FlxGame.hx:715
#   FlxG.sound.destroy()) destroys the sounds in FlxG.sound.list WITHOUT removing them
#   from the list, so list.recycle() later reuses these already-destroyed instances, and
#   Lua may still hold references. Any updateTransform() call then dereferences null.
#   Note: funkin.audio.FunkinSound overrides updateTransform() WITH a null check, so only
#   plain FlxSound / FlxStreamSound instances crash this way.
#
# Usage:
#   powershell -File tools\patch-flxsound-null-guard.ps1 -Status   # show state
#   powershell -File tools\patch-flxsound-null-guard.ps1 -Apply    # apply fix
#   powershell -File tools\patch-flxsound-null-guard.ps1 -Revert   # revert fix
#
# IMPORTANT: dependencies/ and .haxelib/ are listed in .gitignore, so the flixel change
#            is NOT tracked by git. After a fresh clone, `hmm install`, or a machine
#            change you MUST re-run -Apply before building.

[CmdletBinding()]
param(
  [switch]$Apply,
  [switch]$Revert,
  [switch]$Status
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$candidates = @(
  (Join-Path $projectRoot 'dependencies\flixel-5.9.0-main\flixel\sound\FlxSound.hx'),
  (Join-Path $projectRoot '.haxelib\flixel\5,9,0\flixel\sound\FlxSound.hx'),
  (Join-Path $projectRoot '.haxelib\flixel\6,1,2\flixel\sound\FlxSound.hx')
)

function Get-TargetPath {
  foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { return $c } }
  throw ("FlxSound.hx not found. Tried:" + [Environment]::NewLine + ($candidates -join [Environment]::NewLine))
}

# UTF-8 (no BOM) read/write so that non-ASCII comments elsewhere in the file survive.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Read-Text([string]$p) { return [System.IO.File]::ReadAllText($p, $utf8NoBom) }
function Write-Text([string]$p, [string]$t) { [System.IO.File]::WriteAllText($p, $t, $utf8NoBom) }

$guardMark = 'if (_transform == null)'
# Matches: indent + "function updateTransform():Void" + EOL + indent + "{" + EOL
$funcRx = [regex]'(?m)^([ \t]*)function updateTransform\(\):Void[ \t]*\r?\n([ \t]*)\{[ \t]*\r?\n'
# TRUE patch marker: the guard must sit at the very top of updateTransform()'s body.
# (Do NOT test for the bare string "_transform == null": FlxSound.hx already contains
#  that text elsewhere, e.g. in loadEmbedded/reset, which made detection unreliable.)
$appliedRx = [regex]'(?m)^[ \t]*function updateTransform\(\):Void[ \t]*\r?\n[ \t]*\{[ \t]*\r?\n[ \t]*// NovaFlare fix:'
# Matches the whole inserted patch block (6 comment lines + if + return + blank line)
$blockRx = [regex]'(?m)^[ \t]*// NovaFlare fix:.*\r?\n(?:[ \t]*//.*\r?\n)*[ \t]*if \(_transform == null\)\r?\n[ \t]*return;\r?\n\r?\n'
function Test-Applied([string]$t) { return $appliedRx.IsMatch($t) }

$target = Get-TargetPath

# ---- default / -Status ----
if ($Status -or (-not $Apply -and -not $Revert)) {
  $text = Read-Text $target
  Write-Host "File  : $target"
  if (Test-Applied $text) {
    Write-Host "Status: FIXED (null guard present)" -ForegroundColor Green
  } else {
    Write-Host "Status: NOT FIXED (updateTransform lacks null guard -> crashes)" -ForegroundColor Yellow
  }
  exit 0
}

# ---- -Revert ----
if ($Revert) {
  $text = Read-Text $target
  if (-not (Test-Applied $text)) { Write-Host "Already unpatched, nothing to revert."; exit 0 }
  $new = $blockRx.Replace($text, '', 1)
  if ($new -eq $text) { throw "Revert failed: patch block not matched. Please revert manually." }
  Write-Text $target $new
  Write-Host "Reverted: $target" -ForegroundColor Yellow
  exit 0
}

# ---- -Apply ----
if ($Apply) {
  $text = Read-Text $target
  if (Test-Applied $text) { Write-Host "Already patched, nothing to do." -ForegroundColor Green; exit 0 }

  $m = $funcRx.Match($text)
  if (-not $m.Success) { throw "Anchor 'function updateTransform():Void' not found. flixel source may have changed; patch manually." }

  $nl       = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
  $indent   = $m.Groups[1].Value     # indentation of "function ..."
  $bodyInd  = $m.Groups[2].Value     # indentation of "{"
  $lvl1     = $bodyInd + "`t"

  $block = @(
    ($indent + '// NovaFlare fix: destroy() sets _transform to null, but SoundFrontEnd.destroy()'),
    ($indent + '// leaves those destroyed instances inside FlxG.sound.list, so list.recycle() may'),
    ($indent + '// reuse them and Lua may still hold references. Dereferencing _transform then'),
    ($indent + '// writes to NULL+0x30 and raises a native SIGSEGV (fault_address=0x30).'),
    ($indent + '// Return defensively here; do NOT recreate _transform, so the destroyed state'),
    ($indent + '// stays visible instead of being masked.'),
    ($bodyInd + 'if (_transform == null)'),
    ($lvl1 + 'return;'),
    ''
  ) -join $nl

  $insertAt = $m.Index + $m.Length
  $new = $text.Substring(0, $insertAt) + $block + $nl + $text.Substring($insertAt)
  Write-Text $target $new
  Write-Host "Patched: $target" -ForegroundColor Green
  Write-Host "Now rebuild both exports:"
  Write-Host "  haxelib run lime build windows -release -D legacy_gc_compare"
  Write-Host "  haxelib run lime build android -D legacy_gc_compare"
  exit 0
}
