#!/bin/bash
# Tests for circuit-trace.sh — the Layer-1 viewer (add_trace / sub_trace / alu_trace).
#
# The viewer's whole promise is that it CANNOT lie: it re-runs the same `full_adder`
# the real adder uses. So every test pins the trace's reported result/flags against an
# independent computation by the real Layer-1 functions (word_add, word_sub, alu4/alu8)
# across a sweep of inputs. A standalone (non-core) suite; sources Layer 1 directly.

source "$(dirname "${BASH_SOURCE[0]}")/../circuit-trace.sh"   # pulls in boolean-funcs-new.sh

PASS=0; FAIL=0
section () { printf '\n── %s\n' "$1"; }
check_str () {
  local desc="$1" exp="$2" got="$3"
  if [ "$got" = "$exp" ]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); printf 'FAIL  %-50s want=[%s] got=[%s]\n' "$desc" "$exp" "$got"; fi
}

SAMPLE="0 1 3 6 7 8 11 15"             # a representative 4-bit sweep (cheap add/sub traces)
ASAMPLE="0 1 8 15"                      # a smaller sweep for the pricier ALU dashboard

# ── bits_show -----------------------------------------------------------------
section "bits_show — value annotation"
check_str "bits_show 1 0 1 0"  "1 0 1 0  (=5)"   "$(bits_show "1 0 1 0")"
check_str "bits_show 0 0 0 0"  "0 0 0 0  (=0)"   "$(bits_show "0 0 0 0")"
check_str "bits_show 1 1 1 1"  "1 1 1 1  (=15)"  "$(bits_show "1 1 1 1")"

# ── add_trace result must equal word_add (sum bits + carry-out) ---------------
section "add_trace — _CT_SUM/_CT_COUT vs word_add, over the sweep (+ Cin)"
for a in $SAMPLE; do for b in $SAMPLE; do
  A=$(int_to_bits "$a" 4); B=$(int_to_bits "$b" 4)
  for cin in 0 1; do
    real=$(word_add "$A" "$B" "$cin"); rsum="${real% *}"; rcout="${real##* }"
    add_trace "$A" "$B" "$cin" >/dev/null      # sets _CT_SUM / _CT_COUT
    check_str "add $a+$b+$cin sum"  "$rsum"  "$_CT_SUM"
    check_str "add $a+$b+$cin cout" "$rcout" "$_CT_COUT"
  done
done; done

# ── sub_trace result must equal word_sub --------------------------------------
section "sub_trace — _CT_SUM/_CT_COUT vs word_sub, over the sweep"
for a in $SAMPLE; do for b in $SAMPLE; do
  A=$(int_to_bits "$a" 4); B=$(int_to_bits "$b" 4)
  real=$(word_sub "$A" "$B"); rdiff="${real% *}"; rcout="${real##* }"
  sub_trace "$A" "$B" >/dev/null
  check_str "sub $a-$b diff"   "$rdiff"  "$_CT_SUM"
  check_str "sub $a-$b cout"   "$rcout"  "$_CT_COUT"
done; done

# ── alu_trace dashboard must match alu4 result + every flag -------------------
# Pull the printed "result = …" and "X = b" flag lines back out and compare.
alu_field () { printf '%s\n' "$1" | sed -n "s/^ *$2 = \\([01]\\).*/\\1/p"; }
alu_result () { local l; l=$(printf '%s\n' "$1" | grep 'result ='); l="${l#*result = }"; printf '%s' "${l%%  (=*}"; }

section "alu_trace — result + Z/C/N/V vs alu4, every op over the sweep"
for op in add sub and or xor not slt shl shr; do
  for a in $ASAMPLE; do for b in $ASAMPLE; do
    A=$(int_to_bits "$a" 4); B=$(int_to_bits "$b" 4)
    real=$(alu4 "$op" $A $B); read -ra R <<< "$real"
    want_res="${R[*]:0:4}"; wz="${R[4]}"; wc="${R[5]}"; wn="${R[6]}"; wv="${R[7]}"
    out=$(alu_trace "$op" "$A" "$B")
    check_str "alu4 $op $a,$b result" "$want_res" "$(alu_result "$out")"
    check_str "alu4 $op $a,$b Z"      "$wz"       "$(alu_field "$out" Z)"
    check_str "alu4 $op $a,$b C"      "$wc"       "$(alu_field "$out" C)"
    check_str "alu4 $op $a,$b N"      "$wn"       "$(alu_field "$out" N)"
    check_str "alu4 $op $a,$b V"      "$wv"       "$(alu_field "$out" V)"
  done; done
done

# ── 8-bit: the viewer dispatches to alu8 when width > 4 -----------------------
section "alu_trace — 8-bit dispatch matches alu8"
for pair in "200 100" "255 1" "100 100" "0 0"; do
  set -- $pair; A=$(int_to_bits "$1" 8); B=$(int_to_bits "$2" 8)
  real=$(alu8 add $A $B); read -ra R <<< "$real"
  want_res="${R[*]:0:8}"
  out=$(alu_trace add "$A" "$B")
  check_str "alu8 add $1+$2 result" "$want_res" "$(alu_result "$out")"
  check_str "alu8 add $1+$2 C"      "${R[9]}"   "$(alu_field "$out" C)"
done

# ── format smoke: the table is actually drawn --------------------------------
section "format — the ripple table renders"
out=$(add_trace "1 0 1 0" "0 1 1 0")
check_str "header present" "yes" "$(printf '%s' "$out" | grep -q 'ripple-carry ADD' && echo yes)"
check_str "table rule present" "yes" "$(printf '%s' "$out" | grep -q '────┼' && echo yes)"
check_str "5+6 sum line" "yes" "$(printf '%s' "$out" | grep -q 'Sum = 1 1 0 1  (=11)' && echo yes)"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
