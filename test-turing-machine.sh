#!/bin/bash
# Tests for turing-machine.sh — the bounded-tape Turing machine.
#
# Sources turing-machine.sh and boolean-funcs-new.sh. The headline checks wire the
# TM back to Layer 1: the binary-increment TM must equal `inc`, and the bit-flip TM
# must equal `word_not` — the tape machine and the gate circuit computing the same
# thing. Also checks the theory anchor (an FSM is a TM that only moves right and
# never writes) and the busy beavers' exact (1-count, step-count). A touch slow
# (a subshell per step), so it lives outside the fast core.

source "$(dirname "${BASH_SOURCE[0]}")/turing-machine.sh"
source "$(dirname "${BASH_SOURCE[0]}")/boolean-funcs-new.sh"   # inc, word_not, int_to_bits, bits_to_int

PASS=0; FAIL=0
section () { printf '\n── %s\n' "$1"; }
check_str () {
  local desc="$1" exp="$2" got="$3"
  if [ "$got" = "$exp" ]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); printf 'FAIL  %-46s want=[%s] got=[%s]\n' "$desc" "$exp" "$got"; fi
}
ones () { local n=0 c; for c in $1; do [ "$c" = 1 ] && n=$((n+1)); done; echo "$n"; }

section "tm_step — a pure config -> config function"
check_str "one step of binary inc"     "c|1|0 1 0 0" "$(tm_step "$TM_BINARY_INC" "c|0|1 1 0 0")"
out=$(tm_step "$TM_BINARY_INC" "h|2|0 0 1 0"); rc=$?      # halt state: no rule fires
check_str "no rule -> exit 1"          "1" "$rc"

section "unary increment / addition"
check_str "unary inc 1 1 1"   "1 1 1 1"     "$(tm_run "$TM_UNARY_INC" h s '1 1 1')"
check_str "unary inc (empty)" "1"           "$(tm_run "$TM_UNARY_INC" h s '')"
check_str "unary add 3 + 2"   "1 1 1 1 1"   "$(tm_run "$TM_UNARY_ADD" h a '1 1 1 + 1 1')"
check_str "unary add 2 + 0"   "1 1"         "$(tm_run "$TM_UNARY_ADD" h a '1 1 +')"
check_str "unary add 0 + 0"   ""            "$(tm_run "$TM_UNARY_ADD" h a '+')"

section "bit-flip TM == Layer-1 word_not"
for s in "1 0 1 1" "0 0 0 0" "1 1 1 1" "1 0 0 1 1 0"; do
  check_str "flip [$s]" "$(word_not "$s")" "$(tm_run "$TM_FLIP" h s "$s")"
done

section "★ binary-increment TM == Layer-1 inc  (the tape machine = the gate circuit)"
for n in 0 1 2 3 7 8 14 50 100 200; do
  tmv=$(bits_to_int "$(tm_run "$TM_BINARY_INC" h c "$(int_to_bits "$n" 8)")")
  incv=$(bits_to_int "$(inc "$(int_to_bits "$n" 8)")")
  check_str "binc $n -> $((n+1))"   "$((n+1))" "$tmv"
  check_str "binc $n == inc $n"     "$incv"    "$tmv"
done

section "★ an FSM is the restricted TM (parity, right-moving + never writing)"
for s in "1 1 0 1" "1 1 1 1" "1 0 1 0" "0"; do
  fsm=$(fsm_run "$FSM_PARITY" e "$s")                 # e / o
  last=$(tm_trace "$TM_PARITY" "he ho" e "$s" | tail -1); tmstate="${last%%|*}"
  want=$([ "$fsm" = e ] && echo he || echo ho)        # he <-> even, ho <-> odd
  check_str "FSM-as-TM parity [$s]" "$want" "$tmstate"
done

section "busy beavers — they halt, after writing Σ ones in S steps"
__b=$TM_BLANK; TM_BLANK=0; C=$((TM_TAPE / 2))         # busy beavers want blank=0 and a centred head
check_str "BB-2 writes 4 ones"     "4"  "$(ones "$(tm_run "$TM_BB2" H A '' 50 "$C")")"
check_str "BB-2 halts in 6 steps"  "6"  "$(tm_steps "$TM_BB2" H A '' 50 "$C")"
check_str "BB-3 writes 6 ones"     "6"  "$(ones "$(tm_run "$TM_BB3" H A '' 100 "$C")")"
check_str "BB-3 halts in 14 steps" "14" "$(tm_steps "$TM_BB3" H A '' 100 "$C")"
TM_BLANK=$__b

section "bounded tape — a runaway machine halts at the edge (not an infinite loop)"
__t=$TM_TAPE; TM_TAPE=8
check_str "walk off an 8-cell tape in 8 steps" "8" "$(tm_steps 'g,_->g,_,R' h g '' 1000)"
TM_TAPE=$__t

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
