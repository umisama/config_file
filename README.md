# dotfiles

WSL2 / Ubuntu 用の個人設定。zsh・Neovim・tmux・git・mise を XDG 配下（`~/.config`）で管理する。

## セットアップ

### Windows の新規セットアップ（Windows 全体 ＋ WSL）

新しい Windows で、このリポジトリを `C:\` 以下に置いて（GitHub の「Download ZIP」を展開するか `git clone`）、`windows\bootstrap.cmd` を実行する。UAC で管理者に昇格し、途中の再起動をまたいで最後まで進む。

```powershell
C:\Users\me\config_file\windows\bootstrap.cmd
C:\Users\me\config_file\windows\bootstrap.cmd -GitName "Taro" -GitEmail "taro@example.com" -Yes   # 確認なし・自動再起動
C:\Users\me\config_file\windows\bootstrap.cmd -Skip edge,defaults                                  # 一部を飛ばす
```

| ステップ | 内容 |
|---|---|
| `keyboard` | CapsLock → Ctrl、半角/全角 → Esc（`Scancode Map`。全ユーザー・再起動後に有効） |
| `privacy` | 利用履歴によるおすすめの無効化（スタートのおすすめ・最近使った項目、広告 ID、ヒント、アプリの自動インストール、アクティビティ履歴） |
| `copilot` | Copilot・Recall・Click to Do・メモ帳/ペイントの AI 機能を無効化。Copilot アプリと Microsoft 365 Copilot アプリを削除 |
| `search` | スタートの Web 検索・検索候補・検索のハイライトを無効化し、タスクバーの検索ボックスを隠す（インデクサーは残す） |
| `edge` | Edge のポリシー（事前起動・バックグラウンド動作・既定ブラウザの催促・サイドバーを無効化）、ログオン時の自動起動を削除、ウィジェットを無効化 |
| `apps` | winget で Vivaldi / Google 日本語入力 / VS Code / Claude / ChatGPT（Codex）/ LINE（Microsoft Store）/ Google ドライブ |
| `ime` | Google 日本語入力を既定の入力方式にし、`config/windows/google-ime-keymap.txt` のキー設定を登録 |
| `defaults` | ブラウザ（http/https/.html など）と PDF を Vivaldi に。既定の関連付けの XML（`C:\ProgramData\dotfiles\DefaultAssociations.xml`）をポリシーで指定する |
| `wsl` | `wsl --install --no-distribution`（再起動が必要） |
| （再起動） | 必要なときだけ。ログオン時に続きを実行するタスクを登録してから再起動する |
| `dotfiles` | `setup.ps1 -Distro Ubuntu-26.04`（Ubuntu のインストール → この dotfiles の適用） |
| `verify` | 既定のブラウザと WSL を確認する |

- 状態とログは `%LOCALAPPDATA%\dotfiles-bootstrap\` に残る。失敗したときは原因を直してもう一度実行する（設定済みの項目は変わらない）。
- 再起動後はサインインするだけでよい（自動ログオンはパスワードを保存することになるので使わない）。
- 既定アプリのポリシーはサインインのたびに適用される。Windows 11 は既定アプリの直接の書き換えを保護している（UCPD）ため、この方法にしている。反映されないときは `verify` が設定画面を開くので、「既定値に設定」を押す。
- Edge は Windows の一部としてアンインストールできない（EEA 以外）。設定で起動の機会を減らすだけで、Windows が直接 Edge を開くリンクは残る。
- Office は入れない。Office ファイルは Google ドライブ上でブラウザの Google ドキュメントで開く。
- Ubuntu のインストール時は、ユーザー名とパスワードを作成したら `exit` で抜ける。

#### Google 日本語入力のキー設定

`config/windows/google-ime-keymap.txt` は、プロパティ → キー設定 → 編集 →「エクスポート」で書き出した形式。IME のオンは 変換 / ひらがな / カタカナ / F13、オフは 無変換（半角/全角 は Esc にしているので使わない。英数 は Ctrl に変えた CapsLock と同じキー）。

```powershell
windows\google-ime-keymap.ps1                       # リポジトリのキー設定を登録
windows\google-ime-keymap.ps1 -KeymapFile keymap.txt # 別のファイルを登録
```

キーマップを取り込むコマンドはないので、設定ファイル `config1.db`（protobuf）のキーマップの項目だけを書き換える。書き換える前にバックアップを取り、Google IME の常駐プロセスを止める（次に使うときに自動で起動する）。プロパティ画面で変更したら、もう一度エクスポートしてこのファイルを更新する。

### Windows から（WSL）

Windows 側にこのリポジトリを clone して、`windows\setup.cmd` を実行する（ダブルクリックでも可）。

```powershell
git clone <this repo> $HOME\config_file
$HOME\config_file\windows\setup.cmd                      # 既定のディストリビューションが対象
$HOME\config_file\windows\setup.cmd -Distro Ubuntu-26.04 -GitName "Taro" -GitEmail "taro@example.com"
```

`setup.ps1` は次の順に処理する。

1. WSL のディストリビューションを確認する（なければ `wsl --install`）
2. Windows 側に VS Code と WSL 拡張を winget で入れる
3. リポジトリを WSL 内の `~/config_file` にコピーする（注入）
   - 既にあれば `~/.dotfiles-backup/<日時>/` に退避してからコピーする
   - `\\wsl.localhost\...` 上のリポジトリから実行した場合はコピーしない
4. `wsl -u root` で `install.sh --system-only` を実行する（sudo のパスワードは不要）
5. 既定ユーザーで `install.sh --user-only` を実行する
6. `/etc/wsl.conf` が変わったときは、ディストリビューションを再起動するか確認する

オプション：`-Yes`、`-SkipVSCode`、`-SkipAI`、`-NoRestart`、`-Target <WSL内のパス>`

### Ubuntu / WSL の中から

```sh
git clone <this repo> ~/config_file   # 場所はどこでもよい
cd ~/config_file
./install.sh                          # root 権限が必要な作業は sudo で行う
```

何度実行しても同じ状態になる（既にあるファイルは `~/.dotfiles-backup/<日時>/` に退避してからリンクする）。

| オプション | 内容 |
|---|---|
| `-y`, `--yes` | 確認せずに進める（git の名前/メールは `GIT_NAME` / `GIT_EMAIL` から） |
| `--no-packages` | パッケージ類は入れず、リンクと git 設定だけ行う |
| `--skip-ai` | Claude Code / Codex CLI を入れない |
| `--skip-vscode` | VS Code を入れない（ネイティブ Ubuntu のみ） |
| `--system-only` | root 権限の作業だけ（apt / mise 本体 / wsl.conf / ログインシェル） |
| `--user-only` | ユーザーの作業だけ（リンク / mise のツール / git / AI CLI） |
| `--for-user U` | `--system-only` でログインシェルを変える対象ユーザー |

### install.sh がやること

- **system（root）**
  - `packages/apt.txt` のパッケージと mise 本体を apt で入れる
  - WSL のときは `wsl/wsl.conf` の内容を `/etc/wsl.conf` にマージする
  - ネイティブ Ubuntu のときは VS Code を入れる
  - ログインシェルを zsh に変更する
- **user**
  - `config/` 以下を `~/.config/` にリンクする（`~/.zshenv`、`fd` / `bat` も）
  - `config/mise/config.toml` のツールを入れる（Neovim / node / go / python / tree-sitter / Codex）
  - git のユーザー情報を対話で聞き、`~/.config/git/config.local` に保存する
  - Claude Code を入れる
  - Claude Code / Codex の設定（指示ファイル・権限・通知フック・MCP）を反映する

## 構成

```
install.sh                 インストーラ
lib/common.sh              共通関数（link / confirm / ini_set など）
packages/apt.txt           apt パッケージ一覧
home/.zshenv               ZDOTDIR=~/.config/zsh を設定するだけ
config/zsh/                .zshrc と conf.d/*.zsh（番号順に読み込む。90-wsl は WSL のみ有効）
config/nvim/               init.lua, lua/config/*（基本設定）, lua/plugins/*（lazy.nvim）
config/git/config, ignore  git 共通設定（身元は config.local）
config/tmux/               tmux.conf（byobu 風）, status.sh, broadcast.sh
config/starship.toml
config/mise/config.toml    言語ランタイム・CLI ツール
wsl/wsl.conf               /etc/wsl.conf にマージする項目
config/ai/                 AGENTS.md（Claude / Codex 共通の指示）, mcp.json（MCP サーバー）, notify.sh, toast.ps1（完了通知）
config/claude/             CLAUDE.md, settings.json（~/.claude/settings.json にマージ）
config/codex/              config.toml（~/.codex/config.toml にマージ）, hooks.json
lib/merge_ai_config.py     Claude / Codex の設定マージ
windows/setup.cmd, .ps1    Windows 側から WSL をセットアップ（UTF-8 BOM / CRLF）
windows/inject.sh          setup.ps1 が使う、リポジトリを WSL 内にコピーするスクリプト
windows/bootstrap.cmd, .ps1          Windows 全体のセットアップ（再起動をまたいで再開。最後に setup.ps1）
windows/google-ime-keymap.ps1        Google 日本語入力にキー設定を登録
config/windows/google-ime-keymap.txt Google 日本語入力のキー設定（エクスポート形式）
```

## マシン固有の設定（リポジトリ管理外）

- `~/.zshrc.local`：zsh の追加設定（`.zshrc` の最後に読み込む）
- `~/.config/git/config.local`：git の user.name / user.email など

## tmux（byobu 風）

prefix は **C-a**（byobu の screen モードと同じ）と F12 の2つ。

### prefix 操作（screen 互換）

c / n / p / d / w / ] は、Ctrl を押したまま（C-a C-c など）でも同じ動作になる。

| キー | 動作 | キー | 動作 |
|---|---|---|---|
| C-a C-a | 直前のウィンドウと行き来 | C-a a | 中のアプリに C-a を送る（zsh なら行頭へ。Home キーでもよい） |
| C-a c | 新しいウィンドウ | C-a n / Space | 次のウィンドウ |
| C-a p / BS | 前のウィンドウ | C-a 0-9 | 番号でウィンドウを選ぶ |
| C-a w / " | ウィンドウ一覧 | C-a A / , | ウィンドウ名の変更 |
| C-a k（Ctrl 付き）/ K | ウィンドウを閉じる | C-a d | デタッチ |
| C-a S / - | 上下に分割 | C-a \| | 左右に分割 |
| C-a Tab | 次のペインへ | C-a h / j / k / l | 方向を指定してペイン移動 |
| C-a X | ペインを閉じる | C-a Q | このペイン以外を閉じる |
| C-a Esc / [ | コピーモード | C-a ] | 貼り付け |
| C-a r | 設定の再読み込み | | |

a と k だけは、Ctrl の有無で動作が変わる。
- C-a C-a：直前のウィンドウ / C-a a：中のアプリに C-a を送る
- C-a C-k：ウィンドウを閉じる / C-a k：上のペインへ移動

### F キー（byobu 互換）

| キー | 動作 |
|---|---|
| F2 / Shift-F2 / Ctrl-F2 | 新しいウィンドウ / 上下に分割 / 左右に分割 |
| Ctrl-Shift-F2 | 新しいセッション |
| F3 / F4（Alt-← / →） | 前 / 次のウィンドウ |
| Shift-F3 / F4（Shift-矢印） | ペイン移動 |
| Ctrl-F3 / F4 | ペインの入れ替え |
| Ctrl-Shift-F3 / F4 | ウィンドウを左 / 右へ移動 |
| Alt-↑ / ↓ | セッション切替 |
| Shift-Alt-矢印 | ペインのリサイズ |
| F5 | 設定の再読み込み |
| F6 / Shift-F6 / Alt-F6 | デタッチ / デタッチ / 他のクライアントをデタッチ |
| Ctrl-F6 | ペインを閉じる |
| F7（Alt-PageUp） | スクロールバック（コピーモード） |
| F8 / Ctrl-F8 | ウィンドウ / セッション名を変更 |
| Shift-F8 | レイアウト切替 |
| Ctrl-F9 / Shift-F9 | 全ウィンドウ / 全ペインにコマンドを送る |
| Alt-F9 | 全ペイン同時入力の切替（ON の間はステータスバーに `SYNC`） |
| F11 / Shift-F11 | ペインを最大化 / 戻す |
| Ctrl-F11 / Alt-F11 | このウィンドウを前のウィンドウに分割として取り込む / ペインを独立したウィンドウにする |
| Alt-F12 | マウスの切替 |
| Shift-F12 | F キーを tmux で受け取るかどうかの切替（Neovim の F1-F4 を使うとき。OFF の間はステータスバーに `F-KEYS OFF`） |

- byobu との違い
  - Ctrl-F5（SSH / GPG ソケットの再接続）はない
  - Alt-F4 は Windows がウィンドウを閉じる操作なので割り当てていない
- Windows Terminal の既定では **F11 は全画面表示**に使われるので、ペインの最大化は Shift-F11 を使う
- **起動**：`tm` で `main` セッションに入る（なければ作る）
- **ログイン時に自動で入る**（byobu-enable 相当）：`~/.zshrc.local` に `DOTFILES_TMUX_AUTOSTART=1` を書く
- **マシン固有の設定**：`~/.config/tmux/local.conf` に書く

## Claude Code / Codex

| 項目 | 実体 | 反映方法 |
|---|---|---|
| 共通の指示 | `config/ai/AGENTS.md` | `~/.codex/AGENTS.md` にリンク。`~/.claude/CLAUDE.md`（リンク）から `@~/.codex/AGENTS.md` で読み込む |
| Claude の設定 | `config/claude/settings.json` | `~/.claude/settings.json` にマージ（リポジトリにあるキーを上書き。permissions は和集合。theme などは残す） |
| Codex の設定 | `config/codex/config.toml` | `~/.codex/config.toml` の管理ブロックに差し込む（Codex が書いた信頼設定や model は残る） |
| 完了・確認待ちの通知 | `config/ai/notify.sh` → `~/.local/bin/ai-notify` | Claude: Stop / Notification フック、Codex: `~/.codex/hooks.json`（Stop / PermissionRequest） |
| MCP サーバー | `config/ai/mcp.json` | Claude は `claude mcp add-json`（ユーザースコープ）、Codex は config.toml の `[mcp_servers.*]` を生成 |

- **MCP サーバー**：Context7（ライブラリのドキュメント）、Playwright、Chrome DevTools
  - ブラウザ系の2つは、インストール済みの Google Chrome を headless で使う。Chrome は install.sh が入れる（amd64 のみ）
  - スクリーンショットの日本語表示用に Noto CJK フォントも入れる
  - 追加・変更は `config/ai/mcp.json` を編集して install.sh を実行する
- **Bypass Permissions（確認なしモード）**
  - Claude：`claude` は `--allow-dangerously-skip-permissions` 付きで起動するエイリアス。Shift+Tab で Bypass に切り替えられる。最初から Bypass で起動するなら `claude-yolo`
  - Codex：`codex-yolo` で、確認なし・サンドボックスなしで起動する
  - 確認なしモードは、プロンプトインジェクションなどに対する防御がなくなる。信頼できる作業でだけ使う
- **入力欄のキー操作**：各アプリの標準のまま（Enter：送信、Shift+Enter / Ctrl+J：改行）
  - tmux の中でも Shift+Enter を区別できるよう、tmux.conf に `extended-keys` を入れてある
  - Ctrl+Enter を送信にする案は見送った。Windows Terminal は Ctrl+Enter を Ctrl+J として送り、Claude Code（v2.1.316）は Ctrl+J に送信系の動作を割り当てても動かなかったため
- **設定を変えるとき**：リポジトリ側のファイルを編集して `./install.sh --user-only --no-packages` を実行する。`~/.claude/settings.json` や `~/.codex/config.toml` を直接編集しても、リポジトリには戻らない
- **通知**：WSL では Windows のトースト通知、ネイティブ Ubuntu では `notify-send` を使う
- **Codex のフック**：初回は Codex で `/hooks` を開いて信頼する必要がある。hooks.json を変えたときも同じ

## 覚え書き

- **更新**
  - mise 管理のツール（Codex 含む）：`mise upgrade`
  - Neovim のプラグイン：`:Lazy sync`
  - Claude Code：自動で更新される
- **LSP サーバ**：`:Mason` で追加する。入れたものは自動で有効になる
- **クリップボード**
  - コピー：OSC 52 を使う（Windows Terminal / tmux / SSH 越しでも動く）
  - Neovim での貼り付け：WSL では PowerShell 経由
- **WSL**
  - Windows の PATH はそのまま引き継ぐ（`appendWindowsPath=true`）。`explorer.exe`、`code`、`clip.exe` などがそのまま使える
  - `open`：zsh では Windows で開く（`open .` でエクスプローラ、`open file.pdf` で既定のアプリ、`open URL` で Windows のブラウザ）。Ubuntu 標準のものは `command open`
  - `/etc/wsl.conf` を変えた後は、Windows 側で `wsl --terminate <ディストリビューション>` を実行して再起動する
- **以前の zsh 設定**：`~/.zshenv` で ZDOTDIR を設定するため、oh-my-zsh 時代の `~/.zshrc` は読まれなくなる
