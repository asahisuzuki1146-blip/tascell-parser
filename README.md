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
  (begin (do-two (printf n) (printf n)) (hello n)))
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

### 変換の注意点

- SC→C では、複合式を常に括弧付きで出力します（例：`(* 2 (+ a b))` → `2 * (a + b)`）。
  文・条件・右辺・引数など外側の括弧が不要な位置では、一番外の括弧だけ外します。
  そのため往復後の `.tc` は元より括弧が増えることがありますが、意味は変わりません。
- 文字列中の `\n` は SC の `~%` に、`~` は `~~` に変換します（逆変換では元に戻します）。
  対応しているエスケープは `\n` `\t` `\\` `\"` `\'` で、それ以外はパースエラーにします。
- `*p` は `(mref p)`、`&x` は `(ptr x)` に変換します（SC の表記）。
- `task_exec`（PPoPP 2009 §4.2 の構文）は、現行 sc-tascell の `(def (task-body name) ...)` に変換します。
  `task-exec` という SC フォームは sc-tascell のルールに存在しないためです。
  SC→C では `task_body` として出力します。
- C の `x %= e` は `(= x (% x e))` に展開します。SC の `(%= ...)` は SC プリプロセッサの
  `%` 指令と衝突して sc2c が受け付けないためです（`x` に副作用がある場合は 2 回評価されます）。
- SC 側で未対応の形式（`do-many`、`dynamic-wind` の `:before` 形式など）は、関数呼び出しに
  化けずにパースエラーになります。

### テスト

```bash
SC_PREFIX=/opt/sc-tascell bash tests/run_tests.sh
```

次の 3 種類を自動で確認します。

1. 往復変換：`src/*.tc` を C→SC→C→SC と変換し、SC が一致すること（元の `.tc` との差分も表示）。
2. 意味の検証：`tests/expr.tc` を gcc で直接ビルドした実行結果を正解とし、
   「C→SC→sc2c→gcc」と「C→SC→C→gcc」の実行結果が一致すること。
3. Tascell：`src/fib_full.tc` を SC に変換してヘッダを付け、sc2c → gcc（ワーカランタイムとリンク）で
   ビルドし、1・2・4 ワーカで `fib(30) = 832040` になること。

作業ファイルは `tests/out/` に出力されます（sc-tascell のディレクトリは変更しません）。

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
