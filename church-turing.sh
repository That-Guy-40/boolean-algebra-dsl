#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# THE CAPSTONE — Church–Turing in action
#
# The whole project, in one handshake. Pick a function and compute it on EVERY model
# this repo builds — and watch them all land on the same answer:
#
#     the FUNCTION side                    the MACHINE side
#   ┌──────────────────────┐            ┌──────────────────────┐
#   │ pure lambda  (SKI)    │            │ a Turing machine     │
#   │ Church numerals       │            │ (bounded tape)       │
#   └──────────────────────┘            └──────────────────────┘
#                    ╲                  ╱
#                     ╲                ╱
#                   the CIRCUIT side: Layer-1 logic gates
#
# That different definitions of "computable" agree is the **Church–Turing thesis**;
# that they all bottom out in the same NAND gates is this project's running theme.
# Successor (n → n+1) is shown four ways; addition (n + m) four ways. They agree.
#
#   ct_show_succ N        pretty side-by-side for n → n+1 (lambda / Church / TM / gates)
#   ct_show_add  N M      pretty side-by-side for n + m
#   ct_demo               run a few of each, plus the function→circuit bridge
#
#   ct_succ_{lambda,church,machine,circuit} N     the four successors (each → n+1)
#   ct_add_{lambda,church,machine,circuit}  N M   the four adders     (each → n+m)
#   ct_church_to_bits_value N   a Church numeral, decoded after it drives the inc gates
# ─────────────────────────────────────────────────────────────────────────────

_CT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_CT_DIR/alt-arithmetic.sh"     # Church numerals (function side) + Layer-1 gates (circuit) + kit
source "$_CT_DIR/lambda.sh"             # + pure lambda / SKI (function side)
source "$_CT_DIR/turing-machine.sh"     # + FSM and the Turing machine (machine side)
# Source order matters only for the kit-vs-Layer-1 name clashes (all/any/lhead/ltail);
# this order is the same one alt-arithmetic.sh already relies on, so every layer works.

CT_WIDTH=12        # bit width for the circuit / TM number representations (room to grow)

# ── small local helpers ───────────────────────────────────────────────────────
_ct_unary      () { local k="$1" s="" i; for ((i=0; i<k; i++)); do s+="1 "; done; printf '%s' "${s% }"; }   # n -> n strokes
_ct_count_ones () { local n=0 c; for c in $1; do [ "$c" = 1 ] && n=$((n+1)); done; printf '%s' "$n"; }

# ── SUCCESSOR  (n → n+1), one definition per model ────────────────────────────
ct_succ_lambda  () { lambda_church_to_int "$(apply "$LAMBDA_SUCC" "$(lambda_church "$1")")"; }            # pure lambda / SKI
ct_succ_church  () { church_to_int "$(church_succ "$(int_to_church "$1")")"; }                            # Church numeral
ct_succ_machine () { bits_to_int "$(tm_run "$TM_BINARY_INC" h c "$(int_to_bits "$1" "$CT_WIDTH")")"; }    # Turing machine
ct_succ_circuit () { bits_to_int "$(inc "$(int_to_bits "$1" "$CT_WIDTH")")"; }                            # Layer-1 gates

# ── ADDITION  (n + m), one definition per model ──────────────────────────────
ct_add_lambda () {                                       # pure lambda: start at n, apply SUCC m times
  local c i; c="$(lambda_church "$1")"
  for ((i=0; i<$2; i++)); do c="$(apply "$LAMBDA_SUCC" "$c")"; done
  lambda_church_to_int "$c"
}
ct_add_church  () { church_to_int "$(church_plus "$(int_to_church "$1")" "$(int_to_church "$2")")"; }     # Church numeral
ct_add_machine () { _ct_count_ones "$(tm_run "$TM_UNARY_ADD" h a "$(_ct_unary "$1") + $(_ct_unary "$2")")"; }  # Turing machine
ct_add_circuit () { bits_to_int "$(word_add "$(int_to_bits "$1" "$CT_WIDTH")" "$(int_to_bits "$2" "$CT_WIDTH")")"; }  # Layer-1 gates

# ── the function → circuit bridge that already existed ────────────────────────
# A Church numeral is a pure function; church_to_bits has it DRIVE the Layer-1 inc
# circuit from zero, building its own bit pattern. The literal handshake.
ct_church_to_bits_value () { bits_to_int "$(church_to_bits "$1")"; }

# ── pretty demonstrations ─────────────────────────────────────────────────────
ct_show_succ () {                                        # ct_show_succ N
  local n="$1" want=$(( $1 + 1 )) l c m g
  l=$(ct_succ_lambda "$n"); c=$(ct_succ_church "$n"); m=$(ct_succ_machine "$n"); g=$(ct_succ_circuit "$n")
  printf 'successor of %s  ->  %s\n' "$n" "$want"
  printf '  function side  ·  pure lambda / SKI (LAMBDA_SUCC)  : %s\n' "$l"
  printf '  function side  ·  Church numeral   (church_succ)   : %s\n' "$c"
  printf '  machine side   ·  Turing machine   (TM_BINARY_INC) : %s\n' "$m"
  printf '  circuit        ·  Layer-1 gates    (inc)           : %s\n' "$g"
  if [ "$l" = "$want" ] && [ "$c" = "$want" ] && [ "$m" = "$want" ] && [ "$g" = "$want" ]
  then printf '  => all four models agree\n'; else printf '  => DISAGREE\n'; fi
}
ct_show_add () {                                         # ct_show_add N M
  local n="$1" mm="$2" want=$(( $1 + $2 )) l c t g
  l=$(ct_add_lambda "$n" "$mm"); c=$(ct_add_church "$n" "$mm")
  t=$(ct_add_machine "$n" "$mm"); g=$(ct_add_circuit "$n" "$mm")
  printf '%s + %s  ->  %s\n' "$n" "$mm" "$want"
  printf '  function side  ·  pure lambda / SKI (SUCC x m)     : %s\n' "$l"
  printf '  function side  ·  Church numeral   (church_plus)   : %s\n' "$c"
  printf '  machine side   ·  Turing machine   (TM_UNARY_ADD)  : %s\n' "$t"
  printf '  circuit        ·  Layer-1 gates    (word_add)      : %s\n' "$g"
  if [ "$l" = "$want" ] && [ "$c" = "$want" ] && [ "$t" = "$want" ] && [ "$g" = "$want" ]
  then printf '  => all four models agree\n'; else printf '  => DISAGREE\n'; fi
}
ct_demo () {                                             # the headline: run a few of each
  ct_show_succ 5; echo; ct_show_succ 9; echo; ct_show_add 3 4; echo; ct_show_add 6 7; echo
  printf 'and the function->circuit handshake: church_to_bits 5 decodes to %s ' "$(ct_church_to_bits_value 5)"
  printf '(a lambda number, built by the gate circuit)\n'
}
