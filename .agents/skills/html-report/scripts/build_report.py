"""Wraps report body HTML into the report template.

Usage:
  python3 -I build_report.py --title "Title" --content body.html --out report.html
  python3 -I build_report.py --from old-report.html --out report.html   # re-wrap an existing report's <main>

The template adds the side contents, theme switch, reader mode, table wrapping and back-to-top.
"""
import argparse
import html
import pathlib
import re
import sys

TEMPLATE = pathlib.Path(__file__).resolve().parent.parent / "assets" / "report-template.html"


def extract_main(page):
    m = re.search(r"<main[^>]*>(.*)</main>", page, flags=re.S)
    if not m:
        sys.exit("No <main> element in the source report")
    return m.group(1).strip("\n")


def extract_title(page):
    m = re.search(r"<title>(.*?)</title>", page, flags=re.S)
    return html.unescape(m.group(1).strip()) if m else "Report"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--title")
    parser.add_argument("--content", help="file with the HTML that goes inside <main>")
    parser.add_argument("--from", dest="source", help="existing report whose <main> content is re-wrapped")
    parser.add_argument("--template", default=str(TEMPLATE))
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    if args.source:
        page = pathlib.Path(args.source).read_text()
        content = extract_main(page)
        title = args.title or extract_title(page)
    elif args.content:
        content = pathlib.Path(args.content).read_text()
        title = args.title or "Report"
    else:
        sys.exit("Pass --content or --from")

    template = pathlib.Path(args.template).read_text()
    out = template.replace("{{TITLE}}", html.escape(title)).replace("{{CONTENT}}", content)
    pathlib.Path(args.out).write_text(out)
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
