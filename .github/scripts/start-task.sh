#!/bin/bash
# タスク開始スクリプト
# Usage: ./scripts/start-task.sh <issue_number>

set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: ./scripts/start-task.sh <issue_number>"
    exit 1
fi

ISSUE_NUMBER=$1

# 設定読み込み
CONFIG_FILE=".claude/task-config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: $CONFIG_FILE not found"
    exit 1
fi

REPO=$(jq -r '.repository' "$CONFIG_FILE")
PROJECT_NUMBER=$(jq -r '.project_number' "$CONFIG_FILE")
OWNER=$(echo "$REPO" | cut -d'/' -f1)

echo "=== タスク開始: Issue #$ISSUE_NUMBER ==="
echo ""

# 1. Issue 情報を取得
ISSUE_INFO=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json title,labels,projectItems)
ISSUE_TITLE=$(echo "$ISSUE_INFO" | jq -r '.title')
ISSUE_LABEL=$(echo "$ISSUE_INFO" | jq -r '.labels[0].name // "task"')

echo "タイトル: $ISSUE_TITLE"
echo "ラベル: $ISSUE_LABEL"
echo ""

# 2. ブランチ名生成
BRANCH_NAME="feature/${ISSUE_NUMBER}-$(echo "$ISSUE_TITLE" | sed 's/[^a-zA-Z0-9]/-/g' | sed 's/--*/-/g' | tr '[:upper:]' '[:lower:]' | cut -c1-50)"
echo "ブランチ名: $BRANCH_NAME"
echo ""

# 3. ブランチ作成
if git rev-parse --verify "$BRANCH_NAME" >/dev/null 2>&1; then
    echo "⚠️  ブランチ $BRANCH_NAME は既に存在します"
    git checkout "$BRANCH_NAME"
else
    git checkout -b "$BRANCH_NAME"
    echo "✅ ブランチを作成しました"
fi
echo ""

# 4. 成果物フォルダ作成
if [ "$ISSUE_LABEL" == "research" ]; then
    FOLDER="docs/research/${ISSUE_NUMBER}_$(echo "$ISSUE_TITLE" | sed 's/[^a-zA-Z0-9]/_/g' | tr '[:upper:]' '[:lower:]' | cut -c1-30)"
    mkdir -p "$FOLDER"
    echo "✅ 調査フォルダを作成: $FOLDER"
elif [ "$ISSUE_LABEL" == "task" ]; then
    FOLDER="docs/task-management"
    echo "ℹ️  タスク管理ドキュメントフォルダ: $FOLDER"
else
    echo "ℹ️  成果物フォルダの作成をスキップ（ラベル: $ISSUE_LABEL）"
fi
echo ""

# 5. Project Status を In progress に変更
ITEM_ID=$(gh api graphql -f query="
{
  repository(owner: \"$OWNER\", name: \"$(echo $REPO | cut -d'/' -f2)\") {
    issue(number: $ISSUE_NUMBER) {
      projectItems(first: 1) {
        nodes { id }
      }
    }
  }
}" --jq '.data.repository.issue.projectItems.nodes[0].id')

if [ -n "$ITEM_ID" ] && [ "$ITEM_ID" != "null" ]; then
    gh project item-edit --project-id "PVT_kwHOCF3cD84BLntt" --id "$ITEM_ID" \
        --field-id "PVTSSF_lAHOCF3cD84BLnttzg7I8t4" --single-select-option-id "47fc9ee4" 2>/dev/null || true
    echo "✅ Project Status を In progress に変更"

    # Start date を設定
    TODAY=$(date +%Y-%m-%d)
    gh project item-edit --project-id "PVT_kwHOCF3cD84BLntt" --id "$ITEM_ID" \
        --field-id "PVTF_lAHOCF3cD84BLnttzg7I8uk" --date "$TODAY" 2>/dev/null || true
    echo "✅ Start date を設定"
else
    echo "⚠️  Project Item が見つかりません"
fi
echo ""

# 6. @codex に通知
gh issue comment "$ISSUE_NUMBER" --repo "$REPO" --body "@codex このタスクを開始しました。

以下を確認してください：
1. 実装方針が明確か
2. 受け入れ条件が適切か
3. 必要なリソースが揃っているか
4. サポートが必要な箇所はないか

よろしくお願いします。" 2>/dev/null || echo "⚠️  @codex への通知に失敗しました"

echo ""
echo "✅ タスク開始の準備が完了しました"
echo "次のステップ: コードを書いて、コミット・PRを作成してください"
