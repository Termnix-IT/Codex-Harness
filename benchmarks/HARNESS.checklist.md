# Harness Manual Benchmark Checklist

このリポジトリ自体が、home-level `AGENTS.md` の候補である `AGENTSExample.md` を安全に見直すための最低限の床として機能しているかを確認する手動チェックリストです。

評価は高得点を目指すためではなく、明らかな劣化や運用破綻を見つけるために使います。

## Result

- Review date:
- Reviewer:
- Overall status: Pass / Needs Review / Fail
- Harness validation result:
- Metrics score:
- Harness score:

## Automated Checks

まず以下を実行します。

```powershell
.\scripts\validate-harness.ps1 -Path .\AGENTSExample.md
```

このscriptは、主要ファイルの存在、READMEの説明、既存評価scriptの最低score floorを確認します。

必要に応じてfloorを変更して確認します。

```powershell
.\scripts\validate-harness.ps1 -Path .\AGENTSExample.md -MinimumMetricsScore 70 -MinimumHarnessScore 70
```

## Checklist

| Check | Status | Notes |
| --- | --- | --- |
| このrepoの目的が「高得点化」ではなく「最低限の劣化検知」として説明されているか |  |  |
| `AGENTSExample.md` がhome-level instructionの正本候補として扱われているか |  |  |
| root `AGENTS.md` がrepo専用指示で、global候補と重複していないか |  |  |
| `benchmarks/AGENTS.checklist.md` がglobal instructionsの手動確認に使えるか |  |  |
| `benchmarks/HARNESS.checklist.md` がrepo全体の手動確認に使えるか |  |  |
| `scripts/measure-agents.ps1` が過密化やcoverage不足を検出できるか |  |  |
| `scripts/evaluate-agents.ps1` がglobal / repo / skillの分離崩れを検出できるか |  |  |
| `scripts/validate-harness.ps1` が主要ファイル欠落や明らかな低scoreを検出できるか |  |  |
| READMEのDirectory Structureが実ファイルと概ね一致しているか |  |  |
| READMEのUsageが現在のscriptとchecklistに追従しているか |  |  |
| 自動scoreを絶対的な品質判定として扱わない注意が書かれているか |  |  |
| public repository前提の安全確認が残っているか |  |  |
| ユーザー直下 `AGENTS.md` を自動上書きしないMVP境界が残っているか |  |  |

## Notes

- Strengths:
- Needs review:
- Missing floor checks:
- Recommended edits:
