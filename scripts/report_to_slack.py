#!/usr/bin/env python3
"""Copy a markdown report to the clipboard as rich text, ready to paste in Slack.

Only the subset used by the daily report is supported: paragraphs, nested
"- " lists (nesting is given by indentation), [links](url), bare URLs,
**bold**, _italic_ and `code`.

The HTML is placed in the clipboard with wl-copy, so a Wayland session is
needed. Use --print to see the HTML instead.
"""

import argparse
import html
import re
import subprocess
import sys
from pathlib import Path

LIST_ITEM = re.compile(r"^(?P<indent> *)[-*] +(?P<text>.*)$")

INLINE = re.compile(
    r"`(?P<code>[^`]+)`"
    r"|\[(?P<text>[^\]]+)\]\((?P<url>[^)\s]+)\)"
    r"|\*\*(?P<bold>.+?)\*\*"
    r"|(?<!\w)_(?P<italic>.+?)_(?!\w)"
    # Trailing punctuation is most likely part of the sentence, not the URL.
    r"|(?P<bare>https?://[^\s<]+[^\s<.,;:!?)])"
)


def render_inline(text: str) -> str:
    out = []
    pos = 0
    for match in INLINE.finditer(text):
        out.append(html.escape(text[pos : match.start()]))
        if match["code"] is not None:
            out.append(f"<code>{html.escape(match['code'])}</code>")
        elif match["url"] is not None:
            url = html.escape(match["url"])
            out.append(f'<a href="{url}">{render_inline(match["text"])}</a>')
        elif match["bold"] is not None:
            out.append(f"<b>{render_inline(match['bold'])}</b>")
        elif match["italic"] is not None:
            out.append(f"<i>{render_inline(match['italic'])}</i>")
        else:
            url = html.escape(match["bare"])
            out.append(f'<a href="{url}">{url}</a>')
        pos = match.end()
    out.append(html.escape(text[pos:]))
    return "".join(out)


def render(markdown: str) -> str:
    out = []
    paragraph: list[str] = []
    # Indentation width of each open list level.
    indents: list[int] = []

    def flush_paragraph() -> None:
        if paragraph:
            out.append(f"<p>{render_inline(' '.join(paragraph))}</p>")
            paragraph.clear()

    def close_lists(level: int) -> None:
        while len(indents) > level:
            out.append("</li></ul>")
            indents.pop()

    for line in markdown.splitlines():
        if not line.strip():
            flush_paragraph()
            continue

        item = LIST_ITEM.match(line)
        if not item:
            close_lists(0)
            paragraph.append(line.strip())
            continue

        flush_paragraph()
        indent = len(item["indent"])
        previous_level = len(indents)
        while indents and indent < indents[-1]:
            out.append("</li></ul>")
            indents.pop()
        if not indents or indent > indents[-1]:
            out.append("<ul><li>")
            indents.append(indent)
        elif len(indents) <= previous_level:
            out.append("</li><li>")
        out.append(render_inline(item["text"].strip()))

    flush_paragraph()
    close_lists(0)
    return '<meta charset="utf-8">' + "".join(out)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("report", help="markdown file, or - for stdin")
    parser.add_argument(
        "--print",
        action="store_true",
        help="print the HTML instead of copying it to the clipboard",
    )
    args = parser.parse_args()

    if str(args.report) == "-":
        markdown = sys.stdin.read()
    else:
        markdown = Path(args.report).read_text(encoding="utf-8")

    rich_text = render(markdown)

    if args.print:
        print(rich_text)
        return

    try:
        subprocess.run(
            ["wl-copy", "--type", "text/html"],
            input=rich_text.encode("utf-8"),
            check=True,
        )
    except FileNotFoundError:
        sys.exit("wl-copy not found. Install wl-clipboard, or use --print.")
    print("Report copied to the clipboard as rich text.")


if __name__ == "__main__":
    main()
