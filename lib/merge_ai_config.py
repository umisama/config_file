"""install.sh から呼ばれる、Claude Code / Codex の設定マージ。

  merge_ai_config.py claude BASE TARGET
      BASE（リポジトリの settings.json）を TARGET（~/.claude/settings.json）へマージする。
      - リポジトリにあるキーはリポジトリの値で上書き（hooks などはまるごと管理）
      - permissions.allow / deny / ask は和集合（手元で足したルールは残す）
      - リポジトリにないキー（theme など Claude 自身が書く設定）はそのまま

  merge_ai_config.py codex BASE TARGET [MCP_JSON]
      BASE（リポジトリの config.toml）と MCP_JSON（config/ai/mcp.json から生成した
      [mcp_servers.*]）を TARGET（~/.codex/config.toml）へ差し込む。
      - トップレベルのキーは先頭の管理ブロックに、テーブルは 2 つ目の管理ブロックに置く
        （手元のトップレベルのキーが管理テーブルの中に入らないようにするため）
      - Codex が書いたもの（[projects] の信頼設定、model など）はそのまま残す。
        Codex は新しいテーブルを末尾コメントの手前に挿入するので、管理ブロック内に
        入り込んだ管理対象外のテーブルも消さずにブロックの外へ出す
      - 同じキー・テーブルが手元にあれば管理側を優先して手元のものは取り除く

  merge_ai_config.py claude-mcp MCP_JSON CLAUDE_JSON
      MCP_JSON のうち、CLAUDE_JSON（~/.claude.json）のユーザースコープに未登録か内容が
      違うものを「名前<TAB>JSON」の形で出力する（install.sh が claude mcp add-json する）。

変更がなければ何もしない。終了コード: 0=変更なし 10=更新した 1=エラー
"""

import json
import re
import sys
import tomllib
from pathlib import Path

CHANGED = 10
NOTE = "（install.sh が管理。編集は dotfiles の config/codex/config.toml へ）"
TOP_BEGIN = f"# >>> dotfiles: top-level {NOTE} >>>"
TOP_END = "# <<< dotfiles: top-level <<<"
TBL_BEGIN = f"# >>> dotfiles: tables {NOTE} >>>"
TBL_END = "# <<< dotfiles: tables <<<"
MARKERS = {TOP_BEGIN, TOP_END, TBL_BEGIN, TBL_END}
HEADER_RE = re.compile(r"^\s*\[\[?\s*(.+?)\s*\]\]?\s*(#.*)?$")
KEY_RE = re.compile(r"^\s*([A-Za-z0-9_-]+|\"[^\"]*\")\s*=")


# --------------------------------------------------------------------------- claude
def deep_merge(cur, base):
    if isinstance(cur, dict) and isinstance(base, dict):
        out = dict(cur)
        for k, v in base.items():
            out[k] = deep_merge(cur.get(k), v) if k in cur else v
        return out
    return base


def merge_claude(base_path: Path, target: Path) -> int:
    base = json.loads(base_path.read_text())
    cur_text = target.read_text() if target.exists() else ""
    cur = json.loads(cur_text) if cur_text.strip() else {}
    merged = deep_merge(cur, base)
    for key in ("allow", "deny", "ask"):
        rules = (cur.get("permissions", {}).get(key) or []) + (base.get("permissions", {}).get(key) or [])
        if rules:
            merged.setdefault("permissions", {})[key] = list(dict.fromkeys(rules))
    if merged == cur:
        return 0
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(merged, ensure_ascii=False, indent=2) + "\n")
    return CHANGED


# --------------------------------------------------------------------------- codex
def split_sections(lines):
    """行のリストを (トップレベル部分, [(テーブル名, 行のリスト), ...]) に分ける。"""
    head, sections = [], []
    for line in lines:
        m = HEADER_RE.match(line)
        if m:
            sections.append((m.group(1), [line]))
        elif sections:
            sections[-1][1].append(line)
        else:
            head.append(line)
    return head, sections


def strip_blank(lines):
    lines = list(lines)
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    return lines


def without_markers(lines, managed_keys):
    """管理ブロックを取り除く。ブロック内に Codex が書き込んだキーやテーブルは残す。"""
    out, in_block, keep = [], False, False
    for line in lines:
        s = line.strip()
        if s in (TOP_BEGIN, TBL_BEGIN):
            in_block, keep = True, False
            continue
        if s in (TOP_END, TBL_END):
            in_block = False
            continue
        if in_block and not keep:
            if HEADER_RE.match(line):
                keep = True  # 以降は Codex が挿入したテーブル（管理対象かどうかは後で判定）
            else:
                m = KEY_RE.match(line)
                if not (m and m.group(1) not in managed_keys):
                    continue  # 管理ブロックのコメント・空行・管理キーは捨てる
        out.append(line)
    return out


def codex_mcp_toml(mcp_path: Path) -> str:
    """config/ai/mcp.json を Codex の [mcp_servers.*] テーブルに変換する。"""
    servers = json.loads(mcp_path.read_text())
    out = []
    for name, spec in servers.items():
        key = name if re.fullmatch(r"[A-Za-z0-9_-]+", name) else json.dumps(name)
        out.append(f"[mcp_servers.{key}]")
        if spec.get("type") in ("http", "sse") or "url" in spec:
            out.append(f"url = {json.dumps(spec['url'])}")
        else:
            out.append(f"command = {json.dumps(spec['command'])}")
            if spec.get("args"):
                out.append(f"args = {json.dumps(spec['args'], ensure_ascii=False)}")
            if spec.get("env"):
                env = ", ".join(f"{json.dumps(k)} = {json.dumps(v)}" for k, v in spec["env"].items())
                out.append(f"env = {{ {env} }}")
            # npx は初回のダウンロードに時間がかかるので起動待ちを長めにする
            out.append("startup_timeout_sec = 60")
        out.append("")
    return "\n".join(out)


def claude_mcp_diff(mcp_path: Path, claude_json: Path) -> int:
    servers = json.loads(mcp_path.read_text())
    cur = {}
    if claude_json.exists() and claude_json.read_text().strip():
        cur = json.loads(claude_json.read_text()).get("mcpServers", {})
    for name, spec in servers.items():
        have = cur.get(name) or {}
        if any(have.get(k) != v for k, v in spec.items()):
            print(f"{name}\t{json.dumps(spec, ensure_ascii=False)}")
    return 0


def merge_codex(base_path: Path, target: Path, mcp_path: Path | None = None) -> int:
    base_text = base_path.read_text()
    if mcp_path:
        base_text = base_text.rstrip("\n") + "\n\n" + codex_mcp_toml(mcp_path)
    base = tomllib.loads(base_text)
    base_head, base_sections = split_sections(base_text.splitlines())
    managed_keys = {KEY_RE.match(l).group(1) for l in base_head if KEY_RE.match(l)}
    managed_tables = [name for name, _ in base_sections]

    def is_managed(name):
        return any(name == m or name.startswith(m + ".") for m in managed_tables)

    old_text = target.read_text() if target.exists() else ""
    if old_text.strip():
        tomllib.loads(old_text)  # 壊れた既存ファイルには手を出さない
    head, sections = split_sections(without_markers(old_text.splitlines(), managed_keys))
    head = strip_blank(l for l in head if not (KEY_RE.match(l) and KEY_RE.match(l).group(1) in managed_keys))
    sections = [(n, strip_blank(ls)) for n, ls in sections if not is_managed(n)]

    out = [TOP_BEGIN, *strip_blank(base_head), TOP_END, ""]
    if head:
        out += head + [""]
    if base_sections:
        out.append(TBL_BEGIN)
        for i, (_, ls) in enumerate(base_sections):
            out += ([""] if i else []) + strip_blank(ls)
        out += [TBL_END, ""]
    for _, ls in sections:
        out += ls + [""]
    new_text = "\n".join(out).rstrip("\n") + "\n"

    # 検証: TOML として正しく、管理している値がそのまま入っていること
    parsed = tomllib.loads(new_text)
    for k in managed_keys:
        if parsed.get(k) != base.get(k):
            raise ValueError(f"マージ結果の {k} が想定と異なります")

    if new_text == old_text:
        return 0
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(new_text)
    return CHANGED


def main() -> int:
    args = sys.argv[1:]
    usage_ok = (len(args) == 3 and args[0] in ("claude", "claude-mcp")) or (len(args) in (3, 4) and args[0] == "codex")
    if not usage_ok:
        print(__doc__, file=sys.stderr)
        return 1
    kind, paths = args[0], [Path(a) for a in args[1:]]
    try:
        if kind == "claude":
            return merge_claude(*paths)
        if kind == "claude-mcp":
            return claude_mcp_diff(*paths)
        return merge_codex(*paths)
    except (json.JSONDecodeError, tomllib.TOMLDecodeError, ValueError) as e:
        print(f"{paths[-1]}: マージできませんでした: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
