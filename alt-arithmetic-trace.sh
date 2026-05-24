#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# ALT-ARITHMETIC TRACE — a viewer for Layer 4, in the spirit of add_trace / fsm_trace
#
# Layer 4 builds number three different ways, and each hides its work differently:
#   • Peano   — a number is a tower of successors; arithmetic is recursion. The
#               successor IS Layer-1's `inc`, so the trace shows +1 rippling the gates.
#   • Church  — a number is "apply f n times"; the trace watches it iterate.
#   • Modular — clock arithmetic; the trace shows the wrap (raw = q·n + r).
#
# This is a READ-ONLY viewer: it changes nothing in alt-arithmetic.sh and drives the
# SAME primitives (peano_succ/peano_add/…, the real numeral iteration, mod_reduce/
# mod_mul), so every picture stays faithful to the model it draws.
#
#   peano_trace   OP A B [W]   OP ∈ add sub mult expt   — the repeated successor/op
#   church_trace  N [int|bits] [W]                      — the numeral iterating a step
#   mod_trace     OP A B N     OP ∈ add sub mul         — the clock wrap
#   mod_trace_pow BASE E N                              — square-and-multiply, step by step
#
# Bit strings are LSB-first, as everywhere in the project.
# ─────────────────────────────────────────────────────────────────────────────

source "$(dirname "${BASH_SOURCE[0]}")/alt-arithmetic.sh"   # the three models (+ Layer 1)

# ── Peano: a number is zero + repeated successor ──────────────────────────────

peano_trace () {          # OP A B [W]  — show A (OP) B as its repeated lower operation
  local op="$1" a="$2" b="$3" W="${4:-$PEANO_W}"
  local abits cur i unit head sym
  abits=$(int_to_peano "$a" "$W")
  case "$op" in
    add)  cur=$(int_to_peano "$a" "$W"); unit="S (inc)"; sym='+'; head="\"+$b\" = apply the successor $b times; each S is Layer-1 inc" ;;
    sub)  cur=$(int_to_peano "$a" "$W"); unit="P (dec)"; sym='−'; head="\"−$b\" = apply the predecessor $b times; each P is Layer-1 dec" ;;
    mult) cur=$(int_to_peano 0   "$W"); unit="+ $a";    sym='×'; head="\"×$b\" = add $a to a running total $b times (each + is $a successors)" ;;
    expt) cur=$(int_to_peano 1   "$W"); unit="× $a";    sym='^'; head="\"^$b\" = multiply a running total by $a, $b times" ;;
    *) printf 'peano_trace: OP must be add|sub|mult|expt\n' >&2; return 2 ;;
  esac

  printf '\n  Peano %s  %s %s %s   (width %d, LSB-first)\n' "${op^^}" "$a" "$sym" "$b" "$W"
  printf '  %s\n\n' "$head"
  printf '  step       value   bits\n'
  printf '  ─────────────────────────────────────────\n'
  printf '  %-8s %5d   %s\n' "start" "$(peano_to_int "$cur")" "$cur"
  for ((i=1; i<=b; i++)); do
    case "$op" in
      add)  cur=$(peano_succ "$cur") ;;
      sub)  cur=$(peano_pred "$cur") ;;
      mult) cur=$(peano_add  "$cur" "$abits") ;;
      expt) cur=$(peano_mult "$cur" "$abits") ;;
    esac
    printf '  %-8s %5d   %s\n' "$unit" "$(peano_to_int "$cur")" "$cur"
  done
  printf '  ─────────────────────────────────────────\n'
  printf '  result = %d\n' "$(peano_to_int "$cur")"
}

# ── Church: a number is a function that repeats another function n times ──────

church_trace () {         # N [int|bits] [W]  — watch numeral N apply a step function N times
  local n="$1" mode="${2:-int}" W="${3:-8}" i
  case "$mode" in
    int)
      printf '\n  Church numeral %d  =  λf. f∘f∘…∘f   ("do f %d times")\n' "$n" "$n"
      printf '  iterating the integer successor (+1) starting from 0:\n\n'
      local cur=0
      printf '  apply #%-2d  %d\n' 0 "$cur"
      for ((i=1; i<=n; i++)); do cur=$(( cur + 1 )); printf '  apply #%-2d  %d\n' "$i" "$cur"; done
      printf '\n  result = %d   (= church_to_int of the numeral)\n' "$cur"
      ;;
    bits)
      printf '\n  Church numeral %d  =  λf. f∘f∘…∘f   ("do f %d times")\n' "$n" "$n"
      printf '  iterating Layer-1 `inc` on all-zeros — the function↔gate handshake:\n\n'
      local cur; cur=$(int_to_bits 0 "$W")
      printf '  apply #%-2d  %s  (=%d)\n' 0 "$cur" "$(bits_to_int "$cur")"
      for ((i=1; i<=n; i++)); do cur=$(inc "$cur"); printf '  apply #%-2d  %s  (=%d)\n' "$i" "$cur" "$(bits_to_int "$cur")"; done
      printf '\n  result = %s  (=%d)   (= church_to_bits %d)\n' "$cur" "$(bits_to_int "$cur")" "$n"
      ;;
    *) printf 'church_trace: mode must be int|bits\n' >&2; return 2 ;;
  esac
}

# ── Modular: count past n−1 and you wrap back to 0 ────────────────────────────

mod_trace () {            # OP a b n  — show (a OP b) mod n as raw = q·n + r
  local op="$1" a="$2" b="$3" n="$4" raw sym r q
  case "$op" in
    add) raw=$(( a + b )); sym='+' ;;
    sub) raw=$(( a - b )); sym='−' ;;
    mul) raw=$(( a * b )); sym='×' ;;
    *) printf 'mod_trace: OP must be add|sub|mul\n' >&2; return 2 ;;
  esac
  r=$(mod_reduce "$raw" "$n"); q=$(( (raw - r) / n ))   # raw ≡ r (mod n), so this is exact

  printf '\n  Modular %s  (%d %s %d) mod %d\n' "${op^^}" "$a" "$sym" "$b" "$n"
  printf '    %d %s %d = %d\n' "$a" "$sym" "$b" "$raw"
  printf '    %d = %d × %d + %d' "$raw" "$q" "$n" "$r"
  case "$q" in
    0)  printf '   (already on the clock face)\n' ;;
    1)  printf '   (one full turn, then %d)\n' "$r" ;;
    -*) local back=$(( -q )); printf '   (%d turn%s backward, landing on %d)\n' "$back" "$([ "$back" = 1 ] || echo s)" "$r" ;;
    *)  printf '   (%d full turns, then %d)\n' "$q" "$r" ;;
  esac
  printf '    result = %d\n' "$r"
  if [ "$n" -le 24 ]; then
    printf '\n    clock(%d): ' "$n"
    local k
    for ((k=0; k<n; k++)); do [ "$k" = "$r" ] && printf '[%d] ' "$k" || printf '%d ' "$k"; done
    printf '\n'
  fi
}

mod_trace_pow () {        # base e n  — base^e mod n by square-and-multiply, step by step
  local base=$1 e=$2 n=$3 result=1 i=0 bits=""
  local b=$e; while [ "$b" -gt 0 ]; do bits+="$(( b & 1 )) "; b=$(( b >> 1 )); done   # LSB-first
  base=$(mod_reduce "$base" "$n")

  printf '\n  Modular POW  %d^%d mod %d   (square-and-multiply)\n' "$1" "$e" "$n"
  printf '  exponent %d in binary (LSB-first): %s\n\n' "$e" "${bits% }"
  printf '  bit  e&1  base (mod n)   result (mod n)\n'
  printf '  ──────────────────────────────────────\n'
  local ee=$e
  while [ "$ee" -gt 0 ]; do
    local use=$(( ee & 1 ))
    [ "$use" = 1 ] && result=$(mod_mul "$result" "$base" "$n")
    printf '  %3d   %d   %-12d %d\n' "$i" "$use" "$base" "$result"
    base=$(mod_mul "$base" "$base" "$n"); ee=$(( ee >> 1 )); i=$(( i + 1 ))
  done
  printf '  ──────────────────────────────────────\n'
  printf '  result = %d   (rows where e&1=1 multiply the running result in)\n' "$result"
}

# example use:
#   source ./alt-arithmetic-trace.sh
#   peano_trace add 3 2          # 3 + 2, two successors, each a Layer-1 inc
#   peano_trace mult 3 4         # 3 × 4 = add 3 to a total four times
#   peano_trace add 0 5          # the "tower of successors": 5 = S(S(S(S(S(0)))))
#   church_trace 4               # numeral 4 = apply +1 four times to 0
#   church_trace 4 bits          # …the same, driving Layer-1 inc (the handshake)
#   mod_trace add 10 5 12        # 10 + 5 on a 12-clock -> 3
#   mod_trace_pow 2 10 1000      # 2^10 mod 1000 -> 24
