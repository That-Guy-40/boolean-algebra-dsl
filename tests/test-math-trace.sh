#!/bin/bash
# Tests for math-trace.sh — the Layer-3 viewer (derived functions → six primitives).
#
# The viewer's final line is the REAL Layer-3 function (one full-precision bc call),
# so this suite pins that line against the function itself for every NAME it handles,
# and spot-checks that a primitive piece (e.g. sin x, eˣ) equals its own bc value.
# A standalone (non-core) suite.

source "$(dirname "${BASH_SOURCE[0]}")/../math-trace.sh"   # pulls in boolean-funcs-new.sh

PASS=0; FAIL=0
section () { printf '\n── %s\n' "$1"; }
check_str () {
  local desc="$1" exp="$2" got="$3"
  if [ "$got" = "$exp" ]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); printf 'FAIL  %-40s want=[%s] got=[%s]\n' "$desc" "$exp" "$got"; fi
}
final_of () { printf '%s\n' "$1" | sed -n 's/.*= \(.*\)   (the real Layer-3 function)/\1/p'; }

# ── the final line == the real function, for every supported NAME ------------
section "math_trace — final line vs the real Layer-3 function (unary)"
for spec in "tan 1" "sec 1" "csc 1" "cot 1" "sinh 1" "cosh 1" "tanh 1" \
            "asin 0.5" "acos 0.5" "asinh 2" "atanh 0.5" "tan 0.3" "sinh 2"; do
  set -- $spec
  check_str "math_trace $1 $2" "$($1 "$2")" "$(final_of "$(math_trace "$1" "$2")")"
done

section "math_trace — final line vs the real function (binary)"
for spec in "pow 2 10" "pow 3 4" "log_base 10 100" "log_base 2 8"; do
  set -- $spec
  check_str "math_trace $1 $2 $3" "$($1 "$2" "$3")" "$(final_of "$(math_trace "$1" "$2" "$3")")"
done

# ── a primitive piece shown is the honest bc value ---------------------------
section "math_trace — the displayed pieces are real bc sub-expressions"
check_str "tan shows sin(1)"   "yes" "$(math_trace tan 1   | grep -q "$(echo 's(1)' | bc -l)" && echo yes)"
check_str "sinh shows e(1)"    "yes" "$(math_trace sinh 1  | grep -q "$(echo 'e(1)' | bc -l)" && echo yes)"
check_str "pow shows l(2)"     "yes" "$(math_trace pow 2 10 | grep -q "$(echo 'l(2)' | bc -l)" && echo yes)"

# ── error handling -----------------------------------------------------------
section "math_trace — unknown name is rejected"
check_str "unknown fn exit 2" "2" "$(math_trace bogus 1 >/dev/null 2>&1; echo $?)"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
