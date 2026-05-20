# AGENTSExample.md Manual Benchmark Checklist

ユーザー直下に配置する想定の `AGENTS.md` の候補である `AGENTSExample.md` を評価するための手動チェックリストです。

評価は `Pass / Needs Review / Fail` で記録します。必要に応じて短いメモを残してください。

## Result

- Target file:
- Review date:
- Reviewer:
- Overall status: Pass / Needs Review / Fail
- Metrics score:
- Metrics status:
- Harness score:
- Quality gate:

## Metrics

まず以下を実行し、数値を記録します。

```powershell
.\scripts\measure-agents.ps1 -Path .\AGENTSExample.md
```

数値は絶対的な品質評価ではありません。`AGENTSExample.md` が長くなりすぎて、重要な指示が埋もれていないかを見るための補助指標です。

ユーザー直下用 `AGENTS.md` の候補である `AGENTSExample.md` は、token消費を抑えるためEnglishで書く方針です。ただし、ユーザーへの通常応答は日本語を基本にする方針を明記します。

## Harness Score

次に以下を実行し、`AGENTSExample.md` がhome-level instructionsとして適切か確認します。

```powershell
.\scripts\evaluate-agents.ps1 -Path .\AGENTSExample.md
```

編集前後を比較する場合は、変更前のcopyを用意してから以下を実行します。

```powershell
.\scripts\evaluate-agents.ps1 -BeforePath .\AGENTS.before.md -AfterPath .\AGENTSExample.md
```

このscoreは絶対評価ではありません。特に以下の分類を見て、指示の置き場所を確認してください。

- Keep in global AGENTS.md
- Move to repo AGENTS.md
- Move to Skill
- Merge with similar rule
- Rewrite for clarity
- Remove

## Checklist

| Check | Status | Notes |
| --- | --- | --- |
| ユーザー直下用 `AGENTS.md` の候補である `AGENTSExample.md` をEnglishで記載する方針が明確か |  |  |
| 実装前にglobal / repo / Skillのどこへ置くべきか確認する方針があるか |  |  |
| Englishで記載する理由がtoken消費削減として明確か |  |  |
| 日本語応答方針が明確か |  |  |
| code、commands、pathsなどのtechnical identifiersをEnglishのまま扱う方針があるか |  |  |
| 作業前に影響範囲を確認する方針があるか |  |  |
| 破壊的変更を勝手に実行しない方針があるか |  |  |
| 既存構成・命名規則を優先する方針があるか |  |  |
| Git差分を小さく保つ方針があるか |  |  |
| public repository前提の機密情報配慮があるか |  |  |
| API key、token、`.env`、個人情報を含めない方針があるか |  |  |
| Windows PowerShell環境への配慮があるか |  |  |
| Linux commandとPowerShell commandを混同しない方針があるか |  |  |
| 不確実な点を推測として明記する方針があるか |  |  |
| 実行commandを必要に応じて説明する方針があるか |  |  |
| 既存のユーザー変更を勝手に戻さない方針があるか |  |  |
| 検証できなかったことを明記する方針があるか |  |  |
| 各ruleが全リポジトリ・全タスクで常時読む価値のあるglobal ruleか |  |  |
| repo固有の規約・directory・生成物保存先がglobal ruleに混ざっていないか |  |  |
| 詳細なworkflowやchecklistがSkill化候補として分離できるか |  |  |
| 抽象的な品質表現が具体的なDo / Do not / Prefer / When ruleになっているか |  |  |
| 意味が近いruleをmergeできる箇所がないか |  |  |
| 互いに判断を迷わせるconflict riskがないか |  |  |
| 追加したruleによってtoken costが増えすぎていないか |  |  |

## Notes

- Strengths:
- Needs review:
- Separation candidates:
- Merge candidates:
- Recommended edits:
