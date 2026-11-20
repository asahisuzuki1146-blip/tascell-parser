# 拡張C → 拡張SC パーザ

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

## 開発の流れ

```
src/
├── TascellC.rats   ← 拡張C文法（Rats! で書く）
├── hello.tc        ← テスト用の拡張Cソース
└── ...
```

1. `src/TascellC.rats` に文法を書く
2. コンテナ内で `java xtc.parser.Rats src/TascellC.rats` を実行 → Java パーサが生成される
3. `javac` でコンパイルして `src/hello.tc` をパース
4. AST を走査して SC の S 式を出力
