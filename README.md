# codex-harness

ユーザー直下の `AGENTS.md` を安全に育てるためのハーネスリポジトリです。

このリポジトリは、home-level `AGENTS.md` の正本候補、手動チェックリスト、情報密度を測るmetrics scriptを管理します。プロジェクト別テンプレート配布や汎用skill管理はMVPの対象外です。

![codex-harness overview](img/codex-harness.png)

MVPではユーザー直下の `AGENTS.md` を自動上書きしません。反映前に内容を確認し、必要な差分だけを手動で取り込む運用を前提にします。

## Instruction Language Policy

ユーザー直下に置く想定の `AGENTS.md` は、token消費を少しでも抑えるためEnglishで記載します。

ただし、これはinstruction fileの記述言語の方針です。Codexのユーザーへの通常応答は、`AGENTS.md` 内で明示する通り日本語を基本にします。

## Directory Structure

```text
codex-harness/
├─ README.md
├─ AGENTS.md
├─ benchmarks/
│  └─ AGENTS.checklist.md
├─ img/
│  └─ codex-harness.png
└─ scripts/
   └─ measure-agents.ps1
```

## Usage

### 1. `AGENTS.md` を調整する

リポジトリ直下の `AGENTS.md` を、ユーザー直下に置くhome-level agent instructionsの正本候補として編集します。

### 2. metricsを確認する

長さや情報密度の目安を数値で確認する場合は、`scripts/measure-agents.ps1` を実行します。

```powershell
.\scripts\measure-agents.ps1 -Path .\AGENTS.md
```

このscriptは以下の観点から `0-100` の簡易スコアを出します。

- 非空行数
- 文字数
- 日本語文字の割合
- section数
- bullet数
- 140文字を超える行数
- 必須観点のcoverage

スコアは品質保証ではなく、情報を詰め込みすぎていないかを見るための目安です。

### 3. checklistで確認する

`benchmarks/AGENTS.checklist.md` を使い、`AGENTS.md` が必要な運用観点を満たしているか手動で確認します。

評価は `Pass / Needs Review / Fail` と短いメモで記録します。MVPでは自動採点やCodex模擬タスクによる評価は行いません。

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

- `validate-agents.ps1`
- scripted benchmarkの拡張
- prompt task benchmark
- ユーザー直下 `AGENTS.md` への安全な同期script
- GitHub Actionsでのpublic安全チェック
- private用とpublic用の設定分離
