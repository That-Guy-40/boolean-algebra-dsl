#!/bin/bash
# Tests for combinator-trace.sh — the Layer-5 viewer (fold/scan/map + the adder-as-fold).
#
# Same promise as the other viewers: it CANNOT lie. Each trace's reported result is
# pinned against an INDEPENDENT call to the real combinator it visualises — the kit's
# foldl/scanl/map, and Layer 5's fp_word_add (itself cross-checked against Layer 1's
# word_add elsewhere). A standalone (non-core) suite — the adder traces ripple through
# the gates, so it's slow.

source "$(dirname "${BASH_SOURCE[0]}")/../combinator-trace.sh"   # pulls in combinator-circuits.sh + kit

PASS=0; FAIL=0
section () { printf '\n── %s\n' "$1"; }
check_str () {
  local desc="$1" exp="$2" got="$3"
  if [ "$got" = "$exp" ]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); printf 'FAIL  %-44s want=[%s] got=[%s]\n' "$desc" "$exp" "$got"; fi
}
# pull the "result = …" payload (before the "(= …)" attribution) off a trace
res_of () { printf '%s\n' "$1" | sed -n 's/^  result = \(.*\)   (= .*/\1/p' | tail -1; }

# ── fold_trace == foldl ------------------------------------------------------
section "fold_trace — result vs the kit's foldl"
ADD='echo $(($1+$2))'; MUL='echo $(($1*$2))'
for spec in "$ADD:0:1 2 3 4 5" "$ADD:10:7 7 7" "$MUL:1:1 2 3 4" "$ADD:0:"; do
  F="${spec%%:*}"; rest="${spec#*:}"; init="${rest%%:*}"; list="${rest#*:}"
  check_str "fold [$F | $init | $list]" "$(foldl "$F" "$init" "$list")" "$(res_of "$(fold_trace "$F" "$init" "$list")")"
done

# ── scan_trace == scanl ------------------------------------------------------
section "scan_trace — result vs the kit's scanl"
for spec in "$ADD:0:1 2 3 4" "$ADD:0:5 5 5" "$MUL:1:2 2 2 2"; do
  F="${spec%%:*}"; rest="${spec#*:}"; init="${rest%%:*}"; list="${rest#*:}"
  check_str "scan [$init | $list]" "$(scanl "$F" "$init" "$list")" "$(res_of "$(scan_trace "$F" "$init" "$list")")"
done

# ── map_trace == map (command name AND fn value) -----------------------------
section "map_trace — result vs the kit's map"
check_str "map flip_bit"  "$(map flip_bit '1 0 1 1')"            "$(res_of "$(map_trace flip_bit '1 0 1 1')")"
check_str "map flip_bit2" "$(map flip_bit '0 0 1 1 1 0')"        "$(res_of "$(map_trace flip_bit '0 0 1 1 1 0')")"
SQ='echo $(($1*$1))'
check_str "map square (fn value)" "$(map "$SQ" '1 2 3 4 5')"     "$(res_of "$(map_trace "$SQ" '1 2 3 4 5')")"

# ── fp_add_trace == fp_word_add (sum bits + carry-out) -----------------------
# extract "Sum = b b b  (=n)   Cout = c"  ->  "b b b c"  to match fp_word_add's output
add_result () { printf '%s\n' "$1" | sed -n 's/.*Sum = \([01 ]*\)  (=[0-9]*)   Cout = \([01]\).*/\1 \2/p'; }
section "fp_add_trace — result vs fp_word_add, over a sweep (+ Cin)"
for a in 0 1 3 6 9 15; do for b in 0 1 5 10 15; do
  A=$(int_to_bits "$a" 4); B=$(int_to_bits "$b" 4)
  for cin in 0 1; do
    check_str "fp_add $a+$b+$cin" "$(fp_word_add "$A" "$B" "$cin")" "$(add_result "$(fp_add_trace "$A" "$B" "$cin")")"
  done
done; done
# and the carry chain line equals fp_carry_chain
section "fp_add_trace — carry-chain line vs fp_carry_chain"
chain_of () { printf '%s\n' "$1" | sed -n 's/^  carry chain (scanl): \(.*\)   — .*/\1/p'; }
for pair in "1 0 1 0:0 1 1 0" "1 1 1 1:1 0 0 0"; do
  A="${pair%%:*}"; B="${pair#*:}"
  check_str "carry chain [$A]+[$B]" "$(fp_carry_chain "$A" "$B" 0)" "$(chain_of "$(fp_add_trace "$A" "$B")")"
done

# ── format smoke -------------------------------------------------------------
section "format — traces render their headers"
check_str "fold header"  "yes" "$(fold_trace "$ADD" 0 '1 2 3' | grep -q 'foldl'                  && echo yes)"
check_str "scan keeps acc" "yes" "$(scan_trace "$ADD" 0 '1 2' | grep -q 'keeps every running'    && echo yes)"
check_str "adder-as-fold" "yes" "$(fp_add_trace '1 0 1 0' '0 1 1 0' | grep -q 'rebuilt as  foldl' && echo yes)"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
