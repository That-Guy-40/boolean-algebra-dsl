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
# CHURCH NUMERALS  (number = iterated composition, via the combinator layer)
# ═══════════════════════════════════════════════════════════════════════════
# decimal-in / decimal-out wrappers over the canonical (fn-value) numerals
cn () { church_to_int "$1"; }
ci () { int_to_church "$1"; }

section "Function-application machinery (apply / apply2 / compose / lift)"
INC1='echo $(( $1 + 1 ))'; DBL='echo $(( $1 * 2 ))'
check_str "apply (+1) 5 = 6"            "6"  "$(apply "$INC1" 5)"
check_str "apply2 (a+b) 3 4 = 7"        "7"  "$(apply2 'echo $(($1+$2))' 3 4)"
check_str "compose (+1) (×2) @ 5 = 11"  "11" "$(apply "$(compose "$INC1" "$DBL")" 5)"   # 2*5+1
check_str "compose (×2) (+1) @ 5 = 12"  "12" "$(apply "$(compose "$DBL" "$INC1")" 5)"   # (5+1)*2
check_str "deep compose ((+1)∘(+1)∘(×2)) @ 5 = 12" "12" "$(apply "$(compose "$INC1" "$(compose "$INC1" "$DBL")")" 5)"
check_str "lift inc then apply @ bits3" "4" "$(bits_to_int "$(apply "$(lift inc)" "$(int_to_bits 3 4)")")"

section "List combinators (lhead/ltail, map, mapcar, filter, foldl, foldr)"
check_str "lhead '3 1 4'"  "3"      "$(lhead '3 1 4')"
check_str "ltail '3 1 4'"  "1 4"    "$(ltail '3 1 4')"
check_str "llength '3 1 4'" "3"     "$(llength '3 1 4')"
check_str "lnull '' "      "yes"    "$(lnull '' && echo yes || echo no)"
SQ='echo $(($1*$1))'
check_str "map square"           "1 4 9 16 25" "$(map "$SQ" '1 2 3 4 5')"
check_str "mapcar square (recur)" "1 4 9 16 25" "$(mapcar "$SQ" '1 2 3 4 5')"
check_str "foldl + 0 (sum)"      "15" "$(foldl 'echo $(($1+$2))' 0 '1 2 3 4 5')"
check_str "foldl * 1 (product)"  "24" "$(foldl 'echo $(($1*$2))' 1 '1 2 3 4')"
check_str "foldl − 0 = ((0-1)-2)-3 = -6" "-6" "$(foldl 'echo $(($1-$2))' 0 '1 2 3')"
check_str "foldr − 0 = 1-(2-(3-0)) = 2"  "2"  "$(foldr 'echo $(($1-$2))' 0 '1 2 3')"
EVEN='if (( $1 % 2 == 0 )); then echo true; else echo false; fi'
check_str "filter even"          "2 4 6" "$(filter "$EVEN" '1 2 3 4 5 6')"

section "More list combinators (zipwith / take / drop / while / until / range / iterate)"
check_str "zipwith + "        "11 22 33"   "$(zipwith 'echo $(($1+$2))' '1 2 3' '10 20 30')"
check_str "zipwith * (min len)" "5 12"     "$(zipwith 'echo $(($1*$2))' '1 2 3 4' '5 6')"
check_str "take 2"            "a b"        "$(take 2 'a b c d')"
check_str "drop 2"            "c d"        "$(drop 2 'a b c d')"
check_str "take 9 (over)"     "a b"        "$(take 9 'a b')"
LT4='if (( $1 < 4 )); then echo true; else echo false; fi'
check_str "take_while <4"     "1 2"        "$(take_while "$LT4" '1 2 5 3')"
check_str "drop_while <4"     "5 3"        "$(drop_while "$LT4" '1 2 5 3')"
check_str "take_until <4"     ""           "$(take_until "$LT4" '1 2 5 3')"
check_str "drop_until <4"     "1 2 5 3"    "$(drop_until "$LT4" '1 2 5 3')"
check_str "lrange 3 7"        "3 4 5 6 7"  "$(lrange 3 7)"
check_str "lrange 5 2 (empty)" ""          "$(lrange 5 2)"
check_str "lreverse"          "4 3 2 1"    "$(lreverse '1 2 3 4')"
check_str "iterate *2 1 5"    "1 2 4 8 16" "$(iterate 'echo $(($1*2))' 1 5)"
EVEN='if (( $1 % 2 == 0 )); then echo true; else echo false; fi'
check_str "any even (none)"   "false"      "$(any "$EVEN" '1 3 5')"
check_str "all even (all)"    "true"       "$(all "$EVEN" '2 4 6')"
check_str "all even (empty)"  "true"       "$(all "$EVEN" '')"

section "List combinators reconstruct the Layer-1 word ops"
A='1 0 1 1'; B='1 1 0 1'
# the gates take true/false, so the bit-level combiners bridge 0/1 ↔ true/false
BXOR='bool_to_bit "$(ne  "$(bit_to_bool "$1")" "$(bit_to_bool "$2")")"'
BAND='bool_to_bit "$(and "$(bit_to_bool "$1")" "$(bit_to_bool "$2")")"'
BOR='bool_to_bit  "$(or  "$(bit_to_bool "$1")" "$(bit_to_bool "$2")")"'
IS1='if [ "$1" = 1 ]; then echo true; else echo false; fi'
check_str "map flip_bit   == word_not" "$(word_not "$A")"    "$(map "$(lift flip_bit)" "$A")"
check_str "zipwith xor    == word_xor" "$(word_xor "$A" "$B")" "$(zipwith "$BXOR" "$A" "$B")"
check_str "zipwith and    == word_and" "$(word_and "$A" "$B")" "$(zipwith "$BAND" "$A" "$B")"
check_str "zipwith or     == word_or"  "$(word_or  "$A" "$B")" "$(zipwith "$BOR"  "$A" "$B")"
check_str "all (=1) bits  == and_all"  "$(and_all '1 1 1 1')" "$(all "$IS1" '1 1 1 1')"
check_str "all (=1) w/gap == and_all"  "$(and_all '1 1 0 1')" "$(all "$IS1" '1 1 0 1')"
check_str "any (=1) bits  == or_all"   "$(or_all  '0 0 1 0')" "$(any "$IS1" '0 0 1 0')"
check_str "zipwith ne on true/false"   "false true true"      "$(zipwith ne 'true false true' 'true true false')"
check_str "foldl and (all set)  = and_all"  "true"  "$(foldl and true 'true true true')"
check_str "foldl and (a gap)    = and_all"  "false" "$(foldl and true 'true false true')"

section "Church numerals (number IS n-fold composition)"
check_str "to_int(zero) = 0"           "0" "$(cn "$(church_zero)")"
check_str "to_int(succ³ zero) = 3"     "3" "$(cn "$(church_succ "$(church_succ "$(church_succ "$(church_zero)")")")")"
check_str "int 5 → church → int"       "5" "$(cn "$(ci 5)")"
check_str "is_zero(0) = true"   "true"  "$(church_is_zero "$(ci 0)")"
check_str "is_zero(3) = false"  "false" "$(church_is_zero "$(ci 3)")"

section "Church arithmetic via the canonical λ-identities"
check_str "plus 2 3 = 5"   "5"  "$(cn "$(church_plus "$(ci 2)" "$(ci 3)")")"
check_str "plus 0 4 = 4"   "4"  "$(cn "$(church_plus "$(ci 0)" "$(ci 4)")")"
check_str "mult 3 4 = 12"  "12" "$(cn "$(church_mult "$(ci 3)" "$(ci 4)")")"
check_str "mult 5 0 = 0"   "0"  "$(cn "$(church_mult "$(ci 5)" "$(ci 0)")")"
check_str "pow 2 5 = 32"   "32" "$(cn "$(church_pow "$(ci 2)" "$(ci 5)")")"
check_str "pow 3 3 = 27"   "27" "$(cn "$(church_pow "$(ci 3)" "$(ci 3)")")"
check_str "pow 4 0 = 1"    "1"  "$(cn "$(church_pow "$(ci 4)" "$(ci 0)")")"

section "Church booleans & if/and/or/not"
check_str "if TRUE  → 1st" "yes" "$(church_if "$CHURCH_TRUE" yes no)"
check_str "if FALSE → 2nd" "no"  "$(church_if "$CHURCH_FALSE" yes no)"
check_str "and T F = false" "false" "$(church_to_bool "$(church_band "$CHURCH_TRUE" "$CHURCH_FALSE")")"
check_str "and T T = true"  "true"  "$(church_to_bool "$(church_band "$CHURCH_TRUE" "$CHURCH_TRUE")")"
check_str "or  T F = true"  "true"  "$(church_to_bool "$(church_bor  "$CHURCH_TRUE" "$CHURCH_FALSE")")"
check_str "or  F F = false" "false" "$(church_to_bool "$(church_bor  "$CHURCH_FALSE" "$CHURCH_FALSE")")"
check_str "not T = false"   "false" "$(church_to_bool "$(church_bnot "$CHURCH_TRUE")")"

section "Church pairs (cons / car / cdr)"
check_str "car(cons 3 7) = 3" "3" "$(cn "$(car "$(cons "$(ci 3)" "$(ci 7)")")")"
check_str "cdr(cons 3 7) = 7" "7" "$(cn "$(cdr "$(cons "$(ci 3)" "$(ci 7)")")")"

section "Church predecessor (via pairs) & truncated subtraction"
for n in 0 1 2 3 4 6; do
    check_str "pred $n" "$(( n>0 ? n-1 : 0 ))" "$(cn "$(church_pred "$(ci $n)")")"
done
for tc in "5 3" "7 2" "3 3" "2 5" "6 0" "9 4"; do
    set -- $tc
    check_str "sub $1 $2 (monus)" "$(( $1-$2 < 0 ? 0 : $1-$2 ))" "$(cn "$(church_sub "$(ci $1)" "$(ci $2)")")"
done

section "Church ordering & division (leq / lt / eq / div) — complete ordered arithmetic"
# kept to small operands: these recurse through pred/sub and are slow
for tc in "2 5" "5 2" "3 3" "0 0" "4 0"; do
    set -- $tc
    check_str "leq $1 $2" "$([ $1 -le $2 ] && echo true || echo false)" "$(church_leq "$(ci $1)" "$(ci $2)")"
    check_str "lt  $1 $2" "$([ $1 -lt $2 ] && echo true || echo false)" "$(church_lt  "$(ci $1)" "$(ci $2)")"
    check_str "eq  $1 $2" "$([ $1 -eq $2 ] && echo true || echo false)" "$(church_eq  "$(ci $1)" "$(ci $2)")"
done
check_str "div 6 2 = 3"  "3" "$(cn "$(church_div "$(ci 6)" "$(ci 2)")")"
check_str "div 7 3 = 2"  "2" "$(cn "$(church_div "$(ci 7)" "$(ci 3)")")"
check_str "div 5 2 = 2"  "2" "$(cn "$(church_div "$(ci 5)" "$(ci 2)")")"
check_str "div 4 4 = 1"  "1" "$(cn "$(church_div "$(ci 4)" "$(ci 4)")")"
check_str "div 1 3 = 0"  "0" "$(cn "$(church_div "$(ci 1)" "$(ci 3)")")"

section "Church higher-order: the SAME numeral iterates any function"
# Numeral 5 applied to a star-appender (a non-arithmetic fn value) → '*****'.
STAR='printf "%s*" "$1"'
check_str "5 applied to '*'-appender = *****" "*****" "$(apply "$(apply "$(ci 5)" "$STAR")" "")"

section "Church cross-layer: a numeral composes the Layer-1 inc circuit"
check_str "church 5 → bits → 5"   "5"  "$(bits_to_int "$(church_to_bits 5)")"
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
