#!/usr/bin/env python3
"""Minimal Forgejo client for this repository; replaces the `gh` CLI after the move off GitHub.

The repository is read from `git remote get-url origin` (e.g. http://10.10.1.4:3000/jryang/MenuBarMijia.git).
Auth: $FORGEJO_TOKEN if set, otherwise the HTTP credential git already stores for that host
(`git credential fill`, the macOS keychain on this Mac). Requests bypass HTTP(S)_PROXY, because the
forge lives on the LAN and the local proxy cannot reach it.

  python3 scripts/forge.py issue list [--label L]... [--state open|closed|all] [--json]
  python3 scripts/forge.py issue view <n>                 # body, labels and comments
  python3 scripts/forge.py issue create --title T [--body-file F|-] [--label L]...
  python3 scripts/forge.py issue comment <n> --body-file F|-
  python3 scripts/forge.py issue edit <n> [--add-label L]... [--remove-label L]... [--assign-me]
  python3 scripts/forge.py issue close <n> [--comment-file F|-]
  python3 scripts/forge.py pr list [--state open|closed|all] [--json]
  python3 scripts/forge.py pr create --title T [--head BRANCH] [--base main] [--body-file F|-]
  python3 scripts/forge.py pr view <n>
  python3 scripts/forge.py pr checks <n>                  # commit statuses of the PR head
  python3 scripts/forge.py pr merge <n> [--method squash|merge|rebase] [--delete-branch]
  python3 scripts/forge.py api <METHOD> <path> [--data JSON|@file] [--paginate]
      <path> may contain {repo}, expanded to repos/<owner>/<name>.
  python3 scripts/forge.py web                            # print the repository web URL
  python3 scripts/forge.py fetch <url|path>               # raw authenticated GET (e.g. Actions job logs)
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

ORIGIN_RE = re.compile(r"^(?P<scheme>https?)://(?:[^@/]+@)?(?P<host>[^/]+)/(?P<owner>[^/]+)/(?P<name>[^/]+?)(?:\.git)?/?$")


class Forge:
    def __init__(self) -> None:
        url = subprocess.run(["git", "remote", "get-url", "origin"], capture_output=True, text=True, check=True).stdout.strip()
        match = ORIGIN_RE.match(url)
        if not match:
            sys.exit(f"❌ origin 不是 http(s) 形式的 Forgejo 地址：{url}")
        self.scheme, self.host = match["scheme"], match["host"]
        self.owner, self.name = match["owner"], match["name"]
        self.base = f"{self.scheme}://{self.host}"
        self.repo = f"repos/{self.owner}/{self.name}"
        self.web = f"{self.base}/{self.owner}/{self.name}"
        self._auth: str | None = None
        self._opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

    def auth_header(self) -> str:
        if self._auth is None:
            token = os.environ.get("FORGEJO_TOKEN")
            if token:
                self._auth = f"token {token}"
            else:
                query = f"protocol={self.scheme}\nhost={self.host}\n\n"
                out = subprocess.run(["git", "credential", "fill"], input=query, capture_output=True, text=True,
                                     env={**os.environ, "GIT_TERMINAL_PROMPT": "0"})
                fields = dict(line.split("=", 1) for line in out.stdout.splitlines() if "=" in line)
                if not fields.get("password"):
                    sys.exit(f"❌ 没有 {self.host} 的凭据：设置 FORGEJO_TOKEN，或先用 git 推送一次让钥匙串记住账号")
                pair = f"{fields.get('username', '')}:{fields['password']}".encode()
                self._auth = "Basic " + base64.b64encode(pair).decode()
        return self._auth

    def request(self, method: str, path: str, data=None, *, raw: bool = False):
        path = path.replace("{repo}", self.repo).lstrip("/")
        url = path if path.startswith("http") else f"{self.base}/api/v1/{path}"
        body = None if data is None else json.dumps(data).encode()
        req = urllib.request.Request(url, data=body, method=method.upper())
        req.add_header("Authorization", self.auth_header())
        req.add_header("Accept", "application/json")
        if body is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with self._opener.open(req, timeout=30) as resp:
                payload = resp.read()
                headers = resp.headers
        except urllib.error.HTTPError as error:
            detail = error.read().decode(errors="replace")[:500]
            sys.exit(f"❌ {method.upper()} {url} → HTTP {error.code}: {detail}")
        except urllib.error.URLError as error:
            sys.exit(f"❌ 连不上 {self.base}：{error.reason}")
        if raw:
            return payload, headers
        return json.loads(payload) if payload.strip() else None

    def paginate(self, path: str) -> list:
        items, page = [], 1
        sep = "&" if "?" in path else "?"
        while True:
            chunk = self.request("GET", f"{path}{sep}limit=50&page={page}")
            if not chunk:
                return items
            items.extend(chunk)
            if len(chunk) < 50:
                return items
            page += 1

    def label_ids(self, names: list[str]) -> list[int]:
        labels = {label["name"]: label["id"] for label in self.paginate("{repo}/labels")}
        missing = [name for name in names if name not in labels]
        if missing:
            sys.exit(f"❌ 仓库里没有这些标签：{', '.join(missing)}")
        return [labels[name] for name in names]

    def whoami(self) -> str:
        return self.request("GET", "user")["login"]


def read_text(spec: str | None) -> str:
    if spec is None:
        return ""
    if spec == "-":
        return sys.stdin.read()
    with open(spec, encoding="utf-8") as handle:
        return handle.read()


def pr_state(pr: dict) -> str:
    if pr.get("merged"):
        return "MERGED"
    return "OPEN" if pr.get("state") == "open" else "CLOSED"


def cmd_issue(forge: Forge, args) -> None:
    if args.action == "list":
        query = f"{{repo}}/issues?type=issues&state={args.state}"
        if args.label:
            query += "&labels=" + urllib.parse.quote(",".join(args.label))
        issues = forge.paginate(query)
        if args.json:
            json.dump(issues, sys.stdout, ensure_ascii=False, indent=2)
            print()
            return
        for issue in issues:
            labels = ",".join(label["name"] for label in issue.get("labels") or [])
            print(f"#{issue['number']}\t{issue['state']}\t{labels}\t{issue['title']}")
    elif args.action == "view":
        issue = forge.request("GET", f"{{repo}}/issues/{args.number}")
        comments = forge.paginate(f"{{repo}}/issues/{args.number}/comments")
        labels = ", ".join(label["name"] for label in issue.get("labels") or [])
        assignees = ", ".join(user["login"] for user in issue.get("assignees") or [])
        print(f"#{issue['number']} [{issue['state']}] {issue['title']}")
        print(f"labels: {labels or '-'}  assignees: {assignees or '-'}  url: {issue['html_url']}\n")
        print(issue.get("body") or "")
        for comment in comments:
            print(f"\n--- {comment['user']['login']} @ {comment['created_at']}\n{comment['body']}")
    elif args.action == "create":
        data = {"title": args.title, "body": read_text(args.body_file)}
        if args.label:
            data["labels"] = forge.label_ids(args.label)
        issue = forge.request("POST", "{repo}/issues", data)
        print(issue["html_url"])
    elif args.action == "comment":
        comment = forge.request("POST", f"{{repo}}/issues/{args.number}/comments", {"body": read_text(args.body_file)})
        print(comment["html_url"])
    elif args.action == "edit":
        if args.add_label:
            forge.request("POST", f"{{repo}}/issues/{args.number}/labels", {"labels": forge.label_ids(args.add_label)})
        for label_id in forge.label_ids(args.remove_label or []):
            forge.request("DELETE", f"{{repo}}/issues/{args.number}/labels/{label_id}")
        if args.assign_me:
            issue = forge.request("GET", f"{{repo}}/issues/{args.number}")
            names = {user["login"] for user in issue.get("assignees") or []} | {forge.whoami()}
            forge.request("PATCH", f"{{repo}}/issues/{args.number}", {"assignees": sorted(names)})
        print(f"{forge.web}/issues/{args.number}")
    elif args.action == "close":
        if args.comment_file:
            forge.request("POST", f"{{repo}}/issues/{args.number}/comments", {"body": read_text(args.comment_file)})
        forge.request("PATCH", f"{{repo}}/issues/{args.number}", {"state": "closed"})
        print(f"closed #{args.number}")


def cmd_pr(forge: Forge, args) -> None:
    if args.action == "list":
        prs = forge.paginate(f"{{repo}}/pulls?state={args.state}")
        if args.json:
            json.dump(prs, sys.stdout, ensure_ascii=False, indent=2)
            print()
            return
        for pr in prs:
            print(f"#{pr['number']}\t{pr_state(pr)}\t{pr['head']['ref']}\t{pr['title']}")
    elif args.action == "create":
        head = args.head or subprocess.run(["git", "branch", "--show-current"], capture_output=True, text=True, check=True).stdout.strip()
        data = {"title": args.title, "head": head, "base": args.base, "body": read_text(args.body_file)}
        pr = forge.request("POST", "{repo}/pulls", data)
        print(pr["html_url"])
    elif args.action == "view":
        pr = forge.request("GET", f"{{repo}}/pulls/{args.number}")
        print(f"#{pr['number']} [{pr_state(pr)}] {pr['title']}")
        print(f"{pr['head']['ref']} → {pr['base']['ref']}  mergeable: {pr.get('mergeable')}  url: {pr['html_url']}\n")
        print(pr.get("body") or "")
        for comment in forge.paginate(f"{{repo}}/issues/{args.number}/comments"):
            print(f"\n--- {comment['user']['login']} @ {comment['created_at']}\n{comment['body']}")
        for review in forge.request("GET", f"{{repo}}/pulls/{args.number}/reviews") or []:
            print(f"\n--- review {review['user']['login']} [{review['state']}]\n{review.get('body') or ''}")
    elif args.action == "checks":
        pr = forge.request("GET", f"{{repo}}/pulls/{args.number}")
        status = forge.request("GET", f"{{repo}}/commits/{pr['head']['sha']}/status")
        statuses = status.get("statuses") or []
        print(f"head {pr['head']['sha'][:7]}  combined: {status.get('state') or 'none'}")
        if not statuses:
            print("（还没有任何检查上报；用 bash scripts/check.sh --skip-snapshots 本地把关）")
        for item in statuses:
            print(f"{item['status']:8} {item['context']}  {item.get('target_url') or ''}")
        if any(item["status"] == "pending" for item in statuses):
            print("注意：没有注册 Actions runner 时 pending 永远不会结束，本地门禁才是闸门。")
        if status.get("state") in ("failure", "error"):
            sys.exit(1)
    elif args.action == "merge":
        data = {"Do": args.method, "delete_branch_after_merge": args.delete_branch}
        forge.request("POST", f"{{repo}}/pulls/{args.number}/merge", data)
        print(f"merged #{args.number} ({args.method})")


def cmd_api(forge: Forge, args) -> None:
    data = None
    if args.data is not None:
        data = json.loads(read_text(args.data[1:]) if args.data.startswith("@") else args.data)
    if args.paginate:
        result = forge.paginate(args.path)
    else:
        result = forge.request(args.method, args.path, data)
    json.dump(result, sys.stdout, ensure_ascii=False, indent=2)
    print()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="group", required=True)

    issue = sub.add_parser("issue").add_subparsers(dest="action", required=True)
    p = issue.add_parser("list"); p.add_argument("--label", action="append"); p.add_argument("--state", default="open"); p.add_argument("--json", action="store_true")
    p = issue.add_parser("view"); p.add_argument("number", type=int)
    p = issue.add_parser("create"); p.add_argument("--title", required=True); p.add_argument("--body-file"); p.add_argument("--label", action="append")
    p = issue.add_parser("comment"); p.add_argument("number", type=int); p.add_argument("--body-file", required=True)
    p = issue.add_parser("edit"); p.add_argument("number", type=int); p.add_argument("--add-label", action="append"); p.add_argument("--remove-label", action="append"); p.add_argument("--assign-me", action="store_true")
    p = issue.add_parser("close"); p.add_argument("number", type=int); p.add_argument("--comment-file")

    pr = sub.add_parser("pr").add_subparsers(dest="action", required=True)
    p = pr.add_parser("list"); p.add_argument("--state", default="open"); p.add_argument("--json", action="store_true")
    p = pr.add_parser("create"); p.add_argument("--title", required=True); p.add_argument("--head"); p.add_argument("--base", default="main"); p.add_argument("--body-file")
    p = pr.add_parser("view"); p.add_argument("number", type=int)
    p = pr.add_parser("checks"); p.add_argument("number", type=int)
    p = pr.add_parser("merge"); p.add_argument("number", type=int); p.add_argument("--method", default="squash", choices=["squash", "merge", "rebase"]); p.add_argument("--delete-branch", action="store_true")

    p = sub.add_parser("api"); p.add_argument("method"); p.add_argument("path"); p.add_argument("--data"); p.add_argument("--paginate", action="store_true")
    sub.add_parser("web")
    p = sub.add_parser("fetch"); p.add_argument("target")

    args = parser.parse_args()
    forge = Forge()
    if args.group == "issue":
        cmd_issue(forge, args)
    elif args.group == "pr":
        cmd_pr(forge, args)
    elif args.group == "api":
        cmd_api(forge, args)
    elif args.group == "fetch":
        payload, _ = forge.request("GET", args.target, raw=True)
        sys.stdout.buffer.write(payload)
    else:
        print(forge.web)


if __name__ == "__main__":
    main()
