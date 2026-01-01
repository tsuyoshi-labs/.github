#!/bin/bash
# 日報生成スクリプト
# Usage: ./scripts/daily-report.sh

set -euxo pipefail

# 設定読み込み
CONFIG_FILE=".claude/task-config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: $CONFIG_FILE not found"
    exit 1
fi

REPO=$(jq -r '.repository' "$CONFIG_FILE")
PROJECT_NUMBER=$(jq -r '.project_number' "$CONFIG_FILE")
OWNER=$(echo "$REPO" | cut -d'/' -f1)

TODAY=$(date +%Y-%m-%d)
REPORT_DATE=$(date +%Y年%m月%d日)

echo "=== $REPORT_DATE 日報 ==="
echo ""

# 1. 今日完了したタスク
echo "## ✅ 完了したタスク"
DONE_ISSUES=$(gh issue list --repo "$REPO" --state closed --search "closed:$TODAY" --json number,title --limit 20)
DONE_COUNT=$(echo "$DONE_ISSUES" | jq 'length')

if [ "$DONE_COUNT" -eq 0 ]; then
    echo "- なし"
else
    echo "$DONE_ISSUES" | jq -r '.[] | "- #\(.number): \(.title)"'
fi
echo ""

# 2. 進行中のタスク（In progress / In review）
echo "## 🔄 進行中のタスク"
IN_PROGRESS=$(gh issue list --repo "$REPO" --state open --label task --json number,title,projectItems --limit 50 | \
    jq -r '[.[] | select(.projectItems[0]? and (.projectItems[0].status.name == "In progress" or .projectItems[0].status.name == "In review"))] |
    if length == 0 then "- なし" else .[] | "- #\(.number): \(.title) [\(.projectItems[0].status.name)]" end')
echo "$IN_PROGRESS"
echo ""

# 3. ブロックされているタスク（3日以上 In progress のまま）
echo "## ⚠️ ブロックされている可能性のあるタスク"
THREE_DAYS_AGO=$(date -d '3 days ago' +%Y-%m-%d 2>/dev/null || date -v-3d +%Y-%m-%d)
BLOCKED=$(gh issue list --repo "$REPO" --state open --label task --search "updated:<$THREE_DAYS_AGO" --json number,title,updatedAt --limit 10)
BLOCKED_COUNT=$(echo "$BLOCKED" | jq 'length')

if [ "$BLOCKED_COUNT" -eq 0 ]; then
    echo "- なし"
else
    echo "$BLOCKED" | jq -r '.[] | "- #\(.number): \(.title) (最終更新: \(.updatedAt | split("T")[0]))"'
fi
echo ""

# 4. 統計
echo "## 📊 統計"
TOTAL_OPEN=$(gh issue list --repo "$REPO" --state open --label task --json number | jq 'length')
echo "- 完了: $DONE_COUNT 件"
echo "- 進行中: $(echo "$IN_PROGRESS" | grep -c '^-' || echo 0) 件"
echo "- オープン: $TOTAL_OPEN 件"
echo ""

# 5. 明日の候補
echo "## 📅 明日の候補タスク"
TOMORROW=$(date -d '1 day' +%Y-%m-%d 2>/dev/null || date -v+1d +%Y-%m-%d)
TOMORROW_TASKS=$(gh project item-list "$PROJECT_NUMBER" --owner "$OWNER" --format json --limit 100 2>/dev/null | \
    jq -r --arg tomorrow "$TOMORROW" '[.items[] |
    select(.["target date"] == $tomorrow and .status != "Done")] |
    if length == 0 then "- 未設定（準備が必要）" else .[] | "- \(.content.title)" end' || echo "- 取得エラー")
echo "$TOMORROW_TASKS"
echo ""

echo "---"
echo "Generated at: $(date +%Y-%m-%d\ %H:%M:%S)"
