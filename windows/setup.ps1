<#
.SYNOPSIS
  Windows 側から WSL (Ubuntu) の開発環境をセットアップする。

.DESCRIPTION
  1. WSL ディストリビューションを確認する（なければ wsl --install）
  2. VS Code と WSL 拡張を winget でインストールする（Windows 側）
  3. このリポジトリを WSL 内（既定 ~/config_file）にコピーする（注入）
  4. wsl -u root で install.sh --system-only を実行する
     （apt / mise / wsl.conf / ログインシェル。sudo のパスワードは不要）
  5. 既定ユーザーで install.sh --user-only を実行する
     （設定のリンク / mise のツール / git のユーザー情報 / Claude Code・Codex）
  6. /etc/wsl.conf が変わっていれば、ディストリビューションの再起動を確認する

.EXAMPLE
  .\windows\setup.cmd
  .\windows\setup.ps1 -Distro Ubuntu-26.04 -GitName "Taro" -GitEmail "taro@example.com"
#>
[CmdletBinding()]
param(
  # 対象の WSL ディストリビューション名（wsl -l -v で確認できる名前）。省略時は既定のディストリビューション
  [string]$Distro,
  # ディストリビューションが 1 つもないときにインストールするもの
  [string]$InstallDistro = 'Ubuntu',
  # WSL 内のコピー先。相対パスならホームディレクトリ基準
  [string]$Target = 'config_file',
  [string]$GitName,
  [string]$GitEmail,
  # 確認せずに進める
  [switch]$Yes,
  [switch]$SkipVSCode,
  [switch]$SkipAI,
  # 最後に WSL を再起動しない
  [switch]$NoRestart
)

$ErrorActionPreference = 'Stop'
$env:WSL_UTF8 = '1'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$RepoRoot = Split-Path -Parent $PSScriptRoot

function Write-Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Info([string]$Message) { Write-Host "    $Message" }
function Write-Warn([string]$Message) { Write-Host "warn: $Message" -ForegroundColor Yellow }

function Confirm-Step([string]$Question) {
  if ($Yes) { return $true }
  return (Read-Host "$Question [y/N]") -match '^[Yy]'
}

# WSL 内でコマンドを実行する。失敗したら例外
function Invoke-Wsl {
  param([string]$User, [string[]]$Command, [switch]$Capture)
  $wslArgs = @('-d', $Distro)
  if ($User) { $wslArgs += @('-u', $User) }
  $wslArgs += @('--cd', '~', '-e') + $Command
  if ($Capture) {
    $out = & wsl.exe @wslArgs
  } else {
    & wsl.exe @wslArgs
  }
  if ($LASTEXITCODE -ne 0) {
    throw "WSL でのコマンドが失敗しました (exit $LASTEXITCODE): $($Command -join ' ')"
  }
  if ($Capture) { return $out }
}

function Get-Distros {
  $list = & wsl.exe -l -q 2>$null
  if ($LASTEXITCODE -ne 0) { return @() }
  return @($list | ForEach-Object { ($_ -replace "`0", '').Trim() } | Where-Object { $_ })
}

function Find-VSCode {
  @(
    (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd'),
    (Join-Path $env:ProgramFiles 'Microsoft VS Code\bin\code.cmd')
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}

# ---------------------------------------------------------------------------
# 1. WSL ディストリビューション
# ---------------------------------------------------------------------------
if (-not $Distro) {
  # 既定のディストリビューション名を取得（なければ空）
  $Distro = (& wsl.exe -e sh -c 'echo $WSL_DISTRO_NAME' 2>$null | Select-Object -Last 1)
  if ($LASTEXITCODE -ne 0 -or -not $Distro) { $Distro = $InstallDistro } else { $Distro = $Distro.Trim() }
}
Write-Step "WSL ディストリビューション ($Distro)"
if ((Get-Distros) -notcontains $Distro) {
  Write-Info "$Distro が見つかりません"
  if (-not (Confirm-Step "wsl --install -d $Distro でインストールしますか？")) { exit 1 }
  Write-Info "（起動したらユーザー名とパスワードを作成し、exit で抜けてください）"
  & wsl.exe --install -d $Distro
  if ((Get-Distros) -notcontains $Distro) {
    Write-Warn "インストールを完了できませんでした。Windows の再起動が必要な場合は、再起動後にもう一度実行してください"
    exit 1
  }
}
$LinuxUser = ((Invoke-Wsl -Command @('id', '-un') -Capture) | Select-Object -Last 1).Trim()
if ($LinuxUser -eq 'root') {
  throw "$Distro の既定ユーザーが root です。一般ユーザーを作成して既定ユーザーにしてから実行してください"
}
Write-Info "ユーザー: $LinuxUser"

# ---------------------------------------------------------------------------
# 2. VS Code（Windows 側）
# ---------------------------------------------------------------------------
if (-not $SkipVSCode) {
  Write-Step 'VS Code'
  $code = Find-VSCode
  if ($code) {
    Write-Info "導入済み: $code"
  } elseif (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    Write-Warn 'winget が見つかりません。https://code.visualstudio.com/ から手動で入れてください'
  } elseif (Confirm-Step 'winget で VS Code をインストールしますか？') {
    & winget.exe install -e --id Microsoft.VisualStudioCode --scope user `
      --accept-source-agreements --accept-package-agreements
    $code = Find-VSCode
    if (-not $code) { Write-Warn 'VS Code のインストールを確認できませんでした' }
  }
  if ($code) {
    Write-Info 'WSL 拡張 (ms-vscode-remote.remote-wsl)'
    & $code --install-extension ms-vscode-remote.remote-wsl
    if ($LASTEXITCODE -ne 0) { Write-Warn 'WSL 拡張のインストールに失敗しました' }
  }
}

# ---------------------------------------------------------------------------
# 3. リポジトリを WSL 内に注入
# ---------------------------------------------------------------------------
Write-Step 'リポジトリを WSL にコピー'
# inject.sh が CRLF でチェックアウトされていても動くよう、LF に直したコピーを実行する
$injectSrc = Join-Path $RepoRoot 'windows\inject.sh'
$injectTmp = Join-Path $env:TEMP 'dotfiles-inject.sh'
$injectText = [IO.File]::ReadAllText($injectSrc) -replace "`r`n", "`n"
[IO.File]::WriteAllText($injectTmp, $injectText, (New-Object System.Text.UTF8Encoding $false))

$repoWsl   = ((Invoke-Wsl -Command @('wslpath', '-u', $RepoRoot) -Capture) | Select-Object -Last 1).Trim()
$injectWsl = ((Invoke-Wsl -Command @('wslpath', '-u', $injectTmp) -Capture) | Select-Object -Last 1).Trim()
$dest = ((Invoke-Wsl -User $LinuxUser -Command @('bash', $injectWsl, $repoWsl, $Target) -Capture) | Select-Object -Last 1).Trim()
Remove-Item $injectTmp -ErrorAction SilentlyContinue
Write-Info "コピー先: $dest"

$common = @()
if ($Yes)        { $common += '--yes' }
if ($SkipAI)     { $common += '--skip-ai' }
if ($SkipVSCode) { $common += '--skip-vscode' }

# ---------------------------------------------------------------------------
# 4. root 権限の作業
# ---------------------------------------------------------------------------
Write-Step 'install.sh --system-only (root)'
Invoke-Wsl -User 'root' -Command (@('bash', "$dest/install.sh", '--system-only', '--for-user', $LinuxUser) + $common)

# ---------------------------------------------------------------------------
# 5. ユーザーの作業
# ---------------------------------------------------------------------------
Write-Step "install.sh --user-only ($LinuxUser)"
$envArgs = @()
if ($GitName)  { $envArgs += "GIT_NAME=$GitName" }
if ($GitEmail) { $envArgs += "GIT_EMAIL=$GitEmail" }
Invoke-Wsl -User $LinuxUser -Command (@('env') + $envArgs + @('bash', "$dest/install.sh", '--user-only') + $common)

# ---------------------------------------------------------------------------
# 6. wsl.conf の反映
# ---------------------------------------------------------------------------
& wsl.exe -d $Distro -u root -e test -e /run/dotfiles-wsl-restart-required
if ($LASTEXITCODE -eq 0) {
  Write-Step '/etc/wsl.conf の反映'
  if ($NoRestart) {
    Write-Info "後で 'wsl --terminate $Distro' を実行して再起動してください"
  } elseif (Confirm-Step "$Distro を再起動しますか？（開いている $Distro のターミナルは閉じます）") {
    & wsl.exe --terminate $Distro
    Write-Info '再起動しました（次に開いたときに反映されます）'
  } else {
    Write-Info "後で 'wsl --terminate $Distro' を実行して再起動してください"
  }
}

Write-Step '完了'
Write-Info "Windows Terminal などで $Distro を開くと zsh が起動します"
