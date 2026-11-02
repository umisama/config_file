# 共通の作業ルール（Claude Code / Codex）

このファイルは dotfiles（config/ai/AGENTS.md）で管理している。
Codex は ~/.codex/AGENTS.md として、Claude Code は ~/.claude/CLAUDE.md からの読み込みで参照する。

## コミュニケーション

- 応答・説明・質問は日本語で行う。コード、コマンド、識別子、エラーメッセージは原文のまま書く。

## コミットメッセージとコードコメント

- 言語と書式は、そのリポジトリの既存のコミット履歴やコメントの慣習に合わせる。
- 慣習から判断できないときは英語で書く。

## 作業環境

- WSL2 または Ubuntu。ログインシェルは zsh。
- 言語ランタイム（node / go / python など）は mise で管理している。プロジェクトで必要なバージョンは `mise use` / `mise.toml` で指定する。
- ファイル検索には `rg` / `fd` が使える。
