# codex-harness

ユーザー直下の `AGENTS.md` を安全に育てるためのハーネスリポジトリです。

このリポジトリは、home-level `AGENTS.md` の正本候補である `AGENTSExample.md`、モデルと公式資料の確認記録、静的評価script、手動の行動評価ケースを管理します。プロジェクト別テンプレート配布や汎用skill管理は対象外です。

このハーネスの目的は高得点を目指すことではありません。`AGENTSExample.md` や周辺運用が著しく悪化した時に気づける最低限の床を作り、低scoreや警告を改善判断の入口として使うことを目的にします。

![codex-harness overview](img/codex-harness.png)

MVPではユーザー直下の `AGENTS.md` を自動上書きしません。反映前に内容を確認し、必要な差分だけを手動で取り込む運用を前提にします。

## Instruction Language Policy

`AGENTSExample.md`とリポジトリ用の`AGENTS.md`は、ユーザーが後からルールを読み返せるよう、本文と見出しを原則として日本語で記載します。可読性を優先し、コード、コマンド、ファイルパス、API名、JSONキーなどの技術的な識別子は元の表記を維持します。

指示ファイルの記述とユーザーへの通常応答は、ともに日本語を基本にします。言語の割合や文字数だけで実際のtoken消費を判定せず、日本語であることを理由に減点しません。

## Model And Guidance Review

評価対象は `benchmarks/model-profile.json` で管理します。現在の基準は `gpt-6-sol`、行動評価の比較条件は `medium` です。この設定は評価記録用であり、Codexアプリの選択モデルやユーザーの設定を書き換えません。

profileには公式資料、各資料が裏付ける範囲、確認日、再確認間隔を記録します。再確認間隔はこのrepoの運用値として30日とし、モデルやCodexの仕様を変更するときは期限前でも再確認します。`validate-harness.ps1` は期限到達・未来の日付・不正なprofileを失敗として報告します。日付だけを更新せず、対象モデルの公式資料を読み、評価基準と候補指示の前提を確認したうえで更新してください。

確認に使う一次資料と根拠の範囲は [model-profile.json](benchmarks/model-profile.json) の `sources` に集約します。GPT-6ガイドの行動特性の説明は主にAstraの観測に基づくため、Solでの効果は行動評価で確認します。AGENTS.mdの既定の32 KiBは読み込む指示全体の上限であり、モデルのcontext windowとは別です。

静的評価は公式資料を毎回取得せず、モデルも呼び出しません。期限内でも外部仕様の変更を自動検知する保証はありません。モデル変更時はprofileの対象モデルと根拠資料を更新し、同じ行動評価ケースを使って比較します。

## Directory Structure

```text
codex-harness/
├─ README.md
├─ AGENTS.md
├─ AGENTSExample.md
├─ benchmarks/
│  ├─ AGENTS.checklist.md
│  ├─ HARNESS.checklist.md
│  └─ model-profile.json
├─ img/
│  └─ codex-harness.png
└─ scripts/
   ├─ evaluate-agents.ps1
   ├─ harness-profile.ps1
   ├─ measure-agents.ps1
   ├─ test-harness.ps1
   └─ validate-harness.ps1
```

## Usage

### 1. `AGENTSExample.md` を調整する

リポジトリ直下の `AGENTSExample.md` を、ユーザー直下に置くhome-level agent instructionsの正本候補として編集します。root `AGENTS.md` はこのハーネスrepo自体の作業指示として使います。

実装前には、追加・変更するruleがglobal instructionsに入れるべきものか、repo `AGENTS.md` に留めるべきものか、Skillに分離すべきものかを確認します。

### 2. metricsを確認する

長さや情報密度の目安を数値で確認する場合は、`scripts/measure-agents.ps1` を実行します。

```powershell
.\scripts\measure-agents.ps1 -Path .\AGENTSExample.md
```

このscriptは以下の観点から `0-100` の簡易スコアを出します。

- 非空行数
- 文字数
- UTF-8 byte数
- section数
- bullet数
- 必須観点のcoverage

日本語文字の割合と140文字を超える行数は参考値として表示し、減点には使いません。短いファイルや見出しが少ないファイルも、それだけでは減点しません。スコアは文章の密度の目安であり、モデルのtoken数や指示遵守率ではありません。

### 3. harness scoreを確認する

`scripts/evaluate-agents.ps1` は、home-level `AGENTS.md` の候補である `AGENTSExample.md` を「常時読み込む設定ファイル」として管理するための評価を出します。

```powershell
.\scripts\evaluate-agents.ps1 -Path .\AGENTSExample.md
```

このscriptは以下の観点から `0-100` の目安スコア、警告、改善提案、分類を出します。

- Context Economy（文章量の目安）
- Clarity
- Actionability
- Global Relevance
- Duplication
- Conflict Risk
- Separation Fitness
- Autonomy Calibration（無条件の確認・読み込み・テスト・委譲による過剰な制約）

Gitの承認条件に `release` が含まれるだけではSkillへの移動候補にしません。重複の減点は空白・大文字小文字・末尾の句点を正規化した同一ルールに限定します。意味の重複や条件付きルール間の矛盾は手動でも確認してください。

日本語と英語の両方について、実行可能な表現、無条件の作業制約、曖昧な指示、指示の配置先、矛盾の候補を検出します。キーワードによる静的判定のため、言い換えを網羅するものではありません。

JSONで評価結果を取得する場合は `-AsJson` を指定します。別のprofileを使う場合は `-ProfilePath` を指定します。

```powershell
.\scripts\evaluate-agents.ps1 -Path .\AGENTSExample.md -AsJson
```

分類は以下の候補を出します。

- Keep in global AGENTS.md
- Move to repo AGENTS.md
- Move to Skill
- Merge with similar rule
- Rewrite for clarity
- Remove

編集前後を比較する場合は `-BeforePath` と `-AfterPath` を指定します。

```powershell
$beforePath = Join-Path $env:TEMP 'codex-harness-before.txt'
git show HEAD:AGENTSExample.md | Set-Content -LiteralPath $beforePath -Encoding UTF8
.\scripts\evaluate-agents.ps1 -BeforePath $beforePath -AfterPath .\AGENTSExample.md
```

この評価は絶対的な品質判定ではありません。誤検知を許容し、`AGENTSExample.md` を肥大化させずに改善するための判断材料として使います。評価基準のversionを出力し、変更前後を同じ基準で再評価します。旧versionの保存済みscoreと直接比較しないでください。

### 4. checklistで確認する

`benchmarks/AGENTS.checklist.md` を使い、`AGENTSExample.md` が必要な運用観点を満たしているか手動で確認します。

評価は `Pass / Needs Review / Fail` と短いメモで記録します。自動評価で警告された項目は、手動チェックで残す・移す・削る判断を確認します。`GPT-6 Sol Behavior Cases` のケースは、対象モデル・reasoning effort・読み込まれた指示・必要な権限を記録し、使い捨ての検証用repoで実施します。外部へのpush、公開、デプロイのケースはコマンドの提案と確認判断までを観察します。

静的チェックの成功を行動評価のPassとして転記しないでください。実行していないケースは `Not run` と記録します。指示変更後やモデル変更後は同じケースで、完了できたか、不要な確認・読み込み・テストが増えたか、既存変更を保護できたかを比較します。

### 5. harness自体を確認する

`scripts/validate-harness.ps1` は、このリポジトリが最低限のハーネスとして壊れていないかを確認します。

```powershell
.\scripts\validate-harness.ps1 -Path .\AGENTSExample.md
```

このscriptは、主要ファイルの存在、READMEの説明、profileの有効性と確認期限、既存評価scriptの正常終了と最低score floorを確認します。高得点を保証するものではなく、明らかな欠落や低scoreを検出するための簡易チェックです。`-SkipScriptRuns` でもprofileの確認期限は検査します。

評価器やprofileの処理を変更した場合は、回帰テストも実行します。追加のライブラリやAPI keyは不要です。

```powershell
.\scripts\test-harness.ps1
```

scriptは日本語の正規表現や検証データも扱うため、Windows PowerShell 5.1でも読み込めるUTF-8 BOM付きで保存します。PowerShell 7と5.1で回帰テストを確認できます。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-harness.ps1
```

手動では `benchmarks/HARNESS.checklist.md` を使い、README、scripts、checklists、MVP境界が互いにずれていないかを確認します。

## Public Safety Notes

public repositoryとして公開する前に、少なくとも以下を確認します。

- API keyやtokenを含めない。
- `.env` や実環境用configを含めない。
- 個人メールアドレスや個人パスを含めない。
- 内部IPアドレスや内部ネットワーク構成を不用意に書かない。
- READMEに実環境の詳細を書きすぎない。
- 画像や素材は公開利用できるものだけを含める。
- commit historyに機密情報が残っていないか確認する。

## Future Ideas

- LLM reviewを併用したscripted benchmarkの拡張
- ユーザー直下 `AGENTS.md` への安全な同期script
- GitHub Actionsでのpublic安全チェック
- private用とpublic用の設定分離
