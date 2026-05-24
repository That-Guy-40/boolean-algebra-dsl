#!/bin/bash
# Tests for alt-arithmetic-trace.sh — the Layer-4 viewer (peano/church/mod traces).
#
# The viewer's promise, like the Layer-1 one, is that it CANNOT lie: it drives the
# real Layer-4 primitives. So each test pins the trace's reported result (its last
# line / "result =" line) against an INDEPENDENT computation by the real functions
# (peano_add/…, church_to_int, church_to_bits, mod_add/…, mod_pow) over a sweep.
# A standalone (non-core) suite — the Peano traces ripple through the gates, so slow.

source "$(dirname "${BASH_SOURCE[0]}")/../alt-arithmetic-trace.sh"   # pulls in alt-arithmetic.sh

PASS=0; FAIL=0
section () { printf '\n── %s\n' "$1"; }
check_str () {
  local desc="$1" exp="$2" got="$3"
  if [ "$got" = "$exp" ]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); printf 'FAIL  %-46s want=[%s] got=[%s]\n' "$desc" "$exp" "$got"; fi
}
# the integer after "result = " on the trace's result line
res_int () { printf '%s\n' "$1" | sed -n 's/^ *result = \([0-9-]*\).*/\1/p' | tail -1; }

# ── Peano: trace result vs the real peano_* (read back as a decimal) ----------
section "peano_trace add/sub/mult/expt — vs the real peano_* functions"
pint () { peano_to_int "$1"; }
for a in 0 1 2 3 5; do for b in 0 1 2 4; do
  want=$(pint "$(peano_add "$(int_to_peano "$a")" "$(int_to_peano "$b")")")
  check_str "peano add $a+$b" "$want" "$(res_int "$(peano_trace add "$a" "$b")")"
  if [ "$a" -ge "$b" ]; then
    want=$(pint "$(peano_sub "$(int_to_peano "$a")" "$(int_to_peano "$b")")")
    check_str "peano sub $a-$b" "$want" "$(res_int "$(peano_trace sub "$a" "$b")")"
  fi
  want=$(pint "$(peano_mult "$(int_to_peano "$a")" "$(int_to_peano "$b")")")
  check_str "peano mult $a*$b" "$want" "$(res_int "$(peano_trace mult "$a" "$b")")"
done; done
for pair in "2 3" "2 4" "3 2" "5 1"; do set -- $pair
  want=$(pint "$(peano_expt "$(int_to_peano "$1")" "$(int_to_peano "$2")")")
  check_str "peano expt $1^$2" "$want" "$(res_int "$(peano_trace expt "$1" "$2")")"
done

# ── Church: int mode == church_to_int; bits mode == church_to_bits -----------
section "church_trace int — vs church_to_int"
for n in 0 1 3 5 7; do
  check_str "church int #$n" "$n" "$(res_int "$(church_trace "$n" int)")"
done
section "church_trace bits — vs church_to_bits"
res_bits () { printf '%s\n' "$1" | sed -n 's/^ *result = \([01 ]*\)  (=.*/\1/p' | tail -1; }
for n in 0 1 3 6; do
  want=$(church_to_bits "$n" 8)
  check_str "church bits #$n" "$want" "$(res_bits "$(church_trace "$n" bits 8)")"
done

# ── Modular: trace result vs the real mod_* ----------------------------------
section "mod_trace add/sub/mul — vs mod_add/mod_sub/mod_mul"
for n in 7 12; do for a in 0 3 10; do for b in 0 5 11; do
  check_str "mod add ($a+$b)%$n" "$(mod_add "$a" "$b" "$n")" "$(res_int "$(mod_trace add "$a" "$b" "$n")")"
  check_str "mod sub ($a-$b)%$n" "$(mod_sub "$a" "$b" "$n")" "$(res_int "$(mod_trace sub "$a" "$b" "$n")")"
  check_str "mod mul ($a*$b)%$n" "$(mod_mul "$a" "$b" "$n")" "$(res_int "$(mod_trace mul "$a" "$b" "$n")")"
done; done; done

section "mod_trace_pow — vs mod_pow"
for tri in "2 10 1000" "3 7 13" "5 0 7" "7 13 100" "2 1 5"; do set -- $tri
  check_str "mod pow $1^$2 %$3" "$(mod_pow "$1" "$2" "$3")" "$(res_int "$(mod_trace_pow "$1" "$2" "$3")")"
done

# ── format smoke: the headers and tables render ------------------------------
section "format — traces render their headers"
check_str "peano header"  "yes" "$(peano_trace add 3 2     | grep -q 'Peano ADD  3 + 2'        && echo yes)"
check_str "peano ties inc" "yes" "$(peano_trace add 3 2    | grep -q 'each S is Layer-1 inc'    && echo yes)"
check_str "church header" "yes" "$(church_trace 4          | grep -q 'do f 4 times'            && echo yes)"
check_str "church handshake" "yes" "$(church_trace 4 bits  | grep -q 'function↔gate handshake'  && echo yes)"
check_str "mod clock"     "yes" "$(mod_trace add 10 5 12   | grep -q 'clock(12):'              && echo yes)"
check_str "mod pow table" "yes" "$(mod_trace_pow 2 10 1000 | grep -q 'square-and-multiply'      && echo yes)"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
