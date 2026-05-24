#!/bin/bash
# Tests for combinator-circuits.sh — the function-side reconstruction of Layer 1.
#
# THE PAYOFF SUITE: every fp_* (built from map / zipwith / foldl / scanl) is checked
# bit-for-bit against the imperative Layer-1 original it rebuilds. Sourcing
# combinator-circuits.sh pulls in both boolean-funcs-new.sh (the originals) and
# list-processing-kit.sh (the combinators), so both constructions are in scope at
# once. Slow (gate-level subshells per bit), so it lives OUTSIDE the fast core suite.

source "$(dirname "${BASH_SOURCE[0]}")/../combinator-circuits.sh"

PASS=0; FAIL=0
section () { printf '\n── %s\n' "$1"; }
# `same`: assert two constructions produced the identical string. (Deliberately not
# named `eq` — that is a Layer-1 gate, now in scope, and we must not shadow it.)
same () {
  local desc="$1" exp="$2" got="$3"
  if [ "$got" = "$exp" ]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); printf 'FAIL  %-48s want=[%s] got=[%s]\n' "$desc" "$exp" "$got"; fi
}

section "bitwise word ops == Layer 1 (4- and 8-bit)"
for pair in "1 0 1 1|1 1 0 1" "0 0 0 0|1 1 1 1" "1 0 1 0 1 0 1 0|1 1 0 0 1 1 0 0"; do
  A=${pair%|*}; B=${pair#*|}
  same "fp_word_not [$A]"    "$(word_not "$A")"      "$(fp_word_not "$A")"
  same "fp_word_and [$A,$B]" "$(word_and "$A" "$B")" "$(fp_word_and "$A" "$B")"
  same "fp_word_or  [$A,$B]" "$(word_or  "$A" "$B")" "$(fp_word_or  "$A" "$B")"
  same "fp_word_xor [$A,$B]" "$(word_xor "$A" "$B")" "$(fp_word_xor "$A" "$B")"
done

section "reductions == Layer 1 (and_all / or_all / xor_all)"
for W in '1 1 1 1' '1 1 0 1' '0 0 0 0' '1 0 1 0' '1 1 1 1 1 1 1 1' '1 0 0 0 0 0 0 1'; do
  same "fp_and_all [$W]" "$(and_all "$W")" "$(fp_and_all "$W")"
  same "fp_or_all  [$W]" "$(or_all  "$W")" "$(fp_or_all  "$W")"
  same "fp_xor_all [$W]" "$(xor_all "$W")" "$(fp_xor_all "$W")"
done

section "adder cells == Layer 1 (half_adder; full_adder over all 8 combos)"
same "fp_half_adder 0 0" "$(half_adder 0 0)" "$(fp_half_adder 0 0)"
same "fp_half_adder 0 1" "$(half_adder 0 1)" "$(fp_half_adder 0 1)"
same "fp_half_adder 1 0" "$(half_adder 1 0)" "$(fp_half_adder 1 0)"
same "fp_half_adder 1 1" "$(half_adder 1 1)" "$(fp_half_adder 1 1)"
for a in 0 1; do for b in 0 1; do for c in 0 1; do
  same "fp_full_adder $a $b $c" "$(full_adder $a $b $c)" "$(fp_full_adder $a $b $c)"
done; done; done

section "★ ripple adder as a left fold == word_add (4-bit grid + carry-in)"
for a in 0 1 5 8 15; do for b in 0 3 7 15; do
  same "fp_word_add $a+$b" \
       "$(word_add    "$(int_to_bits $a 4)" "$(int_to_bits $b 4)")" \
       "$(fp_word_add "$(int_to_bits $a 4)" "$(int_to_bits $b 4)")"
done; done
same "fp_word_add 3+5+Cin1 = 9" "9" "$(bits_to_int "$(fp_word_add "$(int_to_bits 3 4)" "$(int_to_bits 5 4)" 1)")"

section "★ THREE constructions agree (fold == scan+zipwith3 == word_add), 8-bit"
for a in 0 1 170 255; do for b in 0 85 255; do
  l1=$(word_add        "$(int_to_bits $a 8)" "$(int_to_bits $b 8)")
  fold=$(fp_word_add   "$(int_to_bits $a 8)" "$(int_to_bits $b 8)")
  scan=$(fp_word_add_scan "$(int_to_bits $a 8)" "$(int_to_bits $b 8)")
  same "fold == word_add ($a+$b)" "$l1"   "$fold"
  same "scan == fold     ($a+$b)" "$fold" "$scan"
done; done

section "★ carry chain (scanl) — the carry rippling in at each bit position"
# 3+5 (4-bit): bit0 1+1 makes carry 1; it ripples up through bits 1,2; clears at bit3.
same "carry_chain 3+5  (4b)" "0 1 1 1 0" "$(fp_carry_chain "$(int_to_bits 3 4)"  "$(int_to_bits 5 4)")"
same "carry_chain 0+0  (4b)" "0 0 0 0 0" "$(fp_carry_chain "$(int_to_bits 0 4)"  "$(int_to_bits 0 4)")"
same "carry_chain 15+1 (4b)" "0 1 1 1 1" "$(fp_carry_chain "$(int_to_bits 15 4)" "$(int_to_bits 1 4)")"

section "n-ary: fold a word op over several words"
same "fp_and_words 15&14&12" "$(int_to_bits 12 4)" "$(fp_and_words "$(int_to_bits 15 4)" "$(int_to_bits 14 4)" "$(int_to_bits 12 4)")"
same "fp_or_words  1|2|4"    "$(int_to_bits 7 4)"  "$(fp_or_words  "$(int_to_bits 1 4)"  "$(int_to_bits 2 4)"  "$(int_to_bits 4 4)")"
same "fp_xor_words 1^2^3 = 0"          "0"   "$(bits_to_int "$(fp_xor_words "$(int_to_bits 1 4)" "$(int_to_bits 2 4)" "$(int_to_bits 3 4)")")"
same "fp_add_words 3+5+4+1 = 13"       "13"  "$(bits_to_int "$(fp_add_words "$(int_to_bits 3 4)" "$(int_to_bits 5 4)" "$(int_to_bits 4 4)" "$(int_to_bits 1 4)")")"
same "fp_add_words 200+100+50 = 350"   "350" "$(bits_to_int "$(fp_add_words "$(int_to_bits 200 8)" "$(int_to_bits 100 8)" "$(int_to_bits 50 8)")")"

section "shifts & rotates as list surgery == Layer 1"
for w in "$(int_to_bits 3 8)" "$(int_to_bits 201 8)" "$(int_to_bits 5 4)"; do
  same "fp_shl [$w]" "$(shl "$w")" "$(fp_shl "$w")"
  same "fp_shr [$w]" "$(shr "$w")" "$(fp_shr "$w")"
  same "fp_rol [$w]" "$(rol "$w")" "$(fp_rol "$w")"
  same "fp_ror [$w]" "$(ror "$w")" "$(fp_ror "$w")"
done
same "fp_shl by3 (8b)" "$(shl "$(int_to_bits 5 8)" 3)"   "$(fp_shl "$(int_to_bits 5 8)" 3)"
same "fp_shr by2 (8b)" "$(shr "$(int_to_bits 200 8)" 2)" "$(fp_shr "$(int_to_bits 200 8)" 2)"
same "fp_rol by3 (8b)" "$(rol "$(int_to_bits 201 8)" 3)" "$(fp_rol "$(int_to_bits 201 8)" 3)"
same "fp_ror by3 (8b)" "$(ror "$(int_to_bits 201 8)" 3)" "$(fp_ror "$(int_to_bits 201 8)" 3)"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
