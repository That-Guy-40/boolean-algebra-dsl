#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# COMBINATOR TRACE — a viewer for Layer 5, in the spirit of add_trace / fsm_trace
#
# Layer 5 rebuilds Layer-1's word ops from the FUNCTION side — map / zipwith /
# foldl / scanl (combinator-circuits.sh, on top of list-processing-kit.sh). The
# headline is that the ripple-carry adder is just a LEFT FOLD threading the carry.
# So this viewer's star, `fp_add_trace`, shows the very same carry ripple that
# `add_trace` drew for the gates — but revealed as a fold (the Church–Turing wink
# of the project, made visible). The generic `fold_trace` / `scan_trace` /
# `map_trace` light up the combinators everything else is built from.
#
# Read-only: it changes nothing in Layer 5 and drives the SAME combinators
# (apply2, the real _fp_add_step / fp_carry_chain), so the picture stays faithful.
#
#   fold_trace F init "list"   — a left fold collapsing a list, step by step
#   scan_trace F init "list"   — the same, keeping every running accumulator (scanl)
#   map_trace  F "list"        — apply F to each element independently
#   fp_add_trace A B [Cin]     — the ripple adder AS a carry-threading foldl
#
# Bit strings / lists are LSB-first, space-separated, as everywhere in the project.
# ─────────────────────────────────────────────────────────────────────────────

source "$(dirname "${BASH_SOURCE[0]}")/combinator-circuits.sh"   # the fp_* rebuilds + the kit + Layer 1

# ── generic combinators ───────────────────────────────────────────────────────

fold_trace () {           # F init "list"  — watch foldl collapse the list left-to-right
  local F="$1" init="$2" list="$3" f acc="$2" e i=0 newacc
  f=$(as_fn2 "$F")
  printf '\n  foldl  —  acc starts at init, then  acc = F(acc, x)  for each x, left to right\n'
  printf '  F = %s   init = %s   list = [%s]\n\n' "$F" "$init" "$list"
  printf '  step  element   acc-in        →  acc-out\n'
  printf '  ──────────────────────────────────────────\n'
  for e in $list; do
    i=$((i+1)); newacc=$(apply2 "$f" "$acc" "$e")
    printf '  %3d    %-7s  %-11s  →  %s\n' "$i" "$e" "$acc" "$newacc"
    acc=$newacc
  done
  printf '  ──────────────────────────────────────────\n'
  printf '  result = %s   (= foldl F init list)\n' "$acc"
}

scan_trace () {           # F init "list"  — like fold_trace, but scanl keeps EVERY accumulator
  local F="$1" init="$2" list="$3" f acc="$2" e res="$2"
  f=$(as_fn2 "$F")
  printf '\n  scanl  —  the same fold, but it keeps every running accumulator (not just the last)\n'
  printf '  F = %s   init = %s   list = [%s]\n\n' "$F" "$init" "$list"
  printf '  %-12s %s\n' "start" "$acc"
  for e in $list; do
    acc=$(apply2 "$f" "$acc" "$e"); res+=" $acc"
    printf '  %-12s %s\n' "after $e" "$acc"
  done
  printf '\n  result = %s   (= scanl F init list)\n' "$res"
}

map_trace () {            # F "list"  — apply F to each element independently
  local F="$1" list="$2" f e y res=""
  f=$(as_fn "$F")
  printf '\n  map  —  apply F to each element on its own (no accumulator)\n'
  printf '  F = %s   list = [%s]\n\n' "$F" "$list"
  for e in $list; do
    y=$(apply "$f" "$e"); res+=" $y"
    printf '    %-6s → %s\n' "$e" "$y"
  done
  printf '\n  result = %s   (= map F list)\n' "${res# }"
}

# ── ★ the ripple adder, revealed as a fold ────────────────────────────────────

fp_add_trace () {         # A B [Cin]  — the ripple adder rebuilt as foldl _fp_add_step over zip A B
  local A="$1" B="$2" cin="${3:-0}" w wb pairs
  w=$(llength "$A"); wb=$(llength "$B"); [ "$wb" -gt "$w" ] && w=$wb
  A=$(_fp_zext "$A" "$w"); B=$(_fp_zext "$B" "$w")    # pad shorter operand, as fp_word_add does
  pairs=$(zip "$A" "$B")

  printf '\n  fp_word_add — the ripple adder rebuilt as  foldl _fp_add_step "%s|" (zip A B)\n' "$cin"
  printf '  A = %s  (=%d)\n  B = %s  (=%d)\n' "$A" "$(bits_to_int "$A")" "$B" "$(bits_to_int "$B")"
  printf '  accumulator = "carry|sum-bits"; each step folds one pair a:b through fp_full_adder.\n\n'
  printf '  bit  a:b   acc-in          sum  cout    acc-out\n'
  printf '  ──────────────────────────────────────────────────────\n'

  local acc="$cin|" pair a b i=0 newacc cout bits sum
  for pair in $pairs; do
    a=${pair%%:*}; b=${pair#*:}
    newacc=$(_fp_add_step "$acc" "$pair")            # the REAL foldl combiner — single source of truth
    cout=${newacc%%|*}; bits=${newacc#*|}; sum=${bits##* }
    printf '  %2d   %s:%s   %-13s   %s    %s     %s\n' "$i" "$a" "$b" "$acc" "$sum" "$cout" "$newacc"
    acc=$newacc; i=$((i+1))
  done

  printf '  ──────────────────────────────────────────────────────\n'
  bits=${acc#*|}; cout=${acc%%|*}
  printf '  fold result = %s   →   Sum = %s  (=%d)   Cout = %s\n' "$acc" "$bits" "$(bits_to_int "$bits")" "$cout"
  printf '  carry chain (scanl): %s   — the carry rippling IN at each bit, then the Cout\n' "$(fp_carry_chain "$A" "$B" "$cin")"
}

# example use:
#   source ./combinator-trace.sh
#   fold_trace 'echo $(($1+$2))' 0 '1 2 3 4 5'    # sum a list -> 15, step by step
#   scan_trace 'echo $(($1+$2))' 0 '1 2 3 4'      # the running sums: 0 1 3 6 10
#   map_trace  flip_bit '1 0 1 1'                 # = word_not: 0 1 0 0
#   fp_add_trace "1 0 1 0" "0 1 1 0"              # 5 + 6, the carry ripple AS a fold
