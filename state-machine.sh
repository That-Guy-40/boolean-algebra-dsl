#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# STATE MACHINE — a Finite State Machine driver (the machine side, part 1)
#
# An FSM is a transition TABLE of rules "state,symbol->nextstate" (space-separated),
# a start state, and a set of accept states. The lovely part: *running an FSM is a
# left fold of the transition over the input* — so `fsm_run` is literally `foldl`
# from the list kit, threading the state as the accumulator; `fsm_trace` is the
# matching `scanl` (the state visited after every symbol).
#
# This is the restricted half of the machine layer: a Turing machine
# (turing-machine.sh) is this same finite-state control PLUS a read/write tape. An
# FSM is the special case that cannot write and only moves one way.
#
#   fsm_step    TABLE STATE SYMBOL          -> next state ("DEAD" if no rule)
#   fsm_run     TABLE START INPUT           -> final state              (a foldl)
#   fsm_trace   TABLE START INPUT           -> the state after each symbol (a scanl)
#   fsm_accepts TABLE START ACCEPTS INPUT   -> "accept" / "reject"
# ─────────────────────────────────────────────────────────────────────────────

source "$(dirname "${BASH_SOURCE[0]}")/list-processing-kit.sh"   # foldl / scanl

fsm_step () {            # TABLE STATE SYMBOL -> next state
  local table="$1" key="$2,$3" r
  for r in $table; do case "$r" in "$key->"*) printf '%s' "${r#*->}"; return 0 ;; esac; done
  printf 'DEAD'          # no rule for (state, symbol): fall into a dead / trap state
}

# Running the machine = folding the transition over the input, the state as the
# accumulator. (The transition table is baked into the fold's combiner via %q.)
fsm_run () {             # TABLE START INPUT -> final state
  foldl "fsm_step $(printf '%q' "$1") \"\$1\" \"\$2\"" "$2" "$3"
}
# The whole state history = the matching scan: the start state, then one per symbol.
fsm_trace () {           # TABLE START INPUT -> states visited
  scanl "fsm_step $(printf '%q' "$1") \"\$1\" \"\$2\"" "$2" "$3"
}
fsm_accepts () {         # TABLE START ACCEPTS INPUT -> accept / reject
  local final; final=$(fsm_run "$1" "$2" "$4")
  case " $3 " in *" $final "*) printf 'accept' ;; *) printf 'reject' ;; esac
}

# ── Example machines (tables as variables; start / accept noted) ──────────────

# Parity of the 1-bits. States e(ven) / o(dd); start e; accept e. (Ties to xor_all.)
FSM_PARITY='e,0->e e,1->o o,0->o o,1->e'

# "Divisible by 3", reading a binary string MOST-significant bit first. The states
# are the running remainder r0/r1/r2 (new = (2·r + bit) mod 3); start r0; accept r0.
FSM_DIV3='r0,0->r0 r0,1->r1 r1,0->r2 r1,1->r0 r2,0->r1 r2,1->r2'

# Sequence detector: does "1 0 1" appear anywhere in the input? Start q0; accept q3
# (an absorbing "seen it" state).
FSM_SEQ101='q0,0->q0 q0,1->q1 q1,0->q2 q1,1->q1 q2,0->q0 q2,1->q3 q3,0->q3 q3,1->q3'

# A turnstile — not an acceptor, just a state that evolves. Inputs: push / coin.
# Start locked.
FSM_TURNSTILE='locked,push->locked locked,coin->unlocked unlocked,push->locked unlocked,coin->unlocked'

# example use (FSM):
#   fsm_run     "$FSM_PARITY" e '1 1 0 1'              # o   (three 1s = odd)
#   fsm_trace   "$FSM_PARITY" e '1 1 0 1'              # e o e e o
#   fsm_accepts "$FSM_DIV3" r0 r0 '1 1 0'             # accept   (110 = 6)
#   fsm_accepts "$FSM_SEQ101" q0 q3 '0 1 0 1 0'       # accept   (contains 1 0 1)
#   fsm_run     "$FSM_TURNSTILE" locked 'coin push'   # locked
