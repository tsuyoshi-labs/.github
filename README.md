# .github

このリポジトリは、tsuyoshi-labs配下のすべてのリポジトリで共有される設定を管理します。

## 内容

### Issue/PRテンプレート

`.github/ISSUE_TEMPLATE/` および `.github/pull_request_template.md` に配置されたテンプレートは、
組織内のすべてのリポジトリで自動的に利用可能になります。

- **Goal**: 年次目標・長期的な方針
- **Epic**: 複数タスクで構成される成果物
- **Task**: 1日以内で完了する具体的なタスク

### Reusable Workflows

`.github/workflows/` に配置されたワークフローは、他のリポジトリから呼び出し可能です。

#### add-to-project.yml

Issueを自動的にGitHub Projectに追加します。

使用例:
```yaml
name: Add to Project
on:
  issues:
    types: [opened, labeled, reopened]

jobs:
  add-to-project:
    uses: tsuyoshi-labs/.github/.github/workflows/add-to-project.yml@main
    with:
      project-url: https://github.com/users/tsuyoshi-labs/projects/YOUR_PROJECT_NUMBER
      labeled: 'goal, epic, task'
      label-operator: OR
    secrets:
      ADD_TO_PROJECT_PAT: ${{ secrets.ADD_TO_PROJECT_PAT }}
```

### Scripts

`.github/scripts/` に配置されたスクリプトは、ワークフローで使用されます。

## 使用方法

各リポジトリでこれらのテンプレートとワークフローを使用するには:

1. **Issue/PRテンプレート**: 自動的に利用可能（設定不要）
2. **Reusable Workflows**: 各リポジトリの `.github/workflows/` で上記の例のように呼び出す
