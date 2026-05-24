#!/bin/bash
# Tests for state-machine.sh — the Finite State Machine driver.
#
# Sources state-machine.sh and boolean-funcs-new.sh: every FSM verdict is checked
# against an independent ground truth (popcount, value mod 3, substring search), and
# the parity machine is tied back to Layer 1's `xor_all`. Fast (folds over short
# lists).

source "$(dirname "${BASH_SOURCE[0]}")/state-machine.sh"
source "$(dirname "${BASH_SOURCE[0]}")/boolean-funcs-new.sh"   # xor_all, for the Layer-1 tie

PASS=0; FAIL=0
section () { printf '\n── %s\n' "$1"; }
check_str () {
  local desc="$1" exp="$2" got="$3"
  if [ "$got" = "$exp" ]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); printf 'FAIL  %-44s want=[%s] got=[%s]\n' "$desc" "$exp" "$got"; fi
}
pcount ()      { local n=0 c; for c in $1; do [ "$c" = 1 ] && n=$((n+1)); done; echo $((n%2)); }   # parity of 1s
int_to_bin ()  { local n=$1 s=""; [ "$n" -eq 0 ] && { echo 0; return; }; while [ "$n" -gt 0 ]; do s="$((n&1)) $s"; n=$((n>>1)); done; echo "${s% }"; }  # MSB-first

section "fsm_step — single transitions"
check_str "parity e,1 -> o"   "o"    "$(fsm_step "$FSM_PARITY" e 1)"
check_str "parity o,1 -> e"   "e"    "$(fsm_step "$FSM_PARITY" o 1)"
check_str "no rule -> DEAD"   "DEAD" "$(fsm_step "$FSM_PARITY" e x)"

section "parity — vs popcount, and vs Layer-1 xor_all"
for s in "1 1 0 1" "1 1 1 1" "1 0 1 0" "0 0 0 0" "1" ""; do
  fsm=$(fsm_run "$FSM_PARITY" e "$s")
  want=$([ "$(pcount "$s")" = 1 ] && echo o || echo e)
  check_str "parity [$s] = $want" "$want" "$fsm"
  # tie to Layer 1:  odd <-> xor_all true,  even <-> false
  wantx=$([ "$fsm" = o ] && echo true || echo false)
  check_str "parity [$s] agrees with xor_all" "$wantx" "$(xor_all "$s")"
done

section "divisible-by-3 — vs (value mod 3)"
for n in 0 1 3 5 6 9 12 15 16 21; do
  bits=$(int_to_bin "$n")
  want=$([ $((n % 3)) -eq 0 ] && echo accept || echo reject)
  check_str "div3 $n ($bits) = $want" "$want" "$(fsm_accepts "$FSM_DIV3" r0 r0 "$bits")"
done

section "sequence detector '1 0 1' — vs substring search"
for s in "0 1 0 1 0" "1 1 0 0" "1 0 1" "0 0 0" "1 0 0 1 0 1" "1 1 1"; do
  case " $s " in *" 1 0 1 "*) want=accept ;; *) want=reject ;; esac
  check_str "seq101 [$s] = $want" "$want" "$(fsm_accepts "$FSM_SEQ101" q0 q3 "$s")"
done

section "turnstile — state evolution"
check_str "coin unlocks"             "unlocked" "$(fsm_run "$FSM_TURNSTILE" locked 'coin')"
check_str "push (locked) stays"      "locked"   "$(fsm_run "$FSM_TURNSTILE" locked 'push')"
check_str "coin then push relocks"   "locked"   "$(fsm_run "$FSM_TURNSTILE" locked 'coin push')"
check_str "coin coin stays unlocked" "unlocked" "$(fsm_run "$FSM_TURNSTILE" locked 'coin coin')"

section "fsm_trace (scanl) — the state history, and the fold/scan agree"
check_str "parity trace 1 1 0 1" "e o e e o" "$(fsm_trace "$FSM_PARITY" e '1 1 0 1')"
t=$(fsm_trace "$FSM_PARITY" e '1 0 1 1')
check_str "trace's last state == fsm_run" "$(fsm_run "$FSM_PARITY" e '1 0 1 1')" "${t##* }"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
