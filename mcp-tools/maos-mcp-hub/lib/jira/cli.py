#!/usr/bin/env python3
"""
Jira CLI wrapper — thin sync interface over async JiraClient.

Usage:
    python3 -m lib.jira.cli get-issue VKS-1134 [--format markdown|raw]
    python3 -m lib.jira.cli list-attachments VKS-1134
    python3 -m lib.jira.cli download-attachment VKS-1134 v1-structured.md [--output FILE]
    python3 -m lib.jira.cli upload-attachment VKS-1134 /path/to/file.md
    python3 -m lib.jira.cli delete-attachment 10001
"""

import argparse
import asyncio
import json
import sys
import os

# Ensure hub root is in sys.path for `lib` imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", ".."))

# Load .env if available
try:
    from dotenv import load_dotenv
    load_dotenv(os.path.join(os.path.dirname(__file__), "..", "..", ".env"))
except ImportError:
    pass

from lib.jira.client import JiraClient


def main():
    parser = argparse.ArgumentParser(description="Jira CLI wrapper for maos-mcp-hub")
    sub = parser.add_subparsers(dest="command", required=True)

    # get-issue
    p_get = sub.add_parser("get-issue", help="Get issue details")
    p_get.add_argument("issue_key", help="Issue key (e.g., VKS-1134)")
    p_get.add_argument("--format", choices=["markdown", "raw", "json"], default="markdown",
                        help="Output format (default: markdown)")

    # list-attachments
    p_list = sub.add_parser("list-attachments", help="List attachments on an issue")
    p_list.add_argument("issue_key", help="Issue key (e.g., VKS-1134)")

    # download-attachment
    p_dl = sub.add_parser("download-attachment", help="Download attachment by filename")
    p_dl.add_argument("issue_key", help="Issue key (e.g., VKS-1134)")
    p_dl.add_argument("filename", help="Attachment filename")
    p_dl.add_argument("--output", "-o", help="Output file path (default: stdout)")

    # upload-attachment
    p_up = sub.add_parser("upload-attachment", help="Upload file as attachment")
    p_up.add_argument("issue_key", help="Issue key (e.g., VKS-1134)")
    p_up.add_argument("filepath", help="Local file path to upload")
    p_up.add_argument("--filename", help="Override attachment filename")

    # delete-attachment
    p_del = sub.add_parser("delete-attachment", help="Delete attachment by ID")
    p_del.add_argument("attachment_id", help="Attachment ID (numeric)")

    args = parser.parse_args()
    client = JiraClient()

    if args.command == "get-issue":
        issue = asyncio.run(client.get_issue(args.issue_key))
        fields = issue.get("fields", {})
        desc = fields.get("description")

        if args.format == "json":
            print(json.dumps(issue, indent=2, ensure_ascii=False))
        elif args.format == "raw":
            print(json.dumps(desc, indent=2, ensure_ascii=False))
        else:
            # markdown output
            from servers.jira.tools import _adf_to_markdown
            summary = fields.get("summary", "")
            status = (fields.get("status") or {}).get("name", "")
            labels = ", ".join(fields.get("labels", []))
            desc_md = _adf_to_markdown(desc) if isinstance(desc, dict) else (desc or "")

            print(f"# {issue.get('key', '')} — {summary}")
            print(f"\n**Status**: {status}")
            if labels:
                print(f"**Labels**: {labels}")
            print(f"\n---\n")
            print(desc_md)

    elif args.command == "list-attachments":
        attachments = asyncio.run(client.list_attachments(args.issue_key))
        for att in attachments:
            size_kb = att.get("size", 0) / 1024
            print(f"  {att['id']:>8}  {att['filename']:<40}  {size_kb:>8.1f} KB  {att.get('mimeType', '')}")

    elif args.command == "download-attachment":
        content = asyncio.run(client.download_attachment_by_name(args.issue_key, args.filename))
        if args.output:
            with open(args.output, "wb") as f:
                f.write(content)
            print(f"Downloaded {len(content)} bytes to {args.output}", file=sys.stderr)
        else:
            try:
                sys.stdout.write(content.decode("utf-8"))
            except UnicodeDecodeError:
                sys.stdout.buffer.write(content)

    elif args.command == "upload-attachment":
        result = asyncio.run(client.upload_attachment(
            args.issue_key, args.filepath, args.filename
        ))
        print(json.dumps(result, indent=2, ensure_ascii=False))

    elif args.command == "delete-attachment":
        result = asyncio.run(client.delete_attachment(args.attachment_id))
        print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
