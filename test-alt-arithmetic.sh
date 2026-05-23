#!/bin/bash
# Tests for the experimental alternative-arithmetic layer (alt-arithmetic.sh).
# Kept deliberately small: these models do arithmetic by counting through the
# gate layer, so they are slow. We verify correctness on a handful of small
# cases rather than exhaustive grids. (The core suite is test-boolean-funcs.sh.)

source "$(dirname "${BASH_SOURCE[0]}")/alt-arithmetic.sh"

PASS=0; FAIL=0
section () { printf '\n── %s\n' "$1"; }
check_str () {
  local desc="$1" exp="$2" got="$3"
  if [ "$got" = "$exp" ]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); printf 'FAIL  %-46s want=%s got=%s\n' "$desc" "$exp" "$got"; fi
}

# ═══════════════════════════════════════════════════════════════════════════
# PEANO ARITHMETIC
# ═══════════════════════════════════════════════════════════════════════════
PEANO_W=6   # 0..63 — enough for these cases, narrower = faster

# decimal-in / decimal-out wrappers
padd ()  { peano_to_int "$(peano_add  "$(int_to_peano $1)" "$(int_to_peano $2)")"; }
psub ()  { peano_to_int "$(peano_sub  "$(int_to_peano $1)" "$(int_to_peano $2)")"; }
pmul ()  { peano_to_int "$(peano_mult "$(int_to_peano $1)" "$(int_to_peano $2)")"; }
pdiv ()  { peano_to_int "$(peano_div  "$(int_to_peano $1)" "$(int_to_peano $2)")"; }
pexp ()  { peano_to_int "$(peano_expt "$(int_to_peano $1)" "$(int_to_peano $2)")"; }

section "Peano primitives (successor = inc, predecessor = dec)"
check_str "succ(3) = 4"       "4" "$(peano_to_int "$(peano_succ "$(int_to_peano 3)")")"
check_str "pred(3) = 2"       "2" "$(peano_to_int "$(peano_pred "$(int_to_peano 3)")")"
check_str "succ(pred(7)) = 7" "7" "$(peano_to_int "$(peano_succ "$(peano_pred "$(int_to_peano 7)")")")"
check_str "is_zero(0) = true"  "true"  "$(peano_is_zero "$(int_to_peano 0)")"
check_str "is_zero(5) = false" "false" "$(peano_is_zero "$(int_to_peano 5)")"
check_str "lt(2,5) = true"     "true"  "$(peano_lt "$(int_to_peano 2)" "$(int_to_peano 5)")"
check_str "lt(5,2) = false"    "false" "$(peano_lt "$(int_to_peano 5)" "$(int_to_peano 2)")"

section "Peano addition / subtraction"
check_str "0 + 4 = 4" "4" "$(padd 0 4)"
check_str "2 + 3 = 5" "5" "$(padd 2 3)"
check_str "7 + 1 = 8" "8" "$(padd 7 1)"
check_str "5 − 3 = 2" "2" "$(psub 5 3)"
check_str "6 − 6 = 0" "0" "$(psub 6 6)"
check_str "9 − 0 = 9" "9" "$(psub 9 0)"

section "Peano multiplication / division"
check_str "3 × 0 = 0"   "0"  "$(pmul 3 0)"
check_str "3 × 4 = 12"  "12" "$(pmul 3 4)"
check_str "5 × 2 = 10"  "10" "$(pmul 5 2)"
check_str "13 ÷ 4 = 3"  "3"  "$(pdiv 13 4)"
check_str "12 ÷ 4 = 3"  "3"  "$(pdiv 12 4)"
check_str "3 ÷ 5 = 0"   "0"  "$(pdiv 3 5)"

section "Peano exponentiation"
check_str "2 ^ 0 = 1"  "1"  "$(pexp 2 0)"
check_str "5 ^ 1 = 5"  "5"  "$(pexp 5 1)"
check_str "2 ^ 3 = 8"  "8"  "$(pexp 2 3)"
check_str "3 ^ 2 = 9"  "9"  "$(pexp 3 2)"

section "Peano subtraction below zero wraps (mod 2^W) — the modular tie-in"
# Natural subtraction is only defined for N1 ≥ N2; going under wraps, exactly as
# fixed-width binary (and the ALU) do. With W=6, 3 − 5 = −2 ≡ 64 − 2 = 62.
check_str "3 − 5 ≡ 62 (mod 64)" "62" "$(psub 3 5)"

# ═══════════════════════════════════════════════════════════════════════════
# CHURCH NUMERALS  (number as repeated application)
# ═══════════════════════════════════════════════════════════════════════════
section "Church primitives & the iterator combinator"
check_str "succ(succ(succ 0)) = 3" "3" "$(church_succ "$(church_succ "$(church_succ "$(church_zero)")")")"
check_str "is_zero(0) = true"  "true"  "$(church_is_zero 0)"
check_str "is_zero(3) = false" "false" "$(church_is_zero 3)"
check_str "apply +1 five times to 0 = 5" "5" "$(church_apply 5 church_succ 0)"
check_str "apply '*' five times = *****" "*****" "$(__star () { printf '%s*' "$1"; }; church_apply 5 __star "")"

section "Church arithmetic (built only from succ + iteration)"
check_str "add 2 3 = 5"   "5"  "$(church_add 2 3)"
check_str "add 0 4 = 4"   "4"  "$(church_add 0 4)"
check_str "mult 3 4 = 12" "12" "$(church_mult 3 4)"
check_str "mult 5 0 = 0"  "0"  "$(church_mult 5 0)"
check_str "expt 2 5 = 32" "32" "$(church_expt 2 5)"
check_str "expt 4 0 = 1"  "1"  "$(church_expt 4 0)"

section "Church cross-layer: a numeral drives the Layer-1 inc circuit"
check_str "church 5 → bits → 5" "5" "$(bits_to_int "$(church_to_bits 5)")"
check_str "church 10 → bits → 10" "10" "$(bits_to_int "$(church_to_bits 10)")"

# ═══════════════════════════════════════════════════════════════════════════
# MODULAR / CLOCK ARITHMETIC  (ℤ/nℤ)
# ═══════════════════════════════════════════════════════════════════════════
section "Clock arithmetic (reduce, add, sub, mul)"
check_str "10 + 5 mod 12 = 3"  "3"  "$(mod_add 10 5 12)"
check_str "2 − 5 mod 12 = 9"   "9"  "$(mod_sub 2 5 12)"
check_str "7 × 5 mod 12 = 11"  "11" "$(mod_mul 7 5 12)"
check_str "−1 mod 7 = 6"       "6"  "$(mod_reduce -1 7)"

section "Modular exponentiation (vs bc)"
check_str "2^10 mod 1000 = 24"   "24" "$(mod_pow 2 10 1000)"
check_str "3^5 mod 7 = 5"        "5"  "$(mod_pow 3 5 7)"
check_str "7^13 mod 100 (vs bc)" "$(echo '7^13 % 100' | bc)" "$(mod_pow 7 13 100)"

section "Modular inverse (extended Euclid)"
# mod 7 is a field: every nonzero element has an inverse; a·a⁻¹ ≡ 1.
for a in 1 2 3 4 5 6; do
    inv=$(mod_inverse $a 7)
    check_str "$a · ($a⁻¹) ≡ 1 mod 7" "1" "$(mod_mul $a $inv 7)"
done
check_str "inverse of 4 mod 6 = none (gcd≠1)" "none" "$(mod_inverse 4 6)"

section "Cross-layer: the Layer-1 4-bit adder IS arithmetic mod 16"
for pair in "3 1" "7 5" "12 11" "15 8" "9 11"; do
    set -- $pair
    check_str "ripple_add4 $1+$2 == ($1+$2) mod 16" "$(mod_add $1 $2 16)" "$(mod_add_bits4 $1 $2)"
done

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
