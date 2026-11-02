<#
.SYNOPSIS
  Google 日本語入力にキー設定（カスタムキーマップ）を登録する。

.DESCRIPTION
  Google 日本語入力にはキーマップを取り込むコマンドがないため、設定ファイル
  %USERPROFILE%\AppData\LocalLow\Google\Google Japanese Input\config1.db（protobuf）の
    field 41: session_keymap      = 0 (CUSTOM)
    field 42: custom_keymap_table = キーマップ（プロパティの「エクスポート」と同じ TSV）
  だけを書き換える。他の設定はそのまま残す。
  変更があるときは config1.db をバックアップし、Google IME の常駐プロセスを止めてから書き込む
  （プロセスは次に IME を使ったときに自動で起動し、新しい設定を読み込む）。

.EXAMPLE
  .\windows\google-ime-keymap.ps1
  .\windows\google-ime-keymap.ps1 -KeymapFile C:\Users\me\Downloads\keymap.txt
#>
[CmdletBinding()]
param(
  # 省略時はリポジトリの config\windows\google-ime-keymap.txt
  [string]$KeymapFile
)

$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 を -File で起動すると、param の既定値の評価時点では $PSScriptRoot が空なので本体で決める
if (-not $KeymapFile) {
  $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
  $KeymapFile = Join-Path (Split-Path -Parent $scriptDir) 'config\windows\google-ime-keymap.txt'
}

$FieldKeymapType  = 41
$FieldKeymapTable = 42

function Read-Varint([byte[]]$Bytes, [ref]$Pos) {
  [uint64]$value = 0; $shift = 0
  while ($true) {
    $b = $Bytes[$Pos.Value]; $Pos.Value++
    $value = $value -bor ([uint64]($b -band 0x7f) -shl $shift)
    if ($b -lt 0x80) { return $value }
    $shift += 7
  }
}

function Write-Varint([System.IO.MemoryStream]$Stream, [uint64]$Value) {
  do {
    $b = [byte]($Value -band 0x7f)
    $Value = $Value -shr 7
    if ($Value -ne 0) { $b = $b -bor 0x80 }
    $Stream.WriteByte($b)
  } while ($Value -ne 0)
}

# protobuf のトップレベルを (field, wireType, 生バイト列) の一覧に分解する
function Split-Protobuf([byte[]]$Bytes) {
  $fields = New-Object System.Collections.ArrayList
  $pos = 0
  while ($pos -lt $Bytes.Length) {
    $start = $pos
    $tag = Read-Varint $Bytes ([ref]$pos)
    $wire = [int]($tag -band 7)
    switch ($wire) {
      0 { [void](Read-Varint $Bytes ([ref]$pos)) }
      1 { $pos += 8 }
      2 { $len = Read-Varint $Bytes ([ref]$pos); $pos += [int]$len }
      5 { $pos += 4 }
      default { throw "config1.db を解析できません（wire type $wire）" }
    }
    $raw = New-Object byte[] ($pos - $start)
    [Array]::Copy($Bytes, $start, $raw, 0, $raw.Length)
    [void]$fields.Add([pscustomobject]@{ Field = [int]($tag -shr 3); Raw = $raw })
  }
  return , $fields
}

function New-Field([int]$Field, [int]$Wire, $Value) {
  $ms = New-Object System.IO.MemoryStream
  Write-Varint $ms ([uint64](($Field -shl 3) -bor $Wire))
  if ($Wire -eq 0) {
    Write-Varint $ms ([uint64]$Value)
  } else {
    Write-Varint $ms ([uint64]$Value.Length)
    $ms.Write($Value, 0, $Value.Length)
  }
  return [pscustomobject]@{ Field = $Field; Raw = $ms.ToArray() }
}

# --- キーマップを読む（CRLF/LF どちらでも可。末尾の改行は付けない） ---
if (-not (Test-Path $KeymapFile)) { throw "キーマップが見つかりません: $KeymapFile" }
$text = ([IO.File]::ReadAllText($KeymapFile) -replace "`r`n", "`n").TrimEnd("`n")
if (-not $text.StartsWith("status`tkey`tcommand")) {
  throw "Google 日本語入力のキーマップ（status<TAB>key<TAB>command で始まる TSV）ではありません: $KeymapFile"
}
$table = [Text.Encoding]::UTF8.GetBytes($text)

# --- config1.db を書き換える ---
$configDir = Join-Path $env:USERPROFILE 'AppData\LocalLow\Google\Google Japanese Input'
$configDb  = Join-Path $configDir 'config1.db'

$fields = New-Object System.Collections.ArrayList
if (Test-Path $configDb) {
  $fields = Split-Protobuf ([IO.File]::ReadAllBytes($configDb))
} else {
  # 一度も起動していない場合。省略した項目は Google IME が既定値で補う
  New-Item -ItemType Directory -Force -Path $configDir | Out-Null
}
$before = if (Test-Path $configDb) { [IO.File]::ReadAllBytes($configDb) } else { New-Object byte[] 0 }

$rest = @($fields | Where-Object { $_.Field -ne $FieldKeymapType -and $_.Field -ne $FieldKeymapTable })
$new = @($rest | Where-Object { $_.Field -lt $FieldKeymapType }) +
       @((New-Field $FieldKeymapType 0 0), (New-Field $FieldKeymapTable 2 $table)) +
       @($rest | Where-Object { $_.Field -gt $FieldKeymapTable })
$ms = New-Object System.IO.MemoryStream
foreach ($f in $new) { $ms.Write($f.Raw, 0, $f.Raw.Length) }
$after = $ms.ToArray()

if ([Convert]::ToBase64String($before) -eq [Convert]::ToBase64String($after)) {
  Write-Host 'Google 日本語入力のキー設定は登録済みです（変更なし）'
  return
}

# 常駐プロセスが古い設定で上書きしないよう止める（次に IME を使うと自動で起動する）
Get-Process -Name GoogleIMEJaConverter, GoogleIMEJaRenderer -ErrorAction SilentlyContinue |
  Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

if ($before.Length -gt 0) {
  $backup = "$configDb.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
  Copy-Item $configDb $backup
  Write-Host "バックアップ: $backup"
}
[IO.File]::WriteAllBytes($configDb, $after)
Write-Host "Google 日本語入力にキー設定を登録しました: $KeymapFile"
Write-Host '（反映されないときは、一度サインアウトするか、アプリを開き直してください）'
