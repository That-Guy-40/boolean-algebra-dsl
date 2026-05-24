#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# TURING MACHINE — finite-state control + a bounded read/write tape (machine side, part 2)
#
# A Turing machine IS a finite-state control (the FSM idea from state-machine.sh)
# PLUS a tape it can read, WRITE, and step along in either direction. That one
# addition — writing, and moving both ways — is the whole leap from the FSM, and it
# is enough to make the machine universal.
#
# A CONFIGURATION is the string  "state|head|tape"  (tape = space-separated cells).
# `tm_step` is a pure function: config -> next config. The tape is BOUNDED to TM_TAPE
# cells (default 64), padded with the blank symbol TM_BLANK (default "_"); if the
# head runs off either end the machine halts.
#
# A transition TABLE is space-separated rules "state,symbol->newstate,write,move",
# where move ∈ L | R | S(tay). The machine halts on a halt state, or when no rule
# matches the current (state, symbol).
#
#   tm_step  TABLE CONFIG                       -> next config (exit 1 if halted)
#   tm_run   TABLE HALTS START INPUT [max] [h0] -> final tape (trailing blanks trimmed)
#   tm_trace TABLE HALTS START INPUT [max] [h0] -> one configuration per line
#   tm_steps TABLE HALTS START INPUT [max] [h0] -> number of steps taken
# ─────────────────────────────────────────────────────────────────────────────

source "$(dirname "${BASH_SOURCE[0]}")/state-machine.sh"   # the FSM idea (and the kit)

TM_TAPE=64        # bounded tape width, in cells
TM_BLANK='_'      # the blank symbol (set to 0 for the busy beavers below)

tm_step () {      # TABLE CONFIG -> next CONFIG ; exit 1 if no rule fires or head runs off-tape
  local table="$1" config="$2"
  local state="${config%%|*}" rest="${config#*|}"
  local head="${rest%%|*}" tape="${rest#*|}"        # split locals (avoid the dynamic-scope footgun)
  { [ "$head" -lt 0 ] || [ "$head" -ge "$TM_TAPE" ]; } && { printf '%s' "$config"; return 1; }
  local -a T; read -ra T <<< "$tape"
  local sym="${T[head]:-$TM_BLANK}"
  local key="$state,$sym" rule="" r
  for r in $table; do case "$r" in "$key->"*) rule="${r#*->}"; break ;; esac; done
  [ -z "$rule" ] && { printf '%s' "$config"; return 1; }
  local ns="${rule%%,*}" rr="${rule#*,}"
  local wr="${rr%%,*}" mv="${rr#*,}"
  T[head]="$wr"
  case "$mv" in L|l) head=$((head-1)) ;; R|r) head=$((head+1)) ;; esac   # S (or anything else): stay
  printf '%s|%s|%s' "$ns" "$head" "${T[*]}"
}

_tm_pad () {      # echo INPUT padded out to TM_TAPE cells with TM_BLANK
  local -a T; read -ra T <<< "$1"; local i
  for ((i=${#T[@]}; i<TM_TAPE; i++)); do T[i]="$TM_BLANK"; done
  printf '%s' "${T[*]}"
}
tm_run () {       # TABLE HALTS START INPUT [max] [h0] -> final tape (trailing blanks trimmed)
  local table="$1" halts="$2" start="$3" max="${5:-2000}" h0="${6:-0}"
  local config="$start|$h0|$(_tm_pad "$4")" state nc i
  for ((i=0; i<max; i++)); do
    state="${config%%|*}"; case " $halts " in *" $state "*) break ;; esac
    nc="$(tm_step "$table" "$config")" || break; config="$nc"
  done
  local tape="${config#*|}"; tape="${tape#*|}"
  while [ "${tape% $TM_BLANK}" != "$tape" ]; do tape="${tape% $TM_BLANK}"; done   # trim trailing blanks
  [ "$tape" = "$TM_BLANK" ] && tape=""                                            # an all-blank tape is empty
  printf '%s' "$tape"
}
tm_trace () {     # TABLE HALTS START INPUT [max] [h0] -> one configuration per line (start first)
  local table="$1" halts="$2" start="$3" max="${5:-2000}" h0="${6:-0}"
  local config="$start|$h0|$(_tm_pad "$4")" state nc i
  printf '%s\n' "$config"
  for ((i=0; i<max; i++)); do
    state="${config%%|*}"; case " $halts " in *" $state "*) break ;; esac
    nc="$(tm_step "$table" "$config")" || break; printf '%s\n' "$nc"; config="$nc"
  done
}
tm_steps () { local n; n=$(tm_trace "$@" | grep -c .); printf '%s' "$((n - 1))"; }   # transitions taken

# ── Example machines (tables as variables; halt state(s) noted) ───────────────

# Unary increment: walk to the end, append one stroke. Start s, halt h.
#   tm_run "$TM_UNARY_INC" h s '1 1 1'    -> 1 1 1 1
TM_UNARY_INC='s,1->s,1,R s,_->h,1,S'

# Unary addition "a + b" (strokes, a literal + between them) -> (a+b) strokes.
# Replace the + with a stroke, then erase one stroke from the end. Start a, halt h.
#   tm_run "$TM_UNARY_ADD" h a '1 1 1 + 1 1'   -> 1 1 1 1 1
TM_UNARY_ADD='a,1->a,1,R a,+->b,1,R b,1->b,1,R b,_->c,_,L c,1->h,_,S'

# Bitwise complement: flip every bit. Start s, halt h.   (cross-checks Layer-1 word_not)
#   tm_run "$TM_FLIP" h s '1 0 1 1'   -> 0 1 0 0
TM_FLIP='s,0->s,1,R s,1->s,0,R s,_->h,_,S'

# Binary increment, LSB-first: ripple a carry rightward from bit 0. Start c, halt h.
# This is Layer-1's `inc` — the same carry ripple, now walked along a tape.
#   tm_run "$TM_BINARY_INC" h c '1 1 0 0'   -> 0 0 1 0   (3 -> 4)
TM_BINARY_INC='c,1->c,0,R c,0->h,1,S c,_->h,1,S'

# Parity AS A TM: a TM that only moves Right and never changes a cell IS an FSM.
# It halts in he (even) / ho (odd) — exactly the FSM_PARITY verdict. Start e.
TM_PARITY='e,0->e,0,R e,1->o,1,R o,0->o,0,R o,1->e,1,R e,_->he,_,S o,_->ho,_,S'

# Busy beavers — run with `TM_BLANK=0` and a CENTRED head (h0 = TM_TAPE/2, so there
# is room to move left). They HALT, after writing a surprising number of 1s:
#   TM_BLANK=0; tm_run "$TM_BB3" H A '' 100 $((TM_TAPE/2))   -> six 1s, in 14 steps
TM_BB2='A,0->B,1,R A,1->B,1,L B,0->A,1,L B,1->H,1,R'                        # Σ = 4 in 6 steps
TM_BB3='A,0->B,1,R A,1->H,1,R B,0->C,0,R B,1->B,1,R C,0->C,1,L C,1->A,1,L'  # Σ = 6 in 14 steps
