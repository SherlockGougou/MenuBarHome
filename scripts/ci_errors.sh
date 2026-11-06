#!/usr/bin/env bash
# Print only the failure lines of a Forgejo Actions run, one screenful instead of the full log.
#
# Usage: bash scripts/ci_errors.sh <run-number>     # the number in .../actions/runs/<n>
#        bash scripts/ci_errors.sh <log-file>       # a log saved from the web UI ("Download logs")
# Fetches job logs through the web route with the same credentials as scripts/forge.py.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$#" -ne 1 ]; then
    echo "用法：bash scripts/ci_errors.sh <run-number|log-file>" >&2
    exit 2
fi

log="$(mktemp "${TMPDIR:-/tmp}/ci-errors.XXXXXX")"
trap 'rm -f "$log"' EXIT
if [ -f "$1" ]; then
    cp "$1" "$log"
else
    run="$1"
    web="$(python3 scripts/forge.py web)"
    # Forgejo 9 没有取日志的 API；按 job 序号逐个拉 web 日志，拉不到即没有更多 job。
    for job in $(seq 0 30); do
        python3 scripts/forge.py fetch "$web/actions/runs/$run/jobs/$job/logs" >"$log.job" 2>/dev/null || break
        sed "s/^/job $job\t/" "$log.job" >>"$log"
    done
    rm -f "$log.job"
fi

if [ ! -s "$log" ]; then
    echo "没有日志：$1（run 不存在、没有 runner 接单，或凭据无权访问）"
    exit 1
fi

echo "=== 有错误的 job"
grep -E 'error:|✘ (Test|Suite)|Test run with .* failed|##\[error\]|::error' "$log" | awk -F'\t' '!seen[$1]++ {print $1}' || true
echo "=== 错误与失败用例"
sed -E 's/^job [0-9]+\t//; s/^[0-9T:.Z-]+ ?//' "$log" |
    sed -E 's/\x1b\[[0-9;]*m//g' |
    grep -E 'error:|✘ (Test|Suite)|Test run with .* failed|##\[error\]|::error' |
    awk '!seen[$0]++' |
    head -60
