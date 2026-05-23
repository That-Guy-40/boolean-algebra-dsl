#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# COMBINATOR CIRCUITS — Layer 1's word ops, rebuilt from the FUNCTION side
#
# Layer 1 (boolean-funcs-new.sh) builds words imperatively: loops that walk a bit
# array. This file rebuilds the SAME words declaratively, from the combinators in
# list-processing-kit.sh — map / zipwith / foldl / scanl. Two independent
# constructions of the identical circuit, proven bit-for-bit equal in
# test-combinator-circuits.sh. (A machine-style loop and a function-style fold
# computing the same thing is a Church–Turing wink in miniature — and the whole
# point of the file.)
#
# Names are `fp_*` (function-side) so they sit ALONGSIDE Layer 1's word_* / ripple_*
# / shl / shr without clobbering them — the tests compare the two. It still bottoms
# out in the same gates: the bit combiners below bridge 0/1 ↔ the true/false that
# the NAND-built gates (and/or/ne) speak; flip_bit is already bit-native.
#
#   bit_and/or/xor/xor3              2-/3-input gates lifted to 0/1 bits
#   fp_word_not/and/or/xor           bitwise word ops  =  map / zipwith a bit gate
#   fp_and_all/or_all/xor_all        reductions        =  (map to bool) then fold
#   fp_half_adder / fp_full_adder    the adder cells, composed from the bit gates
#   fp_word_add          ★           ripple adder as a left fold threading the carry
#   fp_carry_chain       ★           the carry rippling in at each bit, via scanl
#   fp_word_add_scan     ★           the adder rebuilt from carry_chain + zipwith3
#   fp_and_words/or_words/xor_words  n-ary: fold a word op over several words
#   fp_add_words                     n-ary sum: fold the adder over several words
#   fp_shl / fp_shr / fp_rol / fp_ror   shifts & rotates as pure list surgery
# ─────────────────────────────────────────────────────────────────────────────

_CC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_CC_DIR/boolean-funcs-new.sh"     # the NAND-built gates + bit helpers (the primitives)
source "$_CC_DIR/list-processing-kit.sh"   # map / zipwith / foldl / scanl (the combinators)
# Source order matters: the kit loads LAST so its list combinators (all/any/lhead/
# ltail) win the name clashes with Layer 1; Layer 1's and_all/or_all/xor_all and the
# gates stay reachable under their own names. (Same arrangement as alt-arithmetic.sh.)

# ── Bit-level gates: bridge 0/1 bits ↔ the true/false the gates speak ─────────
# (flip_bit, from Layer 1, is already the bit-native NOT.)
bit_and  () { bool_to_bit "$(and "$(bit_to_bool "$1")" "$(bit_to_bool "$2")")"; }
bit_or   () { bool_to_bit "$(or  "$(bit_to_bool "$1")" "$(bit_to_bool "$2")")"; }
bit_xor  () { bool_to_bit "$(ne  "$(bit_to_bool "$1")" "$(bit_to_bool "$2")")"; }
bit_xor3 () { bit_xor "$(bit_xor "$1" "$2")" "$3"; }                  # 3-input XOR (the adder's sum bit)

# ── Bitwise word algebra: each is one map / zipwith over a bit gate ───────────
fp_word_not () { map flip_bit "$1"; }            # = word_not
fp_word_and () { zipwith bit_and "$1" "$2"; }    # = word_and
fp_word_or  () { zipwith bit_or  "$1" "$2"; }    # = word_or
fp_word_xor () { zipwith bit_xor "$1" "$2"; }    # = word_xor

# ── Reductions: map each bit to true/false, then fold ─────────────────────────
fp_and_all () { and_list "$(map bit_to_bool "$1")"; }        # = and_all  (∀ bits set)
fp_or_all  () { or_list  "$(map bit_to_bool "$1")"; }        # = or_all   (∃ a set bit)
fp_xor_all () { foldl ne false "$(map bit_to_bool "$1")"; }  # = xor_all  (odd parity)

# ── The adder cells, composed from the bit gates ──────────────────────────────
fp_half_adder () {                        # a b      -> "sum carry"   (= half_adder)
  printf '%s %s' "$(bit_xor "$1" "$2")" "$(bit_and "$1" "$2")"
}
fp_full_adder () {                        # a b cin  -> "sum carry"   (= full_adder)
  # Two half adders feeding an OR on the carries — the cells building on each other.
  local h1 s1 c1 h2 s2 c2
  h1=$(fp_half_adder "$1" "$3"); s1=${h1% *}; c1=${h1#* }
  h2=$(fp_half_adder "$s1" "$2"); s2=${h2% *}; c2=${h2#* }
  printf '%s %s' "$s2" "$(bit_or "$c1" "$c2")"
}

# ── ★ The ripple adder as a LEFT FOLD that threads the carry ──────────────────
# The accumulator is "carry|bits-so-far": each step feeds the carry into a full
# adder and appends the sum bit. Width = the operands' length, so it is n-bit for
# free. Output matches word_add: the W result bits, then the carry-out.
_fp_add_step () {                         # foldl combiner:  "carry|bits"  "a:b"  -> "carry'|bits'"
  local carry="${1%%|*}" bits="${1#*|}" a="${2%%:*}" b="${2#*:}" r sum cout
  r=$(fp_full_adder "$a" "$b" "$carry"); sum=${r% *}; cout=${r#* }
  printf '%s|%s' "$cout" "${bits:+$bits }$sum"
}
# zero-extend (or clip) word $1 to width $2 — lets the adder take unequal widths,
# matching word_add, which pads the shorter operand with 0s. (Pure list surgery.)
_fp_zext () { take "$2" "$1 $(replicate "$2" 0)"; }

fp_word_add () {                          # "A.." "B.." [Cin]  ->  "S.. Cout"   (= word_add)
  local A="$1" B="$2" w wb; w=$(llength "$A"); wb=$(llength "$B"); [ "$wb" -gt "$w" ] && w=$wb
  A=$(_fp_zext "$A" "$w"); B=$(_fp_zext "$B" "$w")   # pad the shorter operand to the common width
  local acc; acc=$(foldl _fp_add_step "${3:-0}|" "$(zip "$A" "$B")")
  printf '%s' "${acc#*|} ${acc%%|*}"      # bits, then carry-out
}

# ── ★ The carry chain, exposed by a SCAN ──────────────────────────────────────
# scanl keeps every running accumulator, so scanning the carry alone shows the
# carry rippling IN at each bit position, ending with the carry-out:
#   "Cin c1 c2 … c{w-1} Cout"    (w+1 values)
_fp_carry_step () { local r; r=$(fp_full_adder "${2%%:*}" "${2#*:}" "$1"); printf '%s' "${r#* }"; }
fp_carry_chain () { scanl _fp_carry_step "${3:-0}" "$(zip "$1" "$2")"; }

# ── ★ The adder, rebuilt a SECOND way: carry chain + a ternary zipwith ─────────
# Once the carry into every position is known, each sum bit is just
# a_i ⊕ b_i ⊕ carry_in_i — a single zipwith3. (Same answer as fp_word_add.)
fp_word_add_scan () {                     # "A.." "B.." [Cin]  ->  "S.. Cout"
  local A="$1" B="$2" w wb carries cin_chain cout sums
  w=$(llength "$A"); wb=$(llength "$B"); [ "$wb" -gt "$w" ] && w=$wb
  A=$(_fp_zext "$A" "$w"); B=$(_fp_zext "$B" "$w")
  carries=$(fp_carry_chain "$A" "$B" "${3:-0}")
  cin_chain=$(take "$w" "$carries")       # the carry into each of the W positions
  cout=$(drop "$w" "$carries")            # the final carry-out
  sums=$(zipwith3 bit_xor3 "$A" "$B" "$cin_chain")
  printf '%s' "${sums:+$sums }$cout"
}

# ── n-ary: a 2-input gate goes variadic by folding it over the inputs ─────────
# Two flavours of "n-ary bit input via a reducer":
#   • over the BITS of one word — that IS fp_and_all / fp_or_all / fp_xor_all above
#     (an N-input AND/OR/XOR gate is the 2-input gate folded over N bits). Width is
#     arbitrary precisely because it is a fold over a list.
#   • over several equal-width WORDS — folded here. (Words contain spaces, so they
#     cannot be kit-list atoms; the fold runs over the argument list "$@" instead.)
fp_and_words () { local a="$1"; shift; local w; for w in "$@"; do a=$(fp_word_and "$a" "$w"); done; printf '%s' "$a"; }
fp_or_words  () { local a="$1"; shift; local w; for w in "$@"; do a=$(fp_word_or  "$a" "$w"); done; printf '%s' "$a"; }
fp_xor_words () { local a="$1"; shift; local w; for w in "$@"; do a=$(fp_word_xor "$a" "$w"); done; printf '%s' "$a"; }
fp_add_words () {                         # sum several words; the result widens by a bit per add, value stays exact
  local a="$1"; shift; local w; for w in "$@"; do a=$(fp_word_add "$a" "$w"); done; printf '%s' "$a"
}

# ── Shifts & rotates as PURE LIST SURGERY (no arithmetic — just take/drop/pad) ─
# LSB-first, so the LSB is at the front. A left shift pads a 0 at the front and
# drops the top; a right shift drops the front and pads a 0 at the top. Rotates
# carry the wrapped slice around instead of dropping it.
fp_shl () { local xs="$1" n="${2:-1}" w; w=$(llength "$xs"); take "$w" "$(replicate "$n" 0) $xs"; }            # = shl
fp_shr () { local xs="$1" n="${2:-1}" w; w=$(llength "$xs"); take "$w" "$(drop "$n" "$xs") $(replicate "$n" 0)"; }  # = shr
fp_rol () {                               # rotate left by n (cyclic): last n atoms wrap to the front
  local xs="$1" n="${2:-1}" w k; w=$(llength "$xs"); [ "$w" -eq 0 ] && return; k=$((n % w))
  printf '%s' "$(drop $((w-k)) "$xs")${k:+ }$(take $((w-k)) "$xs")"
}
fp_ror () {                               # rotate right by n (cyclic): first n atoms wrap to the back
  local xs="$1" n="${2:-1}" w k; w=$(llength "$xs"); [ "$w" -eq 0 ] && return; k=$((n % w))
  printf '%s' "$(drop "$k" "$xs")${k:+ }$(take "$k" "$xs")"
}
