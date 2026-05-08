# AGENTS.md Manual Benchmark Checklist

ユーザー直下に配置する想定の `AGENTS.md` を評価するための手動チェックリストです。

評価は `Pass / Needs Review / Fail` で記録します。必要に応じて短いメモを残してください。

## Result

- Target file:
- Review date:
- Reviewer:
- Overall status: Pass / Needs Review / Fail
- Metrics score:
- Metrics status:

## Metrics

まず以下を実行し、数値を記録します。

```powershell
.\scripts\measure-agents.ps1 -Path .\AGENTS.md
```

数値は絶対的な品質評価ではありません。`AGENTS.md` が長くなりすぎて、重要な指示が埋もれていないかを見るための補助指標です。

ユーザー直下用 `AGENTS.md` は、token消費を抑えるためEnglishで書く方針です。ただし、ユーザーへの通常応答は日本語を基本にする方針を明記します。

## Checklist

| Check | Status | Notes |
| --- | --- | --- |
| ユーザー直下用 `AGENTS.md` をEnglishで記載する方針が明確か |  |  |
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

## Notes

- Strengths:
- Needs review:
- Recommended edits:
