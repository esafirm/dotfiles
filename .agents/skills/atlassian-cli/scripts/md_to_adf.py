#!/usr/bin/env python3
"""
Convert Markdown text to Atlassian Document Format (ADF) for Jira Cloud work items.

Supports:
- Headings (#, ##, ###, etc.)
- Paragraphs
- Markdown links [text](url) -> ADF link mark
- Standalone URLs -> ADF inlineCard (Smart Link)
- Bare URLs in text -> ADF link mark
- Bold (**text**) -> ADF strong mark
- Inline code (`code`) -> ADF code mark
- Italic (*text* / _text_) -> ADF em mark
- Bullet lists (- or *) -> ADF bulletList
- Ordered lists (1., 2., etc.) -> ADF orderedList
- Code blocks (```lang ... ```) -> ADF codeBlock
- Blockquotes (> text) -> ADF blockquote

Can output either raw ADF doc JSON or a full Jira work item JSON ready for `acli jira workitem create --from-json`.
"""

import sys
import os
import re
import json
import argparse


def parse_inline(text):
    content = []
    pattern = re.compile(
        r'(?P<md_link>\[(?P<link_text>[^\]]+)\]\((?P<link_url>[^\)]+)\))|'
        r'(?P<code>\`(?P<code_text>[^\`]+)\`)|'
        r'(?P<bold>\*\*(?P<bold_text>[^\*]+)\*\*)|'
        r'(?P<italic>(?<!\*)\*(?!\*)(?P<italic_text>[^\*]+)(?<!\*)\*(?!\*))|'
        r'(?P<url>https?://[^\s\)]+)'
    )
    last_idx = 0
    for m in pattern.finditer(text):
        start, end = m.span()
        if start > last_idx:
            content.append({'type': 'text', 'text': text[last_idx:start]})

        if m.group('md_link'):
            content.append({
                'type': 'text',
                'text': m.group('link_text'),
                'marks': [{'type': 'link', 'attrs': {'href': m.group('link_url')}}]
            })
        elif m.group('code'):
            content.append({
                'type': 'text',
                'text': m.group('code_text'),
                'marks': [{'type': 'code'}]
            })
        elif m.group('bold'):
            content.append({
                'type': 'text',
                'text': m.group('bold_text'),
                'marks': [{'type': 'strong'}]
            })
        elif m.group('italic'):
            content.append({
                'type': 'text',
                'text': m.group('italic_text'),
                'marks': [{'type': 'em'}]
            })
        elif m.group('url'):
            url = m.group('url')
            content.append({
                'type': 'text',
                'text': url,
                'marks': [{'type': 'link', 'attrs': {'href': url}}]
            })
        last_idx = end

    if last_idx < len(text):
        content.append({'type': 'text', 'text': text[last_idx:]})

    return content if content else [{'type': 'text', 'text': ''}]


def markdown_to_adf(md_text):
    doc = {'version': 1, 'type': 'doc', 'content': []}
    lines = md_text.splitlines()
    i = 0

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if not stripped:
            i += 1
            continue

        # Heading
        heading_match = re.match(r'^(#{1,6})\s+(.*)$', stripped)
        if heading_match:
            level = len(heading_match.group(1))
            h_text = heading_match.group(2)
            doc['content'].append({
                'type': 'heading',
                'attrs': {'level': level},
                'content': parse_inline(h_text)
            })
            i += 1
            continue

        # Code block
        if stripped.startswith('```'):
            lang = stripped[3:].strip()
            code_lines = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith('```'):
                code_lines.append(lines[i])
                i += 1
            if i < len(lines):
                i += 1  # skip closing ```
            doc['content'].append({
                'type': 'codeBlock',
                'attrs': {'language': lang or 'text'},
                'content': [{'type': 'text', 'text': '\n'.join(code_lines)}]
            })
            continue

        # Blockquote
        if stripped.startswith('>'):
            quote_text = stripped[1:].strip()
            doc['content'].append({
                'type': 'blockquote',
                'content': [{
                    'type': 'paragraph',
                    'content': parse_inline(quote_text)
                }]
            })
            i += 1
            continue

        # Bullet list
        if stripped.startswith(('- ', '* ')):
            bullet_items = []
            while i < len(lines) and lines[i].strip().startswith(('- ', '* ')):
                item_text = lines[i].strip()[2:]
                bullet_items.append({
                    'type': 'listItem',
                    'content': [{
                        'type': 'paragraph',
                        'content': parse_inline(item_text)
                    }]
                })
                i += 1
            doc['content'].append({
                'type': 'bulletList',
                'content': bullet_items
            })
            continue

        # Ordered list
        order_match = re.match(r'^\d+\.\s+(.*)$', stripped)
        if order_match:
            ordered_items = []
            while i < len(lines) and re.match(r'^\d+\.\s+(.*)$', lines[i].strip()):
                m = re.match(r'^\d+\.\s+(.*)$', lines[i].strip())
                ordered_items.append({
                    'type': 'listItem',
                    'content': [{
                        'type': 'paragraph',
                        'content': parse_inline(m.group(1))
                    }]
                })
                i += 1
            doc['content'].append({
                'type': 'orderedList',
                'content': ordered_items
            })
            continue

        # Standalone URL -> inlineCard (smart link)
        if re.match(r'^https?://[^\s]+$', stripped):
            doc['content'].append({
                'type': 'paragraph',
                'content': [{
                    'type': 'inlineCard',
                    'attrs': {'url': stripped}
                }]
            })
            i += 1
            continue

        # Regular paragraph
        doc['content'].append({
            'type': 'paragraph',
            'content': parse_inline(line)
        })
        i += 1

    return doc


def main():
    parser = argparse.ArgumentParser(description="Convert Markdown to Atlassian Document Format (ADF) JSON")
    parser.add_argument('--input', '-i', help="Path to input markdown file (default: stdin)")
    parser.add_argument('--output', '-o', help="Path to output json file (default: stdout)")
    parser.add_argument('--summary', '-s', help="Issue summary/title (wraps in full Jira workitem JSON)")
    parser.add_argument('--project', '-p', help="Jira project key (e.g. BLAN)")
    parser.add_argument('--type', '-t', default="Task", help="Work item type (default: Task)")
    parser.add_argument('--assignee', '-a', help="Assignee email, account ID, or @me")
    parser.add_argument('--stream', help="BandLab Stream custom field value (e.g. Other, Social, Studio)")
    parser.add_argument('--raw-adf', action='store_true', help="Only output ADF document, not workitem envelope")

    args = parser.parse_args()

    if args.input:
        with open(args.input, 'r', encoding='utf-8') as f:
            md_text = f.read()
    else:
        md_text = sys.stdin.read()

    adf_doc = markdown_to_adf(md_text)

    if args.raw_adf or not (args.summary or args.project):
        output_data = adf_doc
    else:
        output_data = {
            "projectKey": args.project or "BLAN",
            "type": args.type,
            "summary": args.summary or "New Task",
            "description": adf_doc
        }
        if args.assignee:
            output_data["assignee"] = args.assignee
        if args.stream:
            output_data.setdefault("additionalAttributes", {})["customfield_12385"] = {
                "value": args.stream
            }

    json_str = json.dumps(output_data, indent=2, ensure_ascii=False)

    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(json_str + '\n')
    else:
        sys.stdout.write(json_str + '\n')


if __name__ == '__main__':
    main()
