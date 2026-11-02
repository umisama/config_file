<#
.SYNOPSIS
  Windows をセットアップし、最後に WSL (Ubuntu) へこの dotfiles を適用する。

.DESCRIPTION
  管理者として実行する（管理者でなければ UAC で昇格して起動し直す）。
  途中で再起動が必要になると「ログオン時に続きから実行する」タスクを登録して再起動し、
  次にサインインしたときに自動で再開する。すべて終わるとタスクを削除する。

  ステップ（-Skip で名前を指定すると飛ばせる）:
    keyboard   CapsLock → Ctrl、半角/全角 → Esc（Scancode Map。全ユーザーに適用され、再起動後に有効）
    privacy    利用履歴によるおすすめ・広告・ヒントの無効化
    copilot    Copilot / Recall などの AI 機能の無効化
    search     スタートメニューの Web 検索と、タスクバーの検索ボックスの無効化
    edge       Edge のポリシー（自動起動・バックグラウンド動作・既定ブラウザ催促・サイドバー）とウィジェットの無効化
    apps       アプリのインストール（winget）
    ime        Google 日本語入力を既定の入力方式にし、キー設定を登録する
    defaults   既定アプリ（ブラウザ・PDF → Vivaldi）。ポリシーで設定し、サインイン時に反映される
    wsl        WSL の有効化
    (再起動)
    dotfiles   Ubuntu のインストールと windows\setup.ps1 の実行
    verify     結果の確認

  状態とログ: %LOCALAPPDATA%\dotfiles-bootstrap\

.EXAMPLE
  .\windows\bootstrap.cmd
  .\windows\bootstrap.ps1 -GitName "Taro" -GitEmail "taro@example.com" -Yes
  .\windows\bootstrap.ps1 -Skip edge,defaults
#>
[CmdletBinding()]
param(
  [string]$Distro = 'Ubuntu-26.04',
  [string]$GitName,
  [string]$GitEmail,
  [string[]]$Skip = @(),
  [switch]$SkipAI,
  # 確認せずに進める（再起動も自動）
  [switch]$Yes,
  # 再起動後の自動再開（タスクから呼ばれる）
  [switch]$Resume
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$RepoRoot  = Split-Path -Parent $PSScriptRoot
$StateDir  = Join-Path $env:LOCALAPPDATA 'dotfiles-bootstrap'
$StateFile = Join-Path $StateDir 'state.json'
$TaskName  = 'dotfiles-bootstrap'

$Apps = @(
  @{ Id = 'Vivaldi.Vivaldi';            Name = 'Vivaldi' },
  @{ Id = 'Google.JapaneseIME';         Name = 'Google 日本語入力' },
  @{ Id = 'Microsoft.VisualStudioCode'; Name = 'Visual Studio Code'; Scope = 'user' },
  @{ Id = 'Anthropic.Claude';           Name = 'Claude Desktop' },
  @{ Id = 'OpenAI.ChatGPT';             Name = 'ChatGPT（Codex を含む）' },
  @{ Id = 'XPFCC4CD725961';             Name = 'LINE'; Source = 'msstore' },
  @{ Id = 'Google.GoogleDrive';         Name = 'Google ドライブ' }
)

function Write-Step([string]$Message) { Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Write-Info([string]$Message) { Write-Host "    $Message" }
function Write-Warn([string]$Message) { Write-Host "warn: $Message" -ForegroundColor Yellow; $script:Warnings += $Message }

function Confirm-Step([string]$Question) {
  if ($Yes) { return $true }
  return (Read-Host "$Question [y/N]") -match '^[Yy]'
}

# レジストリに値を書く（キーがなければ作る）
function Set-Reg([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord') {
  if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
  New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

# ---------------------------------------------------------------------------
# 昇格と状態
# ---------------------------------------------------------------------------
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
  foreach ($k in $PSBoundParameters.Keys) {
    $v = $PSBoundParameters[$k]
    if ($v -is [switch]) { if ($v) { $argList += "-$k" } }
    elseif ($v -is [array]) { $argList += "-$k"; $argList += ($v -join ',') }
    else { $argList += "-$k"; $argList += "`"$v`"" }
  }
  Write-Host '管理者として起動し直します（UAC の確認が表示されます）'
  $p = Start-Process powershell.exe -Verb RunAs -ArgumentList $argList -Wait -PassThru
  exit $p.ExitCode
}

New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
Start-Transcript -Path (Join-Path $StateDir "log-$(Get-Date -Format yyyyMMdd-HHmmss).txt") | Out-Null

$State = @{ Done = @(); Params = @{} }
if ($Resume -and (Test-Path $StateFile)) {
  $loaded = Get-Content $StateFile -Raw -Encoding UTF8 | ConvertFrom-Json
  $State.Done = @($loaded.Done)
  # 最初に指定されたオプションを引き継ぐ
  $p = $loaded.Params
  if ($p) {
    if ($p.Distro)   { $Distro   = $p.Distro }
    if ($p.GitName)  { $GitName  = $p.GitName }
    if ($p.GitEmail) { $GitEmail = $p.GitEmail }
    if ($p.Skip)     { $Skip     = @($p.Skip) }
    if ($p.SkipAI)   { $SkipAI   = [switch]$true }
    if ($p.Yes)      { $Yes      = [switch]$true }
  }
}
$Skip = @($Skip | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$State.Params = @{ Distro = $Distro; GitName = $GitName; GitEmail = $GitEmail; Skip = $Skip; SkipAI = [bool]$SkipAI; Yes = [bool]$Yes }

function Save-State { $State | ConvertTo-Json -Depth 4 | Set-Content -Path $StateFile -Encoding UTF8 }

# 再開用タスク（ログオン時に管理者で実行。ウィンドウを表示する）
function Register-ResumeTask {
  $user = "$env:USERDOMAIN\$env:USERNAME"
  $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSCommandPath`" -Resume"
  $trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
  $trigger.Delay = 'PT20S'   # ネットワークとストアの準備を待つ
  $principalTask = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)
  Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principalTask `
    -Settings $settings -Force | Out-Null
}
function Unregister-ResumeTask {
  if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
  }
}

$script:Warnings = @()
$script:RebootPending = $false

# ---------------------------------------------------------------------------
# ステップ
# ---------------------------------------------------------------------------
function Step-Keyboard {
  # Scancode Map: 8 バイトのヘッダ、件数（終端を含む）、[新しいコード, 元のコード] の組、終端 0
  #   0x3A CapsLock（日本語キーボードでは 英数/CapsLock）→ 0x1D 左 Ctrl
  #   0x29 半角/全角 → 0x01 Esc
  [byte[]]$map = 0,0,0,0, 0,0,0,0, 3,0,0,0, 0x1D,0,0x3A,0, 0x01,0,0x29,0, 0,0,0,0
  $path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout'
  $cur = (Get-ItemProperty -Path $path -Name 'Scancode Map' -ErrorAction SilentlyContinue).'Scancode Map'
  if ($cur -and ([Convert]::ToBase64String($cur) -eq [Convert]::ToBase64String($map))) {
    Write-Info '設定済み'
    return
  }
  if ($cur) { Write-Info "既存の Scancode Map を置き換えます（元の値: $([BitConverter]::ToString($cur))）" }
  Set-Reg $path 'Scancode Map' $map 'Binary'
  Write-Info 'CapsLock → Ctrl、半角/全角 → Esc（再起動後に有効）'
  $script:RebootPending = $true
}

function Step-Privacy {
  $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
  Set-Reg $adv 'Start_TrackProgs' 0              # よく使うアプリ（起動履歴の記録）
  Set-Reg $adv 'Start_TrackDocs' 0               # 最近開いた項目（スタート / ジャンプリスト / エクスプローラー）
  Set-Reg $adv 'Start_IrisRecommendations' 0     # スタートのヒント・おすすめアプリ
  Set-Reg $adv 'Start_AccountNotifications' 0    # スタートのアカウント関連の通知
  Set-Reg $adv 'Start_RecoPersonalizedSites' 0   # スタートのおすすめ Web サイト
  # 広告 ID・カスタマイズされたエクスペリエンス
  Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
  Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' 1
  Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0
  Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\CloudContent' 'DisableTailoredExperiencesWithDiagnosticData' 1
  Set-Reg 'HKCU:\Control Panel\International\User Profile' 'HttpAcceptLanguageOptOut' 1
  # おすすめ・ヒント・アプリの自動インストール（ContentDeliveryManager）
  $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
  foreach ($n in 'SilentInstalledAppsEnabled', 'SystemPaneSuggestionsEnabled', 'SoftLandingEnabled',
                 'PreInstalledAppsEnabled', 'OemPreInstalledAppsEnabled', 'RotatingLockScreenOverlayEnabled',
                 'SubscribedContent-310093Enabled',   # 更新後のようこそ画面
                 'SubscribedContent-338387Enabled',   # ロック画面のヒント
                 'SubscribedContent-338388Enabled',   # スタートのおすすめ
                 'SubscribedContent-338389Enabled',   # Windows のヒント
                 'SubscribedContent-338393Enabled',   # 設定アプリのおすすめ
                 'SubscribedContent-353694Enabled',
                 'SubscribedContent-353696Enabled') {
    Set-Reg $cdm $n 0
  }
  Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' 0
  # アクティビティ履歴
  $sys = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
  Set-Reg $sys 'EnableActivityFeed' 0
  Set-Reg $sys 'PublishUserActivities' 0
  Set-Reg $sys 'UploadUserActivities' 0
  Write-Info 'スタートのおすすめ・最近使った項目・広告 ID・ヒント・アクティビティ履歴を無効化'
}

function Step-Copilot {
  foreach ($root in 'HKCU:', 'HKLM:') {
    Set-Reg "$root\Software\Policies\Microsoft\Windows\WindowsCopilot" 'TurnOffWindowsCopilot' 1
  }
  Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'RemoveMicrosoftCopilotApp' 1
  Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton' 0
  # Recall / Click to Do
  foreach ($root in 'HKCU:', 'HKLM:') {
    Set-Reg "$root\Software\Policies\Microsoft\Windows\WindowsAI" 'DisableAIDataAnalysis' 1
    Set-Reg "$root\Software\Policies\Microsoft\Windows\WindowsAI" 'DisableClickToDo' 1
  }
  Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'AllowRecallEnablement' 0
  # メモ帳・ペイントの AI 機能
  Set-Reg 'HKLM:\SOFTWARE\Policies\WindowsNotepad' 'DisableAIFeatures' 1
  $paint = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'
  foreach ($n in 'DisableCocreator', 'DisableGenerativeFill', 'DisableImageCreator') { Set-Reg $paint $n 1 }
  # Copilot アプリと Microsoft 365 Copilot アプリ（Microsoft.MicrosoftOfficeHub）を削除
  foreach ($name in 'Microsoft.Copilot', 'Microsoft.Windows.Ai.Copilot.Provider', 'Microsoft.MicrosoftOfficeHub') {
    try {
      $pkgs = @(Get-AppxPackage -AllUsers -Name $name -ErrorAction SilentlyContinue)
      foreach ($pkg in $pkgs) { Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop; Write-Info "削除: $($pkg.Name)" }
      Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq $name |
        ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName | Out-Null; Write-Info "プロビジョニング解除: $name" }
    } catch {
      Write-Warn "$name を削除できませんでした: $($_.Exception.Message)"
    }
  }
  Write-Info 'Copilot・Recall・メモ帳/ペイントの AI 機能を無効化'
}

function Step-Search {
  Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 0    # 検索ボックスを隠す
  Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0
  Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings' 'IsDynamicSearchBoxEnabled' 0   # 検索のハイライト
  Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
  $ws = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
  Set-Reg $ws 'DisableWebSearch' 1
  Set-Reg $ws 'ConnectedSearchUseWeb' 0
  Set-Reg $ws 'AllowCloudSearch' 0
  Set-Reg $ws 'EnableDynamicContentInWSB' 0
  Set-Reg $ws 'AllowCortana' 0
  Write-Info 'Web 検索・検索候補・検索ボックスを無効化（Win キー → 入力でのアプリやファイルの検索は使える）'
}

function Step-Edge {
  $edge = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
  Set-Reg $edge 'StartupBoostEnabled' 0                  # Windows 起動時の事前起動
  Set-Reg $edge 'BackgroundModeEnabled' 0                # 閉じた後のバックグラウンド動作
  Set-Reg $edge 'DefaultBrowserSettingEnabled' 0         # 既定のブラウザにするよう催促しない
  Set-Reg $edge 'HideFirstRunExperience' 1
  Set-Reg $edge 'HubsSidebarEnabled' 0                   # サイドバー（Copilot を含む）
  Set-Reg $edge 'Microsoft365CopilotChatIconEnabled' 0
  Set-Reg $edge 'ShowRecommendationsEnabled' 0
  # ログオン時の自動起動を削除
  $run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
  $props = Get-ItemProperty -Path $run -ErrorAction SilentlyContinue
  if ($props) {
    $props.PSObject.Properties | Where-Object Name -like 'MicrosoftEdgeAutoLaunch*' | ForEach-Object {
      Remove-ItemProperty -Path $run -Name $_.Name; Write-Info "自動起動を削除: $($_.Name)"
    }
  }
  # ウィジェット（ニュースなどを Edge で開く）
  Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0
  Write-Info 'Edge の事前起動・バックグラウンド動作・サイドバー・ウィジェットを無効化'
}

function Wait-Winget {
  for ($i = 0; $i -lt 60; $i++) {
    if (Get-Command winget.exe -ErrorAction SilentlyContinue) { return $true }
    if ($i -eq 0) { Write-Info 'winget の準備を待っています...' }
    Start-Sleep -Seconds 5
  }
  return $false
}

function Step-Apps {
  if (-not (Wait-Winget)) { throw 'winget が見つかりません（Microsoft Store の「アプリ インストーラー」を更新してください）' }
  foreach ($app in $Apps) {
    $src = if ($app.Source) { $app.Source } else { 'winget' }
    & winget.exe list --id $app.Id -e --source $src --accept-source-agreements *> $null
    if ($LASTEXITCODE -eq 0) { Write-Info "導入済み: $($app.Name)"; continue }
    Write-Info "インストール: $($app.Name)"
    $wargs = @('install', '--id', $app.Id, '-e', '--source', $src, '--silent',
               '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
    if ($app.Scope) { $wargs += @('--scope', $app.Scope) }
    & winget.exe @wargs
    if ($LASTEXITCODE -ne 0) { Write-Warn "$($app.Name) のインストールに失敗しました (winget exit $LASTEXITCODE)" }
  }
}

function Step-Ime {
  # Google 日本語入力の TIP を探して既定の入力方式にする
  $tip = $null
  foreach ($clsid in Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\CTF\TIP' -ErrorAction SilentlyContinue) {
    foreach ($prof in Get-ChildItem (Join-Path $clsid.PSPath 'LanguageProfile\0x00000411') -ErrorAction SilentlyContinue) {
      if ((Get-ItemProperty $prof.PSPath).Description -like 'Google*') { $tip = "0411:$($clsid.PSChildName)$($prof.PSChildName)" }
    }
  }
  if ($tip) {
    Set-WinDefaultInputMethodOverride -InputTip $tip
    Write-Info "既定の入力方式: Google 日本語入力 ($tip)"
  } else {
    Write-Warn 'Google 日本語入力が見つからないため、既定の入力方式は変更しませんでした'
  }
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'google-ime-keymap.ps1')
  if ($LASTEXITCODE -ne 0) { Write-Warn 'Google 日本語入力のキー設定を登録できませんでした' }
}

# Vivaldi が登録している関連付け（拡張子・プロトコル → ProgId）
function Get-VivaldiAssociations {
  foreach ($root in 'HKCU:', 'HKLM:') {
    $clients = Get-ChildItem "$root\SOFTWARE\Clients\StartMenuInternet" -ErrorAction SilentlyContinue |
      Where-Object PSChildName -like 'Vivaldi*'
    foreach ($c in $clients) {
      $map = @{}
      foreach ($sub in 'FileAssociations', 'URLAssociations') {
        $key = Join-Path $c.PSPath "Capabilities\$sub"
        if (Test-Path $key) {
          (Get-ItemProperty $key).PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } |
            ForEach-Object { $map[$_.Name.ToLower()] = $_.Value }
        }
      }
      if ($map.Count) { return $map }
    }
  }
  return $null
}

function Step-Defaults {
  # Windows 11 は UserChoice の直接書き換えを保護しているため（UCPD）、
  # 既定の関連付けの XML をポリシーで指定する。サインインのたびに適用される。
  $assoc = Get-VivaldiAssociations
  if (-not $assoc) { throw 'Vivaldi の登録情報が見つかりません（apps ステップを先に実行してください）' }
  $wanted = 'http', 'https', '.htm', '.html', '.shtml', '.xht', '.xhtml', '.svg', '.pdf'
  $xml = New-Object System.Text.StringBuilder
  [void]$xml.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
  [void]$xml.AppendLine('<DefaultAssociations>')
  foreach ($id in $wanted) {
    if ($assoc.ContainsKey($id)) {
      [void]$xml.AppendLine("  <Association Identifier=`"$id`" ProgId=`"$($assoc[$id])`" ApplicationName=`"Vivaldi`" />")
    }
  }
  [void]$xml.AppendLine('</DefaultAssociations>')
  $dir = Join-Path $env:ProgramData 'dotfiles'
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $file = Join-Path $dir 'DefaultAssociations.xml'
  $sysKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
  $curXml = if (Test-Path $file) { [IO.File]::ReadAllText($file) } else { '' }
  $curPol = (Get-ItemProperty $sysKey -Name DefaultAssociationsConfiguration -ErrorAction SilentlyContinue).DefaultAssociationsConfiguration
  if ($curXml -eq $xml.ToString() -and $curPol -eq $file) {
    Write-Info "設定済み: $file"
    return
  }
  [IO.File]::WriteAllText($file, $xml.ToString(), (New-Object System.Text.UTF8Encoding $false))
  Set-Reg $sysKey 'DefaultAssociationsConfiguration' $file 'String'
  Write-Info "既定アプリの設定: $file（次のサインインで反映）"
  $script:RebootPending = $true
}

function Step-Wsl {
  $vmp = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
  $wslOk = $false
  if ($vmp.State -eq 'Enabled') {
    & wsl.exe --version *> $null
    $wslOk = ($LASTEXITCODE -eq 0)
  }
  if ($wslOk) {
    Write-Info 'WSL は有効です'
    & wsl.exe --update
    return
  }
  & wsl.exe --install --no-distribution
  if ($LASTEXITCODE -ne 0) { throw "wsl --install に失敗しました (exit $LASTEXITCODE)" }
  $script:RebootPending = $true
}

function Step-Dotfiles {
  & wsl.exe --update *> $null
  $setupArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'setup.ps1'),
                 '-Distro', $Distro, '-InstallDistro', $Distro)
  if ($GitName)  { $setupArgs += @('-GitName', $GitName) }
  if ($GitEmail) { $setupArgs += @('-GitEmail', $GitEmail) }
  if ($SkipAI)   { $setupArgs += '-SkipAI' }
  if ($Yes)      { $setupArgs += '-Yes' }
  & powershell.exe @setupArgs
  if ($LASTEXITCODE -ne 0) { throw "setup.ps1 が失敗しました (exit $LASTEXITCODE)" }
}

function Step-Verify {
  $https = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice' -ErrorAction SilentlyContinue).ProgId
  if ($Skip -notcontains 'defaults') {
    if ($https -like 'Vivaldi*') {
      Write-Info "既定のブラウザ: Vivaldi ($https)"
    } else {
      Write-Warn "既定のブラウザが Vivaldi になっていません（現在: $https）。開いた設定画面で「既定値に設定」を押してください"
      Start-Process 'ms-settings:defaultapps?registeredAppUser=Vivaldi'
    }
  }
  & wsl.exe -d $Distro -e true *> $null
  if ($LASTEXITCODE -eq 0) { Write-Info "WSL: $Distro" } else { Write-Warn "WSL の $Distro を起動できません" }
}

$Steps = @(
  @{ Name = 'keyboard'; Title = 'キー配置（CapsLock → Ctrl、半角/全角 → Esc）'; Run = { Step-Keyboard } },
  @{ Name = 'privacy';  Title = '利用履歴によるおすすめの無効化';                 Run = { Step-Privacy } },
  @{ Name = 'copilot';  Title = 'Copilot の無効化';                               Run = { Step-Copilot } },
  @{ Name = 'search';   Title = 'Windows Search（Web 検索・検索ボックス）';       Run = { Step-Search } },
  @{ Name = 'edge';     Title = 'Edge の抑制';                                    Run = { Step-Edge } },
  @{ Name = 'apps';     Title = 'アプリのインストール';                           Run = { Step-Apps } },
  @{ Name = 'ime';      Title = 'Google 日本語入力';                              Run = { Step-Ime } },
  @{ Name = 'defaults'; Title = '既定アプリ（Vivaldi）';                          Run = { Step-Defaults } },
  @{ Name = 'wsl';      Title = 'WSL の有効化';                                   Run = { Step-Wsl } },
  @{ Name = 'reboot';   Title = '再起動';                                         Run = $null },
  @{ Name = 'dotfiles'; Title = "WSL ($Distro) と dotfiles";                     Run = { Step-Dotfiles } },
  @{ Name = 'verify';   Title = '確認';                                           Run = { Step-Verify } }
)

# ---------------------------------------------------------------------------
# 実行
# ---------------------------------------------------------------------------
Unregister-ResumeTask
if ($Resume) { Write-Host '再起動前の続きから再開します' -ForegroundColor Green }
if ($RepoRoot -like '\\*') {
  Write-Warn "リポジトリがネットワーク / WSL 上にあります ($RepoRoot)。再起動後の再開に失敗する場合は C:\ 以下に置いてください"
}

$failed = @()
foreach ($step in $Steps) {
  if ($State.Done -contains $step.Name) { continue }

  if ($step.Name -eq 'reboot') {
    if ($script:RebootPending) {
      Write-Step '再起動'
      $State.Done += 'reboot'
      Save-State
      Register-ResumeTask
      Write-Info 'サインインすると、このウィンドウが自動で開いて続きを実行します'
      if ($Yes) {
        Write-Info '15 秒後に再起動します（中止するには Ctrl+C）'
        Start-Sleep -Seconds 15
        Stop-Transcript | Out-Null
        Restart-Computer -Force
        exit 0
      } elseif (Confirm-Step '今すぐ再起動しますか？') {
        Stop-Transcript | Out-Null
        Restart-Computer -Force
        exit 0
      } else {
        Write-Info '後で手動で再起動してください（サインイン後に続きを実行します）'
        Stop-Transcript | Out-Null
        exit 0
      }
    }
    $State.Done += 'reboot'
    continue
  }

  if ($Skip -contains $step.Name) {
    Write-Step "$($step.Title)（スキップ）"
    $State.Done += $step.Name; Save-State
    continue
  }

  Write-Step $step.Title
  try {
    & $step.Run
    $State.Done += $step.Name
  } catch {
    Write-Warn "$($step.Name): $($_.Exception.Message)"
    $failed += $step.Name
  }
  Save-State
}

Write-Step '完了'
if ($failed.Count) {
  Write-Host "失敗したステップ: $($failed -join ', ')" -ForegroundColor Red
  Write-Info '原因を直してから bootstrap.cmd をもう一度実行してください（設定済みの項目はそのままです）'
}
if ($script:Warnings.Count) {
  Write-Host '確認が必要な項目:' -ForegroundColor Yellow
  $script:Warnings | ForEach-Object { Write-Info "- $_" }
}
if (-not $failed.Count) { Remove-Item $StateFile -ErrorAction SilentlyContinue }
Write-Info "ログ: $StateDir"
Stop-Transcript | Out-Null
if ($failed.Count) { exit 1 }
