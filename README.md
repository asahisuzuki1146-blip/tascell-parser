# 拡張C ↔ 拡張SC パーザ

Tascell の並列構文（`worker`、`do_two`、`handles` など）を含む **拡張C** と、
Tascell コンパイラが処理する **拡張SC（S式形式のIR）** を相互変換するパーザです。

```
拡張C (.tc)  ──[Main]──▶  拡張SC (S式)
拡張SC (S式) ──[SCMain]──▶  拡張C (.tc)
```

Rats!/xtc (SuperC 同梱) を使った開発環境です。

## 前提

- Docker Desktop がインストールされていること

## セットアップ（初回のみ）

```bash
# このフォルダに入る
cd tascell-parser

# イメージをビルド（5〜10分かかります）
docker compose build
```

## コンテナを起動する

```bash
docker compose run --rm tascell-parser
```

起動するとコンテナの中に入ります（`root@...:/workspace#` のようなプロンプト）。

## 動作確認

コンテナ内で：

```bash
# Rats! が使えるか確認
java xtc.parser.Rats --help

# xtc のバージョン確認
java xtc.core.Tool --version
```

## ファイルの置き場所

| 場所 | 説明 |
|------|------|
| `src/` | ホスト側の作業フォルダ。ここに `.rats` 文法や `.tc` ファイルを置く |
| `/workspace/src/` | コンテナ内から見た同じフォルダ |
| `/opt/superc/xtc/` | Rats!/xtc 本体（参照用） |

## 使用手順

```bash
git clone https://github.com/asahisuzuki1146-blip/tascell-parser.git
cd tascell-parser
docker compose build
docker compose run --rm tascell-parser
```

---

## パーザの使い方

コンテナ内 (`/workspace`) で以下を実行します。

### 拡張C → 拡張SC（S式）

```bash
# src/ に置いた .tc ファイルをパース
java -cp $CLASSPATH:src Main < src/hello.tc
```

出力例（`src/hello.tc`）：

```
(def (hello n) (wfn void int)
  (begin (do-two (printf n) (printf n)) (hello n) ))
```

### 拡張SC（S式）→ 拡張C

```bash
java -cp $CLASSPATH:src SCMain < src/fib.sc
```

### パイプで往復変換

拡張C → S式 → 拡張C と通してパースできます。

```bash
java -cp $CLASSPATH:src Main < src/fib.tc | java -cp $CLASSPATH:src SCMain
```

入力した `.tc` と同等の拡張Cが再出力されれば正常です。

### サンプルファイル

`src/` にサンプルが同梱されています。

| ファイル | 内容 |
|----------|------|
| `hello.tc` | `do_two` を使ったシンプルな worker 関数 |
| `fib.tc` | task/worker による並列フィボナッチ |
| `fib_full.tc` | グローバル変数・確率関数込みの完全版フィボナッチ |
| `nq.tc` | N クイーン問題（配列・ネストした for ループ） |
| `ctest.tc` | 通常の C 関数 + worker 関数の混在 |
| `ctest2.tc` | ポインタ・配列・文字列リテラルを含む worker |
| `task_test.tc` | `task` / `task_exec` の最小構成 |

### 自分で .tc ファイルを書くとき

ホスト側の `src/` フォルダに `.tc` ファイルを置けば、コンテナ内の `/workspace/src/` からそのまま参照できます。

```bash
# ホスト側で src/mycode.tc を作成し、コンテナ内で
java -cp $CLASSPATH:src Main < src/mycode.tc
```

### 文法を拡張したいとき

`.rats` ファイルを編集後、コンテナ内で再コンパイルします。

```bash
# 文法ファイルを編集（ホスト側 src/ または コンテナ内 /workspace/src/）
java xtc.parser.Rats src/TascellC.rats
javac -cp $CLASSPATH:src src/TascellC.java src/Main.java

# SCParser も同様
java xtc.parser.Rats src/SCParser.rats
javac -cp $CLASSPATH:src src/SCParser.java src/SCMain.java
```
