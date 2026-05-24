#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# EML TRACE — a viewer for Layer 2, in the spirit of add_trace / fsm_trace
#
# Layer 2 rebuilds ordinary arithmetic from a SINGLE binary operator,
# eml(x,y) = exp(x) − ln(y) — the continuous-math analogue of NAND. Combined with
# the constant 1, eml generates +, −, ×, ÷, exp, ln. That rebuild is invisible in
# the one-line definitions, so this read-only viewer shows it:
#
#   eml_trace OP a b      — how +,−,×,÷ are rebuilt as a small TREE of eml calls
#   eml_recip_trace x …   — 1/x by Newton's iteration  y ← y·(2 − x·y), step by step
#   eml_sin_trace x …     — sin(x) by its Maclaurin series, term by term
#
# Read-only: it changes nothing in Layer 2 and drives the SAME building blocks
# (eml / eml_ln / eml_exp / eml_neg / eml_mul / eml_sub …), so the picture stays
# faithful. All values come from bc -l, exactly as the real functions compute them.
# ─────────────────────────────────────────────────────────────────────────────

source "$(dirname "${BASH_SOURCE[0]}")/boolean-funcs-new.sh"   # the eml operator + derived ops

# ── eml_trace: an arithmetic op, rebuilt as a tree of eml calls ───────────────

eml_trace () {            # OP a b   OP ∈ add sub mul div   — show the eml-tree, evaluated
  local op="$1" a="$2" b="$3" lna lnb negy expy s res
  case "$op" in
    add)   # x + y = x − (−y) = eml(ln x, exp(−y))
      printf '\n  eml ADD  %s + %s   =  eml(ln x, exp(−y))      [x + y = x − (−y)]\n' "$a" "$b"
      lna=$(eml_ln "$a");  negy=$(eml_neg "$b"); expy=$(eml_exp "$negy"); res=$(eml "$lna" "$expy")
      printf '    ln x        = eml_ln %s        = %s\n'   "$a"    "$lna"
      printf '    −y          = eml_neg %s       = %s\n'   "$b"    "$negy"
      printf '    exp(−y)     = eml_exp(%s)      = %s\n'   "$negy" "$expy"
      printf '    x + y       = eml(ln x, exp(−y)) = %s\n' "$res" ;;
    sub)   # x − y = eml(ln x, exp y)
      printf '\n  eml SUB  %s − %s   =  eml(ln x, exp y)\n' "$a" "$b"
      lna=$(eml_ln "$a"); expy=$(eml_exp "$b"); res=$(eml "$lna" "$expy")
      printf '    ln x        = eml_ln %s        = %s\n'   "$a" "$lna"
      printf '    exp y       = eml_exp %s       = %s\n'   "$b" "$expy"
      printf '    x − y       = eml(ln x, exp y)   = %s\n' "$res" ;;
    mul)   # x·y = exp(ln x + ln y) = eml_exp(eml_add(ln x, ln y))
      printf '\n  eml MUL  %s × %s   =  exp(ln x + ln y)        [first arg must be > 1]\n' "$a" "$b"
      lna=$(eml_ln "$a"); lnb=$(eml_ln "$b"); s=$(eml_add "$lna" "$lnb"); res=$(eml_exp "$s")
      printf '    ln x        = eml_ln %s        = %s\n'   "$a" "$lna"
      printf '    ln y        = eml_ln %s        = %s\n'   "$b" "$lnb"
      printf '    ln x + ln y = eml_add(…)        = %s\n'  "$s"
      printf '    x × y       = eml_exp(…)        = %s\n'  "$res" ;;
    div)   # 1/z = exp(−ln z) = eml_exp(eml_neg(ln z))   (unary; b ignored)
      printf '\n  eml DIV  1 / %s   =  exp(−ln z)\n' "$a"
      lna=$(eml_ln "$a"); negy=$(eml_neg "$lna"); res=$(eml_exp "$negy")
      printf '    ln z        = eml_ln %s        = %s\n'   "$a"    "$lna"
      printf '    −ln z       = eml_neg(%s)      = %s\n'   "$lna"  "$negy"
      printf '    1 / z       = eml_exp(−ln z)     = %s\n' "$res" ;;
    *) printf 'eml_trace: OP must be add|sub|mul|div\n' >&2; return 2 ;;
  esac
  printf '  result = %s   (every line is one eml building block; this equals the real eml_%s)\n' "$res" "$op"
}

# ── eml_recip_trace: Newton's method for 1/x, using only eml_mul / eml_sub ─────

eml_recip_trace () {      # x [iters=8] [y0=0.5]  — the same loop eml_recip runs
  local x="$1" iters="${2:-8}" y="${3:-0.5}" i t c
  printf '\n  Newton reciprocal  1/x   via  y ← y·(2 − x·y)   (root of 1/y − x; no division)\n'
  printf '  x = %s   y0 = %s   — stops once x·y reaches 1 (y has converged)\n\n' "$x" "$y"
  printf '  iter   y                      t = x·y                c = 2 − t              y'\'' = c·y\n'
  printf '  ────────────────────────────────────────────────────────────────────────────────────────\n'
  for ((i=0; i<iters; i++)); do
    t=$(eml_mul "$x" "$y")
    if [ "$(echo "$t >= 1" | bc -l)" = 1 ]; then
      printf '  %3d    %-22s %-22s (x·y ≥ 1 — converged, stop)\n' "$i" "$y" "$t"
      break
    fi
    c=$(eml_sub 2 "$t"); local ynew; ynew=$(eml_mul "$c" "$y")
    printf '  %3d    %-22s %-22s %-22s %s\n' "$i" "$y" "$t" "$c" "$ynew"
    y="$ynew"
  done
  printf '  ────────────────────────────────────────────────────────────────────────────────────────\n'
  printf '  result = %s   (≈ 1/%s)\n' "$y" "$x"
}

# ── eml_sin_trace: the Maclaurin series for sin(x), term by term ──────────────

eml_sin_trace () {        # x [terms=6]  — the same series eml_sin_taylor sums
  local x="$1" terms="${2:-6}" k exp fact recip power term acc="$1" sign
  printf '\n  Taylor sine  sin(x) = x − x³/3! + x⁵/5! − x⁷/7! + …   (powers via eml_pow_int, 1/n! via eml_div)\n'
  printf '  x = %s\n\n' "$x"
  printf '  k   exp   term = x^exp / exp!       ±   acc (running sum)\n'
  printf '  ──────────────────────────────────────────────────────────────────\n'
  printf '  0    1    %-24s %s   %s\n' "(the seed: x)" "+" "$acc"
  for ((k=1; k<terms; k++)); do
    exp=$((2*k + 1))
    power=$(eml_pow_int "$x" "$exp")
    fact=$(echo "f=1; for (i=2; i<=$exp; i++) f*=i; f" | bc)
    recip=$(eml_div "$fact")
    term=$(eml_mul "$power" "$recip")
    if (( k % 2 == 1 )); then sign='−'; acc=$(eml_sub "$acc" "$term"); else sign='+'; acc=$(eml_add "$acc" "$term"); fi
    printf '  %-3d  %-4d  %-24s %s   %s\n' "$k" "$exp" "$term" "$sign" "$acc"
  done
  printf '  ──────────────────────────────────────────────────────────────────\n'
  printf '  result = %s   (≈ sin %s)\n' "$acc" "$x"
}

# example use:
#   source ./eml-trace.sh
#   eml_trace mul 3 4          # watch × rebuilt from the eml operator -> ≈ 12
#   eml_trace add 3 5          # …and + -> ≈ 8
#   eml_recip_trace 1.5        # 1/1.5 by Newton's iteration, step by step
#   eml_recip_trace 10 9 0.05  # 1/10 (smaller seed for the larger x)
#   eml_sin_trace 1.5          # sin(1.5) by its Maclaurin series, term by term
