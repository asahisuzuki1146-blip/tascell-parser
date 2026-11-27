#!/bin/bash
# 拡張C ↔ 拡張SC パーザのテスト
#
#   [1] 往復変換: src/*.tc を C→SC→C→SC と変換し、SC が一致すること (不動点)。
#       元の .tc との差分も表示する (括弧の追加など、意味の変わらない差分は残る)。
#   [2] 意味の検証: tests/expr.tc を gcc で直接ビルドした結果を正解とし、
#         拡張C → SC → sc2c → gcc
#         拡張C → SC → 拡張C → gcc
#       の実行結果が一致すること。
#   [3] Tascell: src/fib_full.tc → SC → sc2c → gcc (ワーカランタイムとリンク) を
#       1, 2, 4 ワーカで実行し、fib(30) = 832040 になること。
#
# 必要なもの: Java, Rats! (rats.jar), gcc, clisp, ビルド済みの sc-tascell (c2scpp)
# 環境変数 SC_PREFIX で sc-tascell の場所を指定する (既定: /opt/sc-tascell)。

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/tests/out"
SC_PREFIX="${SC_PREFIX:-/opt/sc-tascell}"
export SC_PREFIX SC_PATH="$SC_PREFIX/bin" SC_CMDLINE="$SC_PREFIX/src/sc-cmdline.lsp"
export SC_LISP="${SC_LISP:-clisp}" SC_LISP_PATH="${SC_LISP_PATH:-$(command -v clisp)}"
export PATH="$SC_PREFIX/bin:$PATH"
RATS_CP="${RATS_CP:-/usr/share/java/rats-runtime.jar:/usr/share/java/rats.jar}"
unset JAVA_TOOL_OPTIONS

PASS=0; FAIL=0
ok()   { echo "  ok   $*"; PASS=$((PASS + 1)); }
ng()   { echo "  FAIL $*"; FAIL=$((FAIL + 1)); }

rm -rf "$OUT/build" "$OUT/work"; mkdir -p "$OUT/build" "$OUT/work"

# ---- パーザのビルド ----
echo "== build"
cp "$ROOT"/src/{TascellC.rats,SCParser.rats,Main.java,SCMain.java} "$OUT/build/"
(
  cd "$OUT/build" &&
  java -cp "$RATS_CP" xtc.parser.Rats TascellC.rats >/dev/null &&
  java -cp "$RATS_CP" xtc.parser.Rats SCParser.rats >/dev/null &&
  javac -nowarn -cp "$RATS_CP" TascellC.java Main.java SCParser.java SCMain.java 2>&1 | grep -v '^Note'
) ; [ -f "$OUT/build/Main.class" ] && [ -f "$OUT/build/SCMain.class" ] || { echo "build failed"; exit 1; }
CP="$RATS_CP:$OUT/build"
c2sc() { java -cp "$CP" Main; }
sc2tc() { java -cp "$CP" SCMain; }

# sc2c で SC → C (入力と同じディレクトリに <name>.c が出る。indent が無い警告は無視)
run_sc2c() { (cd "$(dirname "$1")" && sc2c "$@" >"$(basename "$1").log" 2>&1); }

# ---- [1] 往復変換 ----
echo "== [1] round trip (C -> SC -> C -> SC)"
for src in "$ROOT"/src/*.tc; do
  n=$(basename "$src" .tc); w="$OUT/work/$n"
  if ! c2sc <"$src" >"$w.sc" 2>"$w.err"; then ng "$n: C->SC: $(head -1 "$w.err")"; continue; fi
  if ! sc2tc <"$w.sc" >"$w.rt.tc" 2>"$w.err"; then ng "$n: SC->C: $(head -1 "$w.err")"; continue; fi
  if ! c2sc <"$w.rt.tc" >"$w.sc2" 2>"$w.err"; then ng "$n: 再パース: $(head -1 "$w.err")"; continue; fi
  if cmp -s "$w.sc" "$w.sc2"; then
    d=$(diff -w "$src" "$w.rt.tc" | grep -c '^[<>]')
    ok "$n (元の .tc との差分 $d 行${d:+ : diff -w src/$n.tc tests/out/work/$n.rt.tc})"
  else
    ng "$n: SC が一致しない"; diff "$w.sc" "$w.sc2" | head -5
  fi
done

# ---- [2] 意味の検証 ----
echo "== [2] semantics (tests/expr.tc)"
E="$OUT/work/expr"
{ echo '#include <stdio.h>'; cat "$ROOT/tests/expr.tc"; } >"$E.ref.c"
if gcc -w -o "$E.ref" "$E.ref.c" && "$E.ref" >"$E.expected"; then
  # (1) C -> SC -> sc2c -> gcc
  if c2sc <"$ROOT/tests/expr.tc" >"$E.body.sc" 2>"$E.err"; then
    mkdir -p "$OUT/work/sc"
    { echo '(c-exp "#include <stdio.h>")'; cat "$E.body.sc"; } >"$OUT/work/sc/expr.sc"
    if run_sc2c "$OUT/work/sc/expr.sc" && gcc -w -o "$E.viasc" "$OUT/work/sc/expr.c" \
       && "$E.viasc" >"$E.viasc.out" && cmp -s "$E.expected" "$E.viasc.out"; then
      ok "C -> SC -> sc2c -> gcc"
    else
      ng "C -> SC -> sc2c -> gcc"; diff "$E.expected" "$E.viasc.out" 2>/dev/null | head -10
    fi
    # (2) C -> SC -> C -> gcc
    if sc2tc <"$E.body.sc" >"$E.rt.tc" 2>"$E.err" \
       && { echo '#include <stdio.h>'; cat "$E.rt.tc"; } >"$E.rt.c" \
       && gcc -w -o "$E.rt" "$E.rt.c" && "$E.rt" >"$E.rt.out" && cmp -s "$E.expected" "$E.rt.out"; then
      ok "C -> SC -> C -> gcc"
    else
      ng "C -> SC -> C -> gcc"; diff "$E.expected" "$E.rt.out" 2>/dev/null | head -10
    fi
  else
    ng "expr.tc: C->SC: $(head -1 "$E.err")"
  fi
else
  ng "expr.tc を gcc で直接ビルドできない"
fi

# ---- [3] Tascell ----
echo "== [3] tascell (src/fib_full.tc, fib(30))"
T="$OUT/tcell"
if [ ! -d "$SC_PREFIX/src/sample/tcell" ]; then
  ng "sc-tascell が見つからない (SC_PREFIX=$SC_PREFIX)"
else
  # sc-tascell を汚さないよう、サンプルディレクトリを作業用にコピーして使う
  if [ ! -f "$T/runtime.ok" ]; then
    rm -rf "$T"; cp -r "$SC_PREFIX/src/sample/tcell" "$T"
    if run_sc2c "$T/worker.sc" -D NF-TYPE=GCC && run_sc2c "$T/cmd-serial.sc" -D NF-TYPE=GCC; then
      touch "$T/runtime.ok"
    fi
  fi
  if [ ! -f "$T/runtime.ok" ]; then
    ng "ワーカランタイム (worker.sc) のビルドに失敗"
  elif ! c2sc <"$ROOT/src/fib_full.tc" >"$T/gen.body.sc" 2>"$T/gen.err"; then
    ng "fib_full.tc: C->SC: $(head -1 "$T/gen.err")"
  else
    cat >"$T/gen.tcell" <<'HDR'
(c-exp "#include<sys/time.h>")
(%defconstant COUNT-NTASK 0)
(%defconstant USE-PROBGUARD 0)
(%ifndef* NF-TYPE (%defconstant NF-TYPE GCC))
(%include "rule/tcell-setrule.sh")
(%include "clib.sh")
HDR
    cat "$T/gen.body.sc" >>"$T/gen.tcell"
    if run_sc2c "$T/gen.tcell" -D NF-TYPE=GCC && [ -f "$T/gen-gcc.c" ] \
       && gcc -O2 -w -o "$T/gen-fib" "$T/worker-gcc.c" "$T/cmd-serial-gcc.c" "$T/sendrecv.c" "$T/sock.c" \
              "$T/gen-gcc.c" -lpthread -lm; then
      # fib_full.tc ではタスク 0 = fib, 1 = fib_start
      for nw in 1 2 4; do
        r=$(cd "$T" && timeout 60 ./gen-fib -n "$nw" -i "1 30" </dev/null 2>&1 | grep -E '^[0-9]+$' | tail -1)
        if [ "$r" = "832040" ]; then ok "$nw worker(s): fib(30) = $r"; else ng "$nw worker(s): fib(30) = '${r}' (期待値 832040)"; fi
      done
    else
      ng "fib_full.tc: sc2c / gcc に失敗 (ログ: $T/gen.tcell.log)"
    fi
  fi
fi

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
