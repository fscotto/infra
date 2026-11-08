#!/usr/bin/env python3
"""Convert a ChatGPT data export into the shared AI agent memory tree.

Reads conversations.json from an official ChatGPT data export and writes
under dotfiles/common/.config/ai/memory/chatgpt/:

- transcripts/<date>-<slug>.md : one Markdown transcript per conversation
  (active branch only, visible user/assistant text messages)
- INDEX.md                    : dated index linking every transcript and
                                its distilled knowledge topic
- PENDING-DISTILLATION.md    : conversations not yet distilled into
                                knowledge/ topic files
- assets/                     : textual library assets; binary and personal
                                assets are only listed in assets/ASSETS.md

PII files (user.json, user_settings.json) are never imported, and personal
non-technical conversations are blocked by PRIVACY_BLOCKLIST_TITLES so they
never enter the memory tree (already-imported ones are pruned on re-run).

The conversion is incremental and idempotent: a transcript is rewritten
only when the conversation update_time changes, so re-running the script
on a newer export adds or refreshes conversations without touching the
rest.  Transcript files are never deleted, even if the source conversation
was removed upstream.

Usage:

    python3 scripts/chatgpt_export_to_memory.py --export-dir ~/Downloads/<export>

Optional working digests to support manual or AI-assisted distillation:

    python3 scripts/chatgpt_export_to_memory.py --export-dir ... \\
        --digest-dir /tmp/chatgpt-digests --digest-limit 40
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
import unicodedata
from datetime import datetime
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MEMORY_DIR = REPO_ROOT / "dotfiles/common/.config/ai/memory/chatgpt"

ALLOWED_ROLES = {"user", "assistant"}
ALLOWED_CONTENT_TYPES = {"text", "multimodal_text"}
TEXTUAL_ASSET_EXTENSIONS = {
    ".org", ".md", ".markdown", ".txt", ".log", ".conf", ".cfg",
    ".el", ".scm", ".c", ".h", ".sh", ".py", ".toml", ".yml",
}

ROLE_LABELS = {"user": "Utente", "assistant": "ChatGPT"}

# Personal, non-technical conversations must never enter the agent memory.
# Titles (NFKD-folded, lowercased, ASCII) matching any keyword are excluded
# on import and pruned from an existing meta on re-run.
PRIVACY_BLOCKLIST_TITLES = (
    "730", "mutuo", "consap", "bagagliaio", "cantina", "bollette",
    "tari", "condominial", "classe energetica", "tagliando",
    "revisione auto", "unificazione punti",
)


def is_private_title(title: str) -> bool:
    normalized = unicodedata.normalize("NFKD", title or "")
    folded = normalized.encode("ascii", "ignore").decode("ascii").lower()
    return any(keyword in folded for keyword in PRIVACY_BLOCKLIST_TITLES)


def slugify(text: str, limit: int = 60) -> str:
    """Return an ASCII, filesystem-safe slug for a conversation title."""
    normalized = unicodedata.normalize("NFKD", text or "")
    ascii_text = normalized.encode("ascii", "ignore").decode("ascii").lower()
    slug = re.sub(r"[^a-z0-9]+", "-", ascii_text).strip("-")
    return slug[:limit].rstrip("-") or "senza-titolo"


def fmt_date(epoch) -> str:
    if not epoch:
        return ""
    return datetime.fromtimestamp(epoch).strftime("%Y-%m-%d")


def fmt_datetime(epoch) -> str:
    if not epoch:
        return ""
    return datetime.fromtimestamp(epoch).strftime("%Y-%m-%d %H:%M")


def load_json(path: Path, default=None):
    if not path.is_file():
        return default
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def active_chain(conversation: dict) -> list[str]:
    """Return message node ids from root to current_node (active branch)."""
    mapping = conversation.get("mapping") or {}
    chain: list[str] = []
    node_id = conversation.get("current_node")
    while node_id and node_id in mapping:
        chain.append(node_id)
        node_id = mapping[node_id].get("parent")
    if chain:
        return list(reversed(chain))
    # Fallback for exports without current_node: longest root-to-leaf chain.
    roots = [nid for nid, node in mapping.items() if not node.get("parent")]
    best: list[str] = []
    stack = [(root, [root]) for root in roots]
    while stack:
        node_id, path = stack.pop()
        children = [c for c in mapping.get(node_id, {}).get("children", []) if c in mapping]
        if not children:
            if len(path) > len(best):
                best = path
            continue
        for child in children:
            stack.append((child, path + [child]))
    return best

def part_to_text(part):
    """Convert a message part into text, or a placeholder for non-text assets."""
    if isinstance(part, str):
        return part.strip() or None
    if isinstance(part, dict):
        text = part.get("text")
        if isinstance(text, str) and text.strip():
            return text.strip()
        return "[allegato non testuale]"
    return None


def extract_messages(conversation: dict) -> list[dict]:
    """Extract visible user/assistant text messages from the active branch."""
    mapping = conversation.get("mapping") or {}
    messages: list[dict] = []
    for node_id in active_chain(conversation):
        message = (mapping.get(node_id) or {}).get("message") or {}
        role = (message.get("author") or {}).get("role")
        if role not in ALLOWED_ROLES:
            continue
        metadata = message.get("metadata") or {}
        if metadata.get("is_visually_hidden_from_conversation"):
            continue
        if metadata.get("recipient") not in (None, "all"):
            continue
        content = message.get("content") or {}
        if content.get("content_type") not in ALLOWED_CONTENT_TYPES:
            continue
        parts = [p for p in (part_to_text(x) for x in content.get("parts") or []) if p]
        if not parts:
            continue
        entry = {
            "role": role,
            "create_time": message.get("create_time"),
            "text": "\n\n".join(parts),
        }
        if messages and messages[-1]["role"] == role:
            messages[-1]["text"] += "\n\n" + entry["text"]
        else:
            messages.append(entry)
    return messages


def resolve_title(conversation: dict, messages: list[dict]) -> str:
    title = (conversation.get("title") or "").strip()
    if title and title != "New chat":
        return title
    for message in messages:
        if message["role"] == "user":
            first_line = message["text"].splitlines()[0] if message["text"] else ""
            snippet = re.sub(r"\s+", " ", first_line).strip()
            return (snippet[:70] + "...") if len(snippet) > 70 else snippet or "Senza titolo"
    return "Senza titolo"


def render_transcript(conversation: dict, title: str, messages: list[dict]) -> str:
    lines = [
        "---",
        f"conversation_id: {json.dumps(conversation.get('id') or '')}",
        f"title: {json.dumps(title, ensure_ascii=False)}",
        f"created: {fmt_date(conversation.get('create_time'))}",
        f"updated: {fmt_date(conversation.get('update_time'))}",
        f"model: {json.dumps(conversation.get('default_model_slug'))}",
        f"messages: {len(messages)}",
        "---",
        "",
        f"# {title}",
        "",
    ]
    for message in messages:
        stamp = fmt_datetime(message["create_time"])
        header = f"## {ROLE_LABELS[message['role']]} — {stamp}".rstrip(" —")
        lines += [header, "", message["text"], ""]
    return "\n".join(lines).rstrip() + "\n"

def update_transcripts(conversations: list, memory_dir: Path) -> dict:
    """Write new or updated transcripts; return the per-conversation meta map."""
    transcripts_dir = memory_dir / "transcripts"
    transcripts_dir.mkdir(parents=True, exist_ok=True)
    meta_path = memory_dir / ".meta.json"
    meta = load_json(meta_path, {}) or {}
    used_names = {record["file"] for record in meta.values() if record.get("file")}
    counting = {"new": 0, "updated": 0, "unchanged": 0, "empty": 0, "excluded": 0}

    for conversation in sorted(conversations, key=lambda c: c.get("create_time") or 0):
        conv_id = conversation.get("id")
        if not conv_id:
            counting["empty"] += 1
            continue
        messages = extract_messages(conversation)
        if not messages:
            counting["empty"] += 1
            continue
        title = resolve_title(conversation, messages)
        if is_private_title(title):
            counting["excluded"] += 1
            continue
        update_time = conversation.get("update_time") or conversation.get("create_time") or 0
        record = meta.get(conv_id) or {}
        if record.get("file"):
            filename = record["file"]
        else:
            stem = f"{fmt_date(conversation.get('create_time')) or 'senza-data'}-{slugify(title)}"
            if stem in used_names:
                stem = f"{stem}-{conv_id[:6]}"
            filename = f"{stem}.md"
            used_names.add(filename)
        path = memory_dir / "transcripts" / filename
        if record and record.get("update_time") == update_time and path.is_file():
            counting["unchanged"] += 1
        else:
            path.write_text(render_transcript(conversation, title, messages), encoding="utf-8")
            counting["updated" if record else "new"] += 1
        meta[conv_id] = {
            "file": filename,
            "title": title,
            "created": conversation.get("create_time"),
            "update_time": update_time,
            "messages": len(messages),
            "chars": sum(len(m["text"]) for m in messages),
        }
    # Prune conversations that fall under the privacy blocklist, removing
    # any transcript imported by previous runs.
    pruned = 0
    for conv_id in list(meta):
        if is_private_title(meta[conv_id].get("title", "")):
            stale_path = transcripts_dir / meta[conv_id].get("file", "")
            if stale_path.is_file():
                stale_path.unlink()
            del meta[conv_id]
            pruned += 1
    meta_path.write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return {"meta": meta, "counting": counting, "pruned": pruned}


def render_index(meta: dict, distilled: dict) -> str:
    records = sorted(
        (dict(value, conversation_id=key) for key, value in meta.items()),
        key=lambda r: r.get("created") or 0,
        reverse=True,
    )
    lines = [
        "# ChatGPT Memory — Index",
        "",
        "{} conversations imported from the official ChatGPT data export.".format(len(records)),
        "Structure: `transcripts/` (full active-branch transcripts), `knowledge/`",
        "(distilled topic files), `assets/` (textual attachments only).",
        "Search with ripgrep, e.g.:",
        "",
        "    rg -i \"<keyword>\" ~/.config/ai/memory/chatgpt/transcripts/",
        "",
        "| Updated | Title | Topic | Messages | Chars | Transcript |",
        "| --- | --- | --- | ---: | ---: | --- |",
    ]
    for record in records:
        topic = "—"
        distilled_record = distilled.get(record["conversation_id"])
        if distilled_record:
            topic_file = distilled_record["file"]
            topic = "[{}]({})".format(
                Path(topic_file).stem, Path("knowledge") / topic_file)
        lines.append("| {} | {} | {} | {} | {} | [transcript]({}) |".format(
            fmt_date(record.get("update_time")),
            record.get("title", "").replace("|", "\\|"),
            topic,
            record.get("messages", 0),
            record.get("chars", 0),
            Path("transcripts") / record.get("file", ""),
        ))
    return "\n".join(lines) + "\n"

def render_pending(meta: dict, distilled: dict) -> str:
    """Conversations not yet distilled, or updated after their distillation."""
    pending = []
    for conv_id, record in meta.items():
        done = distilled.get(conv_id)
        if not done or done.get("update_time", 0) != record.get("update_time", 0):
            pending.append(dict(record, conversation_id=conv_id))
    pending.sort(key=lambda r: r.get("chars", 0), reverse=True)
    lines = [
        "# Pending distillation",
        "",
        "Conversations not yet distilled into `knowledge/` topic files, most",
        "valuable first. After distilling, record the mapping in",
        "`knowledge/.distilled.json` and re-run",
        "`scripts/chatgpt_export_to_memory.py` to refresh this queue.",
        "",
    ]
    if pending:
        lines += [
            "| Chars | Updated | Title | Transcript |",
            "| ---: | --- | --- | --- |",
        ]
        for record in pending:
            lines.append("| {} | {} | {} | [transcript]({}) |".format(
                record.get("chars", 0),
                fmt_date(record.get("update_time")),
                record.get("title", "").replace("|", "\\|"),
                Path("transcripts") / record.get("file", ""),
            ))
    else:
        lines.append("Nothing pending: every conversation has a knowledge topic.")
    return "\n".join(lines) + "\n"


def process_assets(export_dir: Path, memory_dir: Path, conversations: list) -> None:
    titles = {c.get("id"): c.get("title") for c in conversations}
    excluded_ids = {
        c.get("id") for c in conversations
        if is_private_title(c.get("title") or "")
    }
    library = load_json(export_dir / "library_files.json", []) or []
    assets_dir = memory_dir / "assets"
    assets_dir.mkdir(parents=True, exist_ok=True)
    rows = []
    for entry in library:
        if entry.get("origination_thread_id") in excluded_ids:
            continue
        name = entry.get("file_name") or "senza-nome"
        file_id = entry.get("file_id") or ""
        dat_path = export_dir / f"{file_id}.dat"
        origin_id = entry.get("origination_thread_id")
        origin = titles.get(origin_id, origin_id or "—")
        size = entry.get("file_size_bytes")
        suffix = Path(name).suffix.lower()
        if not dat_path.is_file():
            rows.append((name, "missing", size, origin, "not present in this export"))
        elif suffix in TEXTUAL_ASSET_EXTENSIONS and (size or 0) < 2_000_000:
            shutil.copy2(dat_path, assets_dir / name)
            rows.append((name, "text", size, origin, "copied"))
        else:
            rows.append((name, "binary", size, origin, "listed only (privacy)"))
    lines = [
        "# Assets",
        "",
        "Binary and personal assets (PDFs, images) are deliberately not",
        "imported into the memory tree; they remain only in the original export.",
        "",
        "| Name | Kind | Size | Origin conversation | Action |",
        "| --- | --- | ---: | --- | --- |",
    ]
    for name, kind, size, origin, action in sorted(rows):
        size_text = str(size) if size else "—"
        lines.append(f"| {name} | {kind} | {size_text} | {origin} | {action} |")
    (assets_dir / "ASSETS.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

def write_digests(memory_dir: Path, meta: dict, digest_dir: Path, limit: int) -> None:
    """Write condensed per-conversation digests used for distillation work."""
    digest_dir.mkdir(parents=True, exist_ok=True)
    ranked = sorted(meta.items(), key=lambda item: item[1].get("chars", 0), reverse=True)
    if limit > 0:
        ranked = ranked[:limit]

    def cap(text: str, limit_chars: int) -> str:
        return text if len(text) <= limit_chars else text[:limit_chars] + "\n[…troncato]"

    for rank, (conv_id, record) in enumerate(ranked, start=1):
        transcript = memory_dir / "transcripts" / record["file"]
        if not transcript.is_file():
            continue
        text = transcript.read_text(encoding="utf-8")
        user_turns: list[str] = []
        assistant_turns: list[str] = []
        current: list[str] | None = None
        target: list[str] | None = None
        for line in text.splitlines():
            if line.startswith("## Utente") or line.startswith("## ChatGPT"):
                target = user_turns if line.startswith("## Utente") else assistant_turns
                current = []
                target.append(current)
            elif current is not None and line.strip():
                current.append(line)
        user_turns = ["\n".join(turn).strip() for turn in user_turns if "\n".join(turn).strip()]
        assistant_turns = ["\n".join(turn).strip() for turn in assistant_turns if "\n".join(turn).strip()]

        digest_path = digest_dir / f"{rank:02d}-{Path(record['file']).stem}.digest.md"
        lines = [
            f"# {record.get('title')}",
            "",
            "Conversation {} — {} to {} — {} messages, {} chars.".format(
                conv_id, fmt_date(record.get("created")), fmt_date(record.get("update_time")),
                record.get("messages"), record.get("chars")),
            f"Full transcript: {transcript}",
            "",
            "Condensed view: every user turn (capped), the opening assistant",
            "answer, and the closing assistant answers.",
            "",
        ]
        lines.append("## Tutti i turni Utente")
        lines.append("")
        for turn in user_turns:
            lines += [cap(turn, 1600), ""]
        if assistant_turns:
            lines += ["## Risposta ChatGPT iniziale", "", cap(assistant_turns[0], 2000), ""]
        for index, label in ((len(assistant_turns) - 2, "penultima"),
                             (len(assistant_turns) - 1, "ultima")):
            if 1 <= index < len(assistant_turns) and assistant_turns[index] != assistant_turns[0]:
                lines += [f"## Risposta ChatGPT {label}", "", cap(assistant_turns[index], 2600), ""]
        digest_path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--export-dir", type=Path, required=True,
                        help="ChatGPT data export directory")
    parser.add_argument("--memory-dir", type=Path, default=DEFAULT_MEMORY_DIR,
                        help="Memory destination directory (default: repo memory tree)")
    parser.add_argument("--digest-dir", type=Path, default=None,
                        help="Optional directory for distillation working digests")
    parser.add_argument("--digest-limit", type=int, default=0,
                        help="Write digests only for the N largest conversations (0 = all)")
    args = parser.parse_args()

    export_dir = args.export_dir.resolve()
    conversations = load_json(export_dir / "conversations.json")
    if conversations is None:
        parser.error(f"{export_dir / 'conversations.json'} not found — is this a ChatGPT export?")
    args.memory_dir.mkdir(parents=True, exist_ok=True)

    result = update_transcripts(conversations, args.memory_dir)
    meta, counting, pruned = result["meta"], result["counting"], result["pruned"]

    distilled = load_json(args.memory_dir / "knowledge" / ".distilled.json", {}) or {}
    distilled = {cid: rec for cid, rec in distilled.items() if cid in meta}
    distilled_path = args.memory_dir / "knowledge" / ".distilled.json"
    distilled_path.parent.mkdir(parents=True, exist_ok=True)
    distilled_path.write_text(
        json.dumps(distilled, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    (args.memory_dir / "INDEX.md").write_text(
        render_index(meta, distilled), encoding="utf-8")
    (args.memory_dir / "PENDING-DISTILLATION.md").write_text(
        render_pending(meta, distilled), encoding="utf-8")
    process_assets(export_dir, args.memory_dir, conversations)
    if args.digest_dir:
        write_digests(args.memory_dir, meta, args.digest_dir, args.digest_limit)

    total_chars = sum(r.get("chars", 0) for r in meta.values())
    print("Conversazioni nell'export: {}".format(len(conversations)))
    print("Transcripts: {new} nuovi, {updated} aggiornati, {unchanged} invariati,"
          " {empty} vuoti, {excluded} esclusi per privacy".format(**counting))
    print("Rimossi dall'albero (privacy): {}".format(pruned))
    print("Memoria: {} conversazioni, {} caratteri".format(len(meta), total_chars))
    print("Destinazione: {}".format(args.memory_dir))
    return 0


if __name__ == "__main__":
    sys.exit(main())




