#!/bin/bash
# 翌日タスク整理スクリプト
# Usage: ./scripts/prepare-tomorrow.sh [--auto]

set -euo pipefail

# 設定読み込み
CONFIG_FILE=".claude/task-config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: $CONFIG_FILE not found"
    exit 1
fi

REPO=$(jq -r '.repository' "$CONFIG_FILE")
PROJECT_NUMBER=$(jq -r '.project_number' "$CONFIG_FILE")
OWNER=$(echo "$REPO" | cut -d'/' -f1)

TOMORROW=$(date -d '1 day' +%Y-%m-%d 2>/dev/null || date -v+1d +%Y-%m-%d)
AUTO_MODE=${1:-""}

echo "=== 翌日タスク整理 ($TOMORROW) ==="
echo ""

# 1. Ready タスクから優先度順に取得（WIP制限: 3件）
echo "## 📋 Ready タスクから推奨タスクを選択"
READY_TASKS=$(gh project item-list "$PROJECT_NUMBER" --owner "$OWNER" --format json --limit 100 2>/dev/null | \
    jq -r '[.items[] | select(.status == "Ready")] |
    sort_by(.priority // "Low" | if . == "High" then 0 elif . == "Medium" then 1 else 2 end) |
    limit(3; .[])' || echo "[]")

READY_COUNT=$(echo "$READY_TASKS" | jq -s 'length')

if [ "$READY_COUNT" -eq 0 ]; then
    echo "Ready タスクがありません。Backlog から選択してください。"
    echo ""

    # Backlog から優先度順に表示
    echo "## 📦 Backlog タスク（優先度順）"
    gh project item-list "$PROJECT_NUMBER" --owner "$OWNER" --format json --limit 100 2>/dev/null | \
        jq -r '[.items[] | select(.status == "Backlog")] |
        sort_by(.priority // "Low" | if . == "High" then 0 elif . == "Medium" then 1 else 2 end) |
        limit(5; .[]) | "- \(.content.title) [Priority: \(.priority // "None")]"' || echo "- 取得エラー"
    echo ""
    exit 0
fi

echo "推奨タスク（優先度順、最大3件）:"
echo "$READY_TASKS" | jq -r '. | "- \(.content.title) [Priority: \(.priority // "None")] (Issue #\(.content.number))"'
echo ""

# 2. Target date を設定
if [ "$AUTO_MODE" == "--auto" ]; then
    echo "## 🔄 Target date を自動設定中..."
    echo "$READY_TASKS" | jq -r '.content.number' | while read -r issue_num; do
        # GraphQL で Project Item ID を取得
        ITEM_ID=$(gh api graphql -f query="
        {
          repository(owner: \"$(echo $OWNER)\", name: \"$(echo $REPO | cut -d'/' -f2)\") {
            issue(number: $issue_num) {
              projectItems(first: 1) {
                nodes { id }
              }
            }
          }
        }" --jq '.data.repository.issue.projectItems.nodes[0].id')

        # Target date を設定
        if [ -n "$ITEM_ID" ]; then
            gh project item-edit --project-id "PVT_kwHOCF3cD84BLntt" --id "$ITEM_ID" \
                --field-id "PVTF_lAHOCF3cD84BLnttzg7I8uo" --date "$TOMORROW" 2>/dev/null || true
            echo "  ✓ Issue #$issue_num に Target date を設定"
        fi
    done
    echo ""
    echo "✅ 翌日タスクの準備が完了しました"
else
    echo "手動モード: 上記タスクに Target date を設定するには、以下を実行:"
    echo "  ./scripts/prepare-tomorrow.sh --auto"
fi

echo ""
echo "---"
echo "Generated at: $(date +%Y-%m-%d\ %H:%M:%S)"
