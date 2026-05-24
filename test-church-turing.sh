#!/bin/bash
# Tests for church-turing.sh — THE CAPSTONE.
#
# The point of the whole project, asserted: the same function, computed on the
# function side (pure lambda / SKI, and Church numerals), the machine side (a Turing
# machine), and the circuit side (Layer-1 gates), lands on the same answer every
# time. Church/lambda count through the gates, so this is slow — small inputs only.

source "$(dirname "${BASH_SOURCE[0]}")/church-turing.sh"

PASS=0; FAIL=0
section () { printf '\n── %s\n' "$1"; }
check_str () {
  local desc="$1" exp="$2" got="$3"
  if [ "$got" = "$exp" ]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); printf 'FAIL  %-52s want=[%s] got=[%s]\n' "$desc" "$exp" "$got"; fi
}

section "successor n -> n+1 agrees across lambda / Church / Turing / gates"
for n in 0 1 2 5 8; do
  want=$((n + 1))
  check_str "lambda  succ $n  = $want" "$want" "$(ct_succ_lambda  "$n")"
  check_str "Church  succ $n  = $want" "$want" "$(ct_succ_church  "$n")"
  check_str "Turing  succ $n  = $want" "$want" "$(ct_succ_machine "$n")"
  check_str "circuit succ $n  = $want" "$want" "$(ct_succ_circuit "$n")"
done

section "addition n + m agrees across lambda / Church / Turing / gates"
for pair in "0 0" "1 2" "3 4" "2 5" "6 4"; do
  set -- $pair; n="$1"; m="$2"; want=$((n + m))
  check_str "lambda  $n+$m = $want" "$want" "$(ct_add_lambda  "$n" "$m")"
  check_str "Church  $n+$m = $want" "$want" "$(ct_add_church  "$n" "$m")"
  check_str "Turing  $n+$m = $want" "$want" "$(ct_add_machine "$n" "$m")"
  check_str "circuit $n+$m = $want" "$want" "$(ct_add_circuit "$n" "$m")"
done

section "the function -> circuit bridge: a Church numeral drives the inc gates"
for n in 0 1 5 8 11; do
  check_str "church_to_bits $n decodes to $n" "$n" "$(ct_church_to_bits_value "$n")"
done

section "the headline: every model agrees (a single cross-model assertion)"
n=7
all=$(printf '%s\n' "$(ct_succ_lambda $n)" "$(ct_succ_church $n)" "$(ct_succ_machine $n)" "$(ct_succ_circuit $n)" | sort -u | tr '\n' ' ')
check_str "succ 7: lambda=Church=Turing=gates=8" "8 " "$all"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
