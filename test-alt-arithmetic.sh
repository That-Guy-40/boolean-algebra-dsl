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

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
