#!/bin/bash
# Test suite for boolean-funcs-new.sh.
#
# Three distinct layers are tested here, each with its own value convention:
#
#   Boolean layer  — shell functions that use exit codes (0 = true, 1 = false)
#                    and also echo the strings "true" or "false".
#   Adder layer    — functions that echo space-separated 0/1 bit strings, e.g. "1 0".
#   Numeric layer  — functions that shell out to bc -l and echo decimal strings.
#
# A separate helper handles each convention.

cd "$(dirname "$0")" || exit 1
source ./boolean-funcs-new.sh

PASS=0; FAIL=0

# ── helpers ──────────────────────────────────────────────────────────────────

# check_exit: for functions whose result lives in the exit code.
# The Boolean layer uses the shell convention: 0 = success = TRUE.
# All output is suppressed; only $? is inspected.
check_exit() {
    local desc="$1" exp="$2"; shift 2
    local actual
    "$@" >/dev/null 2>&1; actual=$?
    if [ "$actual" = "$exp" ]; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
        printf 'FAIL  %-62s  exit: want=%s got=%s\n' "$desc" "$exp" "$actual"
    fi
}

# check_str: for functions whose result is an echoed string ("true" / "false",
# or a bit-pair like "0 1"). Simple exact-match comparison.
check_str() {
    local desc="$1" exp="$2" actual="$3"
    if [ "$actual" = "$exp" ]; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
        printf 'FAIL  %-62s  want=%s got=%s\n' "$desc" "$exp" "$actual"
    fi
}

# check_float: for bc-backed numeric functions.
# Shell arithmetic cannot handle floating-point, so the comparison itself is
# also done inside bc. A tolerance guards against the ~1e-17 residuals that
# accumulate through bc's 20-digit precision.
# Default tolerance: 1e-10 (well above bc noise, well below any real error).
check_float() {
    local desc="$1" exp="$2" actual="$3" tol="${4:-0.0000000001}"
    local ok
    ok=$(printf 'define abs(x){if(x<0)return -x;return x;}\nabs(%s-(%s))<=%s\n' \
         "$actual" "$exp" "$tol" | bc -l 2>/dev/null)
    if [ "$ok" = "1" ]; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
        printf 'FAIL  %-62s  want=%s got=%s\n' "$desc" "$exp" "$actual"
    fi
}

# check_domain_err: bc silences stdout when it hits a domain violation
# (e.g. ln(0), sqrt(-1), or exact division by zero).
# We capture the output and assert it is empty.
check_domain_err() {
    local desc="$1" actual="$2"
    if [ -z "$actual" ]; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
        printf 'FAIL  %-62s  expected domain error, got: %s\n' "$desc" "$actual"
    fi
}

section() { printf '\n── %s\n' "$1"; }

# Bit-string helpers for the multi-bit adder/subtractor tests.
# All bit strings are LSB-first, matching the ripple_* function convention.

# dec_to_bits N WIDTH: decimal -> space-separated LSB-first bit string.
dec_to_bits() {
    local n=$1 w=$2 i out=""
    for ((i=0; i<w; i++)); do out+="$(( (n >> i) & 1 )) "; done
    echo "${out% }"
}

# bits_to_dec "b0 b1 ...": LSB-first bit string -> decimal. Treats every field
# as a bit, so passing a full adder output (sum bits + carry-out) yields the
# exact unsigned sum, with the carry-out acting as the most significant bit.
bits_to_dec() {
    local d=0 i=0 b
    for b in $1; do d=$(( d + (b << i) )); i=$(( i + 1 )); done
    echo "$d"
}

# sub_signed OUTPUT WIDTH: interpret a ripple_subN output ("D0..D{W-1} Cout")
# as a signed two's-complement integer. Cout=1 means no borrow (value as-is);
# Cout=0 means borrow, so subtract 2^WIDTH to recover the negative value.
sub_signed() {
    local out="$1" w="$2"
    local cout="${out##* }"          # last field
    local bits="${out% *}"           # everything except the last field
    local mag; mag=$(bits_to_dec "$bits")
    if [ "$cout" = 0 ]; then mag=$(( mag - (1 << w) )); fi
    echo "$mag"
}

# Precompute shared constants once. Many tests need these, and each bc call
# carries process-spawn overhead in a shell loop.
PI=$(pi)
E=$(eml_e)
HALF_PI=$(echo "2*a(1)" | bc -l)   # pi/2, used repeatedly for trig tests

# ── 1. Boolean primitives ─────────────────────────────────────────────────────
section "Boolean primitives"

# true/false are shell functions that simply return 0 or 1 as an exit code.
check_exit "true  exits 0"   0  true
check_exit "false exits 1"   1  false

# is_true and is_false accept multiple synonyms. "0" is in the TRUE set because
# 0 is the shell's exit code for success. All other unrecognised strings are false.
for v in T t True true 0; do
    check_exit "is_true($v)"           0  is_true "$v"
done
for v in 1 F f False false "" foo; do
    check_exit "is_true($v) is false"  1  is_true "$v"
done

for v in F f False false 1; do
    check_exit "is_false($v)"          0  is_false "$v"
done
for v in 0 T t True true "" foo; do
    check_exit "is_false($v) is false" 1  is_false "$v"
done

# ── 2. Gate truth tables ──────────────────────────────────────────────────────
# Every binary gate is tested against its complete 4-row truth table.
# NAND is the primitive from which all other gates are derived; its truth table
# is verified first, then the derived gates are implicitly cross-checked by the
# identity tests in section 3.

section "NAND"
# NAND is FALSE only when both inputs are TRUE — all other combos are TRUE.
check_str "nand T T = false" false "$(nand true true)"
check_str "nand T F = true"  true  "$(nand true false)"
check_str "nand F T = true"  true  "$(nand false true)"
check_str "nand F F = true"  true  "$(nand false false)"

section "NOT"
# NOT is built as nand(A,A) — tying NAND's inputs together leaves only inversion.
check_str "not true  = false" false "$(not true)"
check_str "not false = true"  true  "$(not false)"

section "AND"
# AND = not(nand(A,B)): invert the NAND output.
check_str "and T T = true"  true  "$(and true true)"
check_str "and T F = false" false "$(and true false)"
check_str "and F T = false" false "$(and false true)"
check_str "and F F = false" false "$(and false false)"

section "OR"
# OR = nand(not(A), not(B)): De Morgan applied directly to NAND.
check_str "or T T = true"  true  "$(or true true)"
check_str "or T F = true"  true  "$(or true false)"
check_str "or F T = true"  true  "$(or false true)"
check_str "or F F = false" false "$(or false false)"

section "OR via NAND (or_nand)"
# or_nand is a second, independent implementation of OR built entirely from
# NAND gates: NAND(NAND(A,A), NAND(B,B)). Both implementations must agree.
check_str "or_nand T T = true"  true  "$(or_nand true true)"
check_str "or_nand T F = true"  true  "$(or_nand true false)"
check_str "or_nand F T = true"  true  "$(or_nand false true)"
check_str "or_nand F F = false" false "$(or_nand false false)"

section "NOR"
# NOR is TRUE only when both inputs are FALSE — the dual of AND.
check_str "nor T T = false" false "$(nor true true)"
check_str "nor T F = false" false "$(nor true false)"
check_str "nor F T = false" false "$(nor false true)"
check_str "nor F F = true"  true  "$(nor false false)"

section "XOR (ne)"
# XOR (ne = not-equal) is TRUE when inputs differ.
check_str "ne T T = false" false "$(ne true true)"
check_str "ne T F = true"  true  "$(ne true false)"
check_str "ne F T = true"  true  "$(ne false true)"
check_str "ne F F = false" false "$(ne false false)"

section "XNOR (eq)"
# XNOR (eq = equal) is TRUE when inputs match — the logical biconditional.
check_str "eq T T = true"  true  "$(eq true true)"
check_str "eq T F = false" false "$(eq true false)"
check_str "eq F T = false" false "$(eq false true)"
check_str "eq F F = true"  true  "$(eq false false)"

section "Implication gates"
# if_then (A→B) is FALSE only when A is TRUE and B is FALSE.
check_str "if_then T T = true"  true  "$(if_then true true)"
check_str "if_then T F = false" false "$(if_then true false)"
check_str "if_then F T = true"  true  "$(if_then false true)"
check_str "if_then F F = true"  true  "$(if_then false false)"

# then_if (B→A) is the converse: FALSE only when B is TRUE and A is FALSE.
check_str "then_if T T = true"  true  "$(then_if true true)"
check_str "then_if T F = true"  true  "$(then_if true false)"
check_str "then_if F T = false" false "$(then_if false true)"
check_str "then_if F F = true"  true  "$(then_if false false)"

# if_and_only_if (IFF / XNOR) is TRUE when A and B have the same value.
check_str "iff T T = true"  true  "$(if_and_only_if true true)"
check_str "iff T F = false" false "$(if_and_only_if true false)"
check_str "iff F T = false" false "$(if_and_only_if false true)"
check_str "iff F F = true"  true  "$(if_and_only_if false false)"

# ── 3. Boolean algebraic identities ──────────────────────────────────────────
# These test relationships between gates, not just individual gate outputs.
# A bug in one gate will typically break multiple identities here, making
# root-cause easier to pinpoint.
section "Boolean identities"

# Double negation: applying NOT twice must return the original value.
check_str "not(not true)  = true"  true  "$(not "$(not true)")"
check_str "not(not false) = false" false "$(not "$(not false)")"

# De Morgan's law (AND form): not(A AND B) = (not A) OR (not B).
# Tested across all 4 input combinations.
for A in true false; do for B in true false; do
    lhs=$(not "$(and "$A" "$B")")
    rhs=$(or  "$(not "$A")" "$(not "$B")")
    check_str "De Morgan AND  A=$A B=$B" "$lhs" "$rhs"
done; done

# De Morgan's law (OR form): not(A OR B) = (not A) AND (not B).
for A in true false; do for B in true false; do
    lhs=$(not "$(or "$A" "$B")")
    rhs=$(and "$(not "$A")" "$(not "$B")")
    check_str "De Morgan OR   A=$A B=$B" "$lhs" "$rhs"
done; done

# Idempotence: combining a value with itself under AND or OR leaves it unchanged.
for A in true false; do
    check_str "idempotence and A=$A" "$A" "$(and "$A" "$A")"
    check_str "idempotence or  A=$A" "$A" "$(or  "$A" "$A")"
done

# Absorption: A OR (A AND B) = A. The inner AND can never produce something
# "more true" than A itself, so the outer OR collapses to A.
for A in true false; do for B in true false; do
    check_str "absorption A=$A B=$B" "$A" "$(or "$A" "$(and "$A" "$B")")"
done; done

# XOR properties: A XOR A = false (self-cancelling), A XOR false = A (identity).
for A in true false; do
    check_str "xor self-inverse A=$A"  false "$(ne "$A" "$A")"
    check_str "xor identity     A=$A"  "$A"  "$(ne "$A" false)"
done

# ── 3b. Boolean algebra axioms ────────────────────────────────────────────────
# Together with the identities above (idempotence, absorption, involution, De
# Morgan), these certify that (or=∨, and=∧, not=¬, false=0, true=1) is a genuine
# Boolean algebra — every law verified exhaustively over all input assignments.
section "Boolean algebra axioms: commutativity"
for A in true false; do for B in true false; do
    check_str "A∨B = B∨A  A=$A B=$B" "$(or  "$A" "$B")" "$(or  "$B" "$A")"
    check_str "A∧B = B∧A  A=$A B=$B" "$(and "$A" "$B")" "$(and "$B" "$A")"
done; done

section "Boolean algebra axioms: associativity"
for A in true false; do for B in true false; do for C in true false; do
    check_str "(A∨B)∨C = A∨(B∨C)  $A$B$C" \
        "$(or  "$(or  "$A" "$B")" "$C")" "$(or  "$A" "$(or  "$B" "$C")")"
    check_str "(A∧B)∧C = A∧(B∧C)  $A$B$C" \
        "$(and "$(and "$A" "$B")" "$C")" "$(and "$A" "$(and "$B" "$C")")"
done; done; done

section "Boolean algebra axioms: distributivity"
for A in true false; do for B in true false; do for C in true false; do
    check_str "A∧(B∨C) = (A∧B)∨(A∧C)  $A$B$C" \
        "$(and "$A" "$(or "$B" "$C")")" "$(or  "$(and "$A" "$B")" "$(and "$A" "$C")")"
    check_str "A∨(B∧C) = (A∨B)∧(A∨C)  $A$B$C" \
        "$(or  "$A" "$(and "$B" "$C")")" "$(and "$(or  "$A" "$B")" "$(or  "$A" "$C")")"
done; done; done

section "Boolean algebra axioms: identity, complement, annihilator"
for A in true false; do
    # identity:    A∨0 = A,  A∧1 = A
    check_str "A∨0 = A  A=$A" "$A" "$(or  "$A" false)"
    check_str "A∧1 = A  A=$A" "$A" "$(and "$A" true)"
    # complement:  A∨¬A = 1,  A∧¬A = 0
    check_str "A∨¬A = 1  A=$A" true  "$(or  "$A" "$(not "$A")")"
    check_str "A∧¬A = 0  A=$A" false "$(and "$A" "$(not "$A")")"
    # annihilator: A∨1 = 1,  A∧0 = 0
    check_str "A∨1 = 1  A=$A" true  "$(or  "$A" true)"
    check_str "A∧0 = 0  A=$A" false "$(and "$A" false)"
done

# ── 4. Adders ─────────────────────────────────────────────────────────────────
section "half_adder (true/false string inputs)"
# A half adder adds two single bits with no carry-in.
# Output is "sum carry" as 0/1 digits; 1+1 = 0 with carry 1 (binary overflow).
check_str "false+false = 0 0" "0 0" "$(half_adder false false)"
check_str "false+true  = 1 0" "1 0" "$(half_adder false true)"
check_str "true+false  = 1 0" "1 0" "$(half_adder true false)"
check_str "true+true   = 0 1" "0 1" "$(half_adder true true)"

section "half_adder (0/1 bit inputs)"
# The fix: half_adder now uses a case statement (same as full_adder) so that
# the bit "0" maps to false and "1" maps to true, rather than the shell
# exit-code convention where is_true("0") = true.
# Without the fix, half_adder 0 0 → "0 1" and half_adder 1 1 → "0 0".
check_str "0+0 = 0 0" "0 0" "$(half_adder 0 0)"
check_str "0+1 = 1 0" "1 0" "$(half_adder 0 1)"
check_str "1+0 = 1 0" "1 0" "$(half_adder 1 0)"
check_str "1+1 = 0 1" "0 1" "$(half_adder 1 1)"

section "half_adder (mixed bit/string inputs)"
# The case statement also handles T/F abbreviations and mixed 0/1 + true/false.
check_str "0+true  = 1 0" "1 0" "$(half_adder 0 true)"
check_str "1+false = 1 0" "1 0" "$(half_adder 1 false)"
check_str "T+F     = 1 0" "1 0" "$(half_adder T F)"
check_str "0+T     = 1 0" "1 0" "$(half_adder 0 T)"

section "full_adder (all 8 combinations)"
# A full adder adds two bits plus a carry-in from a previous stage.
# Tests all 2³ = 8 input combinations. The carry-out propagates to the next stage
# in a ripple-carry adder chain.
check_str "0 0 0 = 0 0" "0 0" "$(full_adder 0 0 0)"
check_str "0 0 1 = 1 0" "1 0" "$(full_adder 0 0 1)"
check_str "0 1 0 = 1 0" "1 0" "$(full_adder 0 1 0)"
check_str "0 1 1 = 0 1" "0 1" "$(full_adder 0 1 1)"
check_str "1 0 0 = 1 0" "1 0" "$(full_adder 1 0 0)"
check_str "1 0 1 = 0 1" "0 1" "$(full_adder 1 0 1)"
check_str "1 1 0 = 0 1" "0 1" "$(full_adder 1 1 0)"
check_str "1 1 1 = 1 1" "1 1" "$(full_adder 1 1 1)"

section "full_adder accepts true/false strings"
# full_adder contains a conversion layer that normalises "true"/"false" strings
# to 0/1 bits before processing. Verify the conversion does not corrupt results.
check_str "true false false = 1 0" "1 0" "$(full_adder true false false)"
check_str "true true  false = 0 1" "0 1" "$(full_adder true true false)"
check_str "true true  true  = 1 1" "1 1" "$(full_adder true true true)"

# ── 4b. Multi-bit ripple-carry adders ─────────────────────────────────────────
# ripple_add4 chains four full_adders; ripple_add8 chains two ripple_add4 units.
# Decoding the full output (sum bits + carry-out) as one LSB-first number gives
# the exact unsigned sum, so each test compares against plain shell A+B.

section "ripple_add4"
# Exact-output checks against the documented bit patterns (LSB first).
check_str "3+5  = 0 0 0 1 0"  "0 0 0 1 0"  "$(ripple_add4 1 1 0 0  1 0 1 0)"
check_str "7+7  = 0 1 1 1 0"  "0 1 1 1 0"  "$(ripple_add4 1 1 1 0  1 1 1 0)"
check_str "15+1 = 0 0 0 0 1"  "0 0 0 0 1"  "$(ripple_add4 1 1 1 1  1 0 0 0)"  # 4-bit overflow
check_str "0+0  = 0 0 0 0 0"  "0 0 0 0 0"  "$(ripple_add4 0 0 0 0  0 0 0 0)"
# Decoded-sum checks across the full 0..15 input range (a + b for all pairs).
for a in 0 1 5 8 14 15; do for b in 0 1 7 9 15; do
    out=$(ripple_add4 $(dec_to_bits "$a" 4) $(dec_to_bits "$b" 4))
    check_str "ripple_add4 $a+$b = $((a+b))" "$((a+b))" "$(bits_to_dec "$out")"
done; done
# Carry-in is honoured: 3 + 5 + 1 = 9.
check_str "ripple_add4 3+5+Cin1 = 9" "9" \
    "$(bits_to_dec "$(ripple_add4 1 1 0 0  1 0 1 0  1)")"

section "ripple_add8 (two chained ripple_add4 units)"
# The whole point of the 8-bit adder: the carry-out of the low nibble must feed
# the carry-in of the high nibble. 255+1 and 200+100 both cross that boundary.
check_str "ripple_add8 3+5   = 8"   "8"   "$(bits_to_dec "$(ripple_add8 $(dec_to_bits 3 8)   $(dec_to_bits 5 8))")"
check_str "ripple_add8 15+1  = 16"  "16"  "$(bits_to_dec "$(ripple_add8 $(dec_to_bits 15 8)  $(dec_to_bits 1 8))")"   # low-nibble carry crosses
check_str "ripple_add8 200+100=300" "300" "$(bits_to_dec "$(ripple_add8 $(dec_to_bits 200 8) $(dec_to_bits 100 8))")"
check_str "ripple_add8 255+1  = 256" "256" "$(bits_to_dec "$(ripple_add8 $(dec_to_bits 255 8) $(dec_to_bits 1 8))")"   # 8-bit overflow
check_str "ripple_add8 255+255=510" "510" "$(bits_to_dec "$(ripple_add8 $(dec_to_bits 255 8) $(dec_to_bits 255 8))")"
check_str "ripple_add8 0+0    = 0"   "0"   "$(bits_to_dec "$(ripple_add8 $(dec_to_bits 0 8)   $(dec_to_bits 0 8))")"
# Carry-in honoured: 100 + 100 + 1 = 201.
check_str "ripple_add8 100+100+Cin1 = 201" "201" \
    "$(bits_to_dec "$(ripple_add8 $(dec_to_bits 100 8) $(dec_to_bits 100 8) 1)")"

# ── 4c. Subtractors (two's complement) ────────────────────────────────────────
# A - B is computed as A + (~B) + 1: flip every B bit and force carry-in = 1.
# The trailing carry-out is the borrow flag: 1 = no borrow (A>=B), 0 = borrow.

section "flip_bit"
check_str "flip 0 = 1"     "1"  "$(flip_bit 0)"
check_str "flip 1 = 0"     "0"  "$(flip_bit 1)"
check_str "flip true = 0"  "0"  "$(flip_bit true)"
check_str "flip false = 1" "1"  "$(flip_bit false)"
check_str "flip T = 0"     "0"  "$(flip_bit T)"

section "ripple_sub4 (signed result via two's complement)"
# Positive results (A>=B): carry-out = 1 (no borrow).
check_str "sub4 5-3  =  2" "2"  "$(sub_signed "$(ripple_sub4 $(dec_to_bits 5 4)  $(dec_to_bits 3 4))" 4)"
check_str "sub4 15-0 = 15" "15" "$(sub_signed "$(ripple_sub4 $(dec_to_bits 15 4) $(dec_to_bits 0 4))" 4)"
check_str "sub4 8-8  =  0" "0"  "$(sub_signed "$(ripple_sub4 $(dec_to_bits 8 4)  $(dec_to_bits 8 4))" 4)"
check_str "sub4 10-7 =  3" "3"  "$(sub_signed "$(ripple_sub4 $(dec_to_bits 10 4) $(dec_to_bits 7 4))" 4)"
# Negative results (A<B): carry-out = 0 (borrow), result is two's-complement.
check_str "sub4 3-5  = -2" "-2"  "$(sub_signed "$(ripple_sub4 $(dec_to_bits 3 4)  $(dec_to_bits 5 4))" 4)"
check_str "sub4 0-15 =-15" "-15" "$(sub_signed "$(ripple_sub4 $(dec_to_bits 0 4)  $(dec_to_bits 15 4))" 4)"
check_str "sub4 7-10 = -3" "-3"  "$(sub_signed "$(ripple_sub4 $(dec_to_bits 7 4)  $(dec_to_bits 10 4))" 4)"
check_str "sub4 0-1  = -1" "-1"  "$(sub_signed "$(ripple_sub4 $(dec_to_bits 0 4)  $(dec_to_bits 1 4))" 4)"
# Borrow flag = carry-out (5th field): 1 when A>=B (no borrow), 0 when A<B.
check_str "sub4 5-3 carry-out = 1 (no borrow)" "1" "$(ripple_sub4 $(dec_to_bits 5 4) $(dec_to_bits 3 4) | cut -d' ' -f5)"
check_str "sub4 3-5 carry-out = 0 (borrow)"    "0" "$(ripple_sub4 $(dec_to_bits 3 4) $(dec_to_bits 5 4) | cut -d' ' -f5)"

section "ripple_sub8 (signed result via two's complement)"
check_str "sub8 100-50 =  50"  "50"   "$(sub_signed "$(ripple_sub8 $(dec_to_bits 100 8) $(dec_to_bits 50 8))" 8)"
check_str "sub8 50-100 = -50"  "-50"  "$(sub_signed "$(ripple_sub8 $(dec_to_bits 50 8)  $(dec_to_bits 100 8))" 8)"
check_str "sub8 255-255 =  0"  "0"    "$(sub_signed "$(ripple_sub8 $(dec_to_bits 255 8) $(dec_to_bits 255 8))" 8)"
check_str "sub8 200-1  = 199"  "199"  "$(sub_signed "$(ripple_sub8 $(dec_to_bits 200 8) $(dec_to_bits 1 8))" 8)"
check_str "sub8 0-200  =-200"  "-200" "$(sub_signed "$(ripple_sub8 $(dec_to_bits 0 8)   $(dec_to_bits 200 8))" 8)"
check_str "sub8 128-128 =  0"  "0"    "$(sub_signed "$(ripple_sub8 $(dec_to_bits 128 8) $(dec_to_bits 128 8))" 8)"

# ── 4d. Magnitude comparators ─────────────────────────────────────────────────
# bits_eq:  A == B  iff XNOR of every bit pair (all ANDed together).
# bits_gt:  A >  B  via cascaded priority logic from the MSB down.
# compare4/compare8: positional wrappers echoing lt/eq/gt.

# expected_cmp A B: reference lt/eq/gt using shell integer comparison.
expected_cmp() {
    if   [ "$1" -lt "$2" ]; then echo lt
    elif [ "$1" -gt "$2" ]; then echo gt
    else echo eq; fi
}

section "bit_to_bool"
check_str "bit_to_bool 0     = false" false "$(bit_to_bool 0)"
check_str "bit_to_bool 1     = true"  true  "$(bit_to_bool 1)"
check_str "bit_to_bool true  = true"  true  "$(bit_to_bool true)"
check_str "bit_to_bool false = false" false "$(bit_to_bool false)"
check_str "bit_to_bool T     = true"  true  "$(bit_to_bool T)"
check_str "bit_to_bool F     = false" false "$(bit_to_bool F)"

section "bits_eq / bits_gt predicates (exit codes)"
# Exit-code convention: 0 = true. These compose with `if`.
check_exit "bits_eq 5==5 -> true"  0 bits_eq "$(dec_to_bits 5 4)" "$(dec_to_bits 5 4)"
check_exit "bits_eq 5==3 -> false" 1 bits_eq "$(dec_to_bits 5 4)" "$(dec_to_bits 3 4)"
check_exit "bits_eq 0==0 -> true"  0 bits_eq "$(dec_to_bits 0 4)" "$(dec_to_bits 0 4)"
check_exit "bits_gt 5>3  -> true"  0 bits_gt "$(dec_to_bits 5 4)" "$(dec_to_bits 3 4)"
check_exit "bits_gt 3>5  -> false" 1 bits_gt "$(dec_to_bits 3 4)" "$(dec_to_bits 5 4)"
check_exit "bits_gt 5>5  -> false" 1 bits_gt "$(dec_to_bits 5 4)" "$(dec_to_bits 5 4)"
# Echoed-string convention (true/false), matching the Boolean gates.
check_str "bits_eq echoes true"  true  "$(bits_eq "$(dec_to_bits 5 4)" "$(dec_to_bits 5 4)")"
check_str "bits_gt echoes false" false "$(bits_gt "$(dec_to_bits 3 4)" "$(dec_to_bits 5 4)")"
# Less-than is bits_gt with operands swapped: 3 < 5  <=>  bits_gt(5,3).
check_exit "3<5 via bits_gt(5,3) -> true" 0 bits_gt "$(dec_to_bits 5 4)" "$(dec_to_bits 3 4)"

section "compare4 (lt/eq/gt over a 0..15 grid sample)"
# Every ordered pair from a representative sample must agree with shell integer
# comparison. Catches any sign/cascade slip.
for a in 0 1 5 7 8 9 14 15; do for b in 0 1 5 7 8 9 14 15; do
    check_str "compare4 $a vs $b" "$(expected_cmp "$a" "$b")" \
        "$(compare4 $(dec_to_bits "$a" 4) $(dec_to_bits "$b" 4))"
done; done

section "compare4 cascaded-priority edge cases (MSB dominates)"
# 8 = 1000, 7 = 0111: A>B is decided at the most significant bit even though B
# has more low-order 1s. This is the case a naive bit count gets wrong.
check_str "compare4 8 vs 7 = gt"  gt "$(compare4 $(dec_to_bits 8 4)  $(dec_to_bits 7 4))"
check_str "compare4 7 vs 8 = lt"  lt "$(compare4 $(dec_to_bits 7 4)  $(dec_to_bits 8 4))"
check_str "compare4 9 vs 10 = lt" lt "$(compare4 $(dec_to_bits 9 4)  $(dec_to_bits 10 4))"
check_str "compare4 15 vs 0 = gt" gt "$(compare4 $(dec_to_bits 15 4) $(dec_to_bits 0 4))"

section "compare8 (lt/eq/gt)"
for a in 0 100 127 128 200 255; do for b in 0 100 127 128 200 255; do
    check_str "compare8 $a vs $b" "$(expected_cmp "$a" "$b")" \
        "$(compare8 $(dec_to_bits "$a" 8) $(dec_to_bits "$b" 8))"
done; done

section "int_to_bits (integer -> LSB-first bit string)"
# Minimal width, then round-trip via the test helper's bits_to_dec.
check_str "int_to_bits 0     = 0"     "0"      "$(int_to_bits 0)"
check_str "int_to_bits 1     = 1"     "1"      "$(int_to_bits 1)"
check_str "int_to_bits 5     = 1 0 1" "1 0 1"  "$(int_to_bits 5)"
check_str "int_to_bits 5 6 padded"    "1 0 1 0 0 0" "$(int_to_bits 5 6)"
for n in 0 1 7 8 100 255 2047; do
    check_str "int_to_bits($n) round-trips" "$n" "$(bits_to_dec "$(int_to_bits "$n")")"
done

# ── 4e. Word-level Boolean operations ─────────────────────────────────────────
# Bitwise ops lift the single-bit gates to whole bit-vectors; the reductions
# fold a word down to one Boolean.
section "word_not / word_and / word_or / word_xor (bitwise)"
check_str "word_not 1011"            "0 1 0 0" "$(word_not "1 0 1 1")"
check_str "word_and 1100 & 1010"     "1 0 0 0" "$(word_and "1 1 0 0" "1 0 1 0")"
check_str "word_or  1100 | 1010"     "1 1 1 0" "$(word_or  "1 1 0 0" "1 0 1 0")"
check_str "word_xor 1100 ^ 1010"     "0 1 1 0" "$(word_xor "1 1 0 0" "1 0 1 0")"
# A xor A = 0; A or (not A) = all ones; both decoded for clarity.
check_str "A xor A = 0"  "0" "$(bits_to_dec "$(word_xor "1 0 1 1" "1 0 1 1")")"
check_str "A or ¬A = 15" "15" "$(bits_to_dec "$(word_or "1 0 1 1" "$(word_not "1 0 1 1")")")"
# De Morgan at the word level: ¬(A∧B) = ¬A ∨ ¬B, across two 4-bit words.
WA="1 1 0 0"; WB="1 0 1 0"
check_str "word De Morgan ¬(A∧B)=¬A∨¬B" \
    "$(word_not "$(word_and "$WA" "$WB")")" \
    "$(word_or  "$(word_not "$WA")" "$(word_not "$WB")")"

section "and_all / or_all / xor_all / is_zero (reductions)"
check_exit "and_all 1111 = true"   0 and_all "1 1 1 1"
check_exit "and_all 1101 = false"  1 and_all "1 1 0 1"
check_exit "or_all  0010 = true"   0 or_all  "0 0 1 0"
check_exit "or_all  0000 = false"  1 or_all  "0 0 0 0"
check_exit "xor_all 1101 = true"   0 xor_all "1 1 0 1"   # three 1s -> odd parity
check_exit "xor_all 1100 = false"  1 xor_all "1 1 0 0"   # two 1s   -> even parity
check_exit "is_zero 0000 = true"   0 is_zero "0 0 0 0"
check_exit "is_zero 0100 = false"  1 is_zero "0 1 0 0"
# is_zero must be the exact complement of or_all across several words.
for w in "0 0 0 0" "1 0 0 0" "0 0 0 1" "1 1 1 1"; do
    if or_all "$w" >/dev/null; then exp_zero=false; else exp_zero=true; fi
    check_str "is_zero = ¬or_all  [$w]" "$exp_zero" "$(is_zero "$w")"
done

# ── 4e-ii. Word helpers and predicates ────────────────────────────────────────
section "inc / dec / negate (width-preserving two's complement)"
# Results wrap mod 16; checked by decoding with bits_to_int.
for n in 0 1 3 7 14 15; do
    check_str "inc $n"    "$(( (n + 1)  % 16 ))" "$(bits_to_int "$(inc    "$(dec_to_bits $n 4)")")"
    check_str "dec $n"    "$(( (n + 15) % 16 ))" "$(bits_to_int "$(dec    "$(dec_to_bits $n 4)")")"
    check_str "negate $n" "$(( (16 - n) % 16 ))" "$(bits_to_int "$(negate "$(dec_to_bits $n 4)")")"
done
# Structural relationships.
check_str "dec(inc 5) = 5"        "5" "$(bits_to_int "$(dec "$(inc "$(dec_to_bits 5 4)")")")"
check_str "negate(negate 6) = 6"  "6" "$(bits_to_int "$(negate "$(negate "$(dec_to_bits 6 4)")")")"
# a + (-a) = 0: the low 4 sum bits of ripple_add4(a, negate a) are all zero.
for a in 1 5 9 13; do
    sumbits=$(ripple_add4 $(dec_to_bits $a 4) $(negate "$(dec_to_bits $a 4)"))
    check_str "a + (-a) = 0  [a=$a]" "0" "$(bits_to_int "${sumbits% *}")"   # drop carry field
done

section "predicates: is_one / is_even / is_odd / is_negative"
check_exit "is_one(1) true"        0 is_one      "$(dec_to_bits 1 4)"
check_exit "is_one(0) false"       1 is_one      "$(dec_to_bits 0 4)"
check_exit "is_one(3) false"       1 is_one      "$(dec_to_bits 3 4)"
check_exit "is_even(4) true"       0 is_even     "$(dec_to_bits 4 4)"
check_exit "is_even(3) false"      1 is_even     "$(dec_to_bits 3 4)"
check_exit "is_odd(3) true"        0 is_odd      "$(dec_to_bits 3 4)"
check_exit "is_odd(4) false"       1 is_odd      "$(dec_to_bits 4 4)"
check_exit "is_negative(8) true"   0 is_negative "$(dec_to_bits 8 4)"   # MSB set (8 = -8 signed)
check_exit "is_negative(7) false"  1 is_negative "$(dec_to_bits 7 4)"
# is_odd is exactly ¬is_even, and is_even ⟺ lsb = 0, across all 4-bit values.
for n in $(seq 0 15); do
    w=$(dec_to_bits $n 4)
    if is_even "$w" >/dev/null; then ie=1; else ie=0; fi
    if is_odd  "$w" >/dev/null; then io=1; else io=0; fi
    check_str "is_even xor is_odd = 1  [$n]" "1" "$(( ie + io ))"
    check_str "is_even ⟺ lsb=0  [$n]" "$([ "$(lsb "$w")" = 0 ] && echo 1 || echo 0)" "$ie"
done

section "parity / popcount / lsb / msb / bits_to_int"
check_str "parity 1110 (3 ones, odd)"  "1" "$(parity "1 1 1 0")"
check_str "parity 1100 (2 ones, even)" "0" "$(parity "1 1 0 0")"
check_str "parity 0000"                "0" "$(parity "0 0 0 0")"
check_str "popcount 1011"              "3" "$(popcount "1 0 1 1")"
check_str "popcount 0000"              "0" "$(popcount "0 0 0 0")"
check_str "popcount 1111"              "4" "$(popcount "1 1 1 1")"
check_str "lsb of 9 (1001)"            "1" "$(lsb "$(dec_to_bits 9 4)")"
check_str "msb of 9 (1001)"            "1" "$(msb "$(dec_to_bits 9 4)")"
check_str "lsb of 6 (0110)"            "0" "$(lsb "$(dec_to_bits 6 4)")"
check_str "msb of 6 (0110)"            "0" "$(msb "$(dec_to_bits 6 4)")"
# parity = popcount mod 2; bits_to_int = the test helper bits_to_dec; round-trips.
for n in $(seq 0 15); do
    w=$(dec_to_bits $n 4)
    check_str "parity = popcount%2  [$n]" "$(( $(popcount "$w") % 2 ))" "$(parity "$w")"
    check_str "bits_to_int = n      [$n]" "$n" "$(bits_to_int "$w")"
done
check_str "bits_to_int round-trips int_to_bits(100)" "100" "$(bits_to_int "$(int_to_bits 100)")"

# ── 4f. Shifts and the ALU ────────────────────────────────────────────────────
section "shl / shr (logical shifts, width-preserving)"
check_str "shl 3  = 6"   "0 1 1 0" "$(shl "$(dec_to_bits 3 4)")"
check_str "shr 3  = 1"   "1 0 0 0" "$(shr "$(dec_to_bits 3 4)")"
check_str "shl 12 = 8"   "0 0 0 1" "$(shl "$(dec_to_bits 12 4)")"   # top bit shifted out
check_str "shr 1  = 0"   "0 0 0 0" "$(shr "$(dec_to_bits 1 4)")"    # bottom bit shifted out
check_str "shl 1 by 2"   "0 0 1 0" "$(shl "$(dec_to_bits 1 4)" 2)"  # 1 << 2 = 4
check_str "decode 5<<1"  "10"      "$(bits_to_dec "$(shl "$(dec_to_bits 5 4)")")"

section "alu4 — result + flags (R0 R1 R2 R3 Z C N V)"
# add 3+5=8 overflows signed 4-bit (range -8..7): V=1, N=1, no unsigned carry.
check_str "add 3+5  -> 8 (V,N)"  "0 0 0 1 0 0 1 1" "$(alu4 add $(dec_to_bits 3 4) $(dec_to_bits 5 4))"
check_str "add 2+3  -> 5"        "1 0 1 0 0 0 0 0" "$(alu4 add $(dec_to_bits 2 4) $(dec_to_bits 3 4))"
check_str "sub 5-3  -> 2 (C=1)"  "0 1 0 0 0 1 0 0" "$(alu4 sub $(dec_to_bits 5 4) $(dec_to_bits 3 4))"
check_str "sub 3-5  -> -2 (N=1)" "0 1 1 1 0 0 1 0" "$(alu4 sub $(dec_to_bits 3 4) $(dec_to_bits 5 4))"
check_str "and 3&5  -> 1"        "1 0 0 0 0 0 0 0" "$(alu4 and $(dec_to_bits 3 4) $(dec_to_bits 5 4))"
check_str "or  3|5  -> 7"        "1 1 1 0 0 0 0 0" "$(alu4 or  $(dec_to_bits 3 4) $(dec_to_bits 5 4))"
check_str "xor 3^5  -> 6"        "0 1 1 0 0 0 0 0" "$(alu4 xor $(dec_to_bits 3 4) $(dec_to_bits 5 4))"
check_str "not 3    -> 12 (N=1)" "0 0 1 1 0 0 1 0" "$(alu4 not $(dec_to_bits 3 4) $(dec_to_bits 0 4))"
check_str "slt 3<5  -> 1"        "1 0 0 0 0 0 0 0" "$(alu4 slt $(dec_to_bits 3 4) $(dec_to_bits 5 4))"
check_str "slt 5<3  -> 0 (Z=1)"  "0 0 0 0 1 0 0 0" "$(alu4 slt $(dec_to_bits 5 4) $(dec_to_bits 3 4))"
check_str "shl 3    -> 6"        "0 1 1 0 0 0 0 0" "$(alu4 shl $(dec_to_bits 3 4) $(dec_to_bits 0 4))"
check_str "shr 3    -> 1 (C=1)"  "1 0 0 0 0 1 0 0" "$(alu4 shr $(dec_to_bits 3 4) $(dec_to_bits 0 4))"

section "alu4 — flag spot checks"
# Zero flag: A XOR A = 0 sets Z.
check_str "xor 6^6 -> 0 (Z=1)"   "0 0 0 0 1 0 0 0" "$(alu4 xor $(dec_to_bits 6 4) $(dec_to_bits 6 4))"
# 8+8 = 16 wraps to 0: unsigned carry C=1, signed overflow V=1, zero Z=1.
check_str "add 8+8 wraps (Z,C,V)" "0 0 0 0 1 1 0 1" "$(alu4 add $(dec_to_bits 8 4) $(dec_to_bits 8 4))"
# Unknown opcode is rejected.
check_exit "alu4 bad op -> exit 2" 2 alu4 frobnicate 0 0 0 0 0 0 0 0

# ── 5. EML operator ───────────────────────────────────────────────────────────
# eml(x,y) = exp(x) - ln(y). The EML operator is "functionally complete" in the
# sense that exp, ln, and all arithmetic can be expressed as trees of eml nodes
# over the constant 1. The tests below verify both the base constructions and the
# derived arithmetic, and check that exp and ln are true mutual inverses.
section "EML base"
T=0.0000000001   # tolerance for all EML and math-library float comparisons

# Key eml-tree identities derived from the base definition:
#   eml(1,1) = exp(1) - ln(1) = e - 0 = e
#   eml_zero uses a 3-node tree: eml(1, eml(e, 1)) = e - ln(exp(e)) = 0
check_float "eml(1,1) = e"          "$E"  "$(eml 1 1)"                            "$T"
check_float "eml_e    = e"          "$E"  "$(eml_e)"                              "$T"
check_float "eml_exp(0) = 1"        1     "$(eml_exp 0)"                          "$T"
check_float "eml_exp(1) = e"        "$E"  "$(eml_exp 1)"                          "$T"
check_float "eml_exp(-1) = 1/e"     "$(echo "1/$E" | bc -l)"  "$(eml_exp -1)"    "$T"
check_float "eml_ln(1)  = 0"        0     "$(eml_ln 1)"                           "$T"
check_float "eml_ln(e)  = 1"        1     "$(eml_ln "$E")"                        "$T"
check_float "eml_ln(e^2) = 2"       2     "$(eml_ln "$(echo "$E*$E" | bc -l)")"  "$T"
check_float "eml_zero   = 0"        0     "$(eml_zero)"                           "$T"

section "EML inverses"
# exp and ln are mutual inverses: composing them in either order returns the input.
check_float "ln(exp(2))  = 2"  2  "$(eml_ln "$(eml_exp 2)")"   "$T"
check_float "ln(exp(0.5))= .5" .5 "$(eml_ln "$(eml_exp .5)")"  "$T"
check_float "exp(ln(7))  = 7"  7  "$(eml_exp "$(eml_ln 7)")"   "$T"

section "EML arithmetic"
# eml_sub(x,y) = eml(ln x, exp y) = x - y. Requires x > 0 for ln to be defined.
check_float "sub(7,3) = 4"      4    "$(eml_sub 7 3)"    "$T"
check_float "sub(5,5) = 0"      0    "$(eml_sub 5 5)"    "$T"
check_float "sub(3,0.5) = 2.5"  2.5  "$(eml_sub 3 .5)"  "$T"

# eml_neg uses bc's plain subtraction for 0 - z, since the pure eml form would
# require ln(0) = -∞ which bc cannot represent.
check_float "neg(3)   = -3"    -3   "$(eml_neg 3)"                    "$T"
check_float "neg(0)   =  0"     0   "$(eml_neg 0)"                    "$T"
check_float "neg(-5)  =  5"     5   "$(eml_neg -5)"                   "$T"
check_float "neg(neg(4)) = 4"   4   "$(eml_neg "$(eml_neg 4)")"       "$T"

# eml_add(x,y) = eml(ln x, exp(-y)) = x - (-y) = x + y. Requires x > 0.
check_float "add(3,5) = 8"     8    "$(eml_add 3 5)"    "$T"
check_float "add(1,0) = 1"     1    "$(eml_add 1 0)"    "$T"
check_float "add(2,.5) = 2.5"  2.5  "$(eml_add 2 .5)"  "$T"

# eml_mul chains through eml_add: exp(ln(x) + ln(y)).
# Requires x > 1 so that ln(x) > 0, satisfying eml_add's domain constraint.
check_float "mul(3,4) = 12"   12   "$(eml_mul 3 4)"   "$T"
check_float "mul(2,2) =  4"    4   "$(eml_mul 2 2)"   "$T"
check_float "mul(5,1) =  5"    5   "$(eml_mul 5 1)"   "$T"

# eml_div(z) = exp(-ln z) = 1/z. No chain dependency on eml_add; works for any z > 0.
check_float "div(1)   = 1"     1   "$(eml_div 1)"             "$T"
check_float "div(2)   = .5"   .5   "$(eml_div 2)"             "$T"
check_float "div(4)   = .25"  .25  "$(eml_div 4)"             "$T"
check_float "div(e)   = 1/e"  "$(echo "1/$E" | bc -l)"  "$(eml_div "$E")"  "$T"

section "EML mul/div inverses"
# x * (1/x) = 1 is a round-trip through eml_mul and eml_div.
check_float "x * (1/x) = 1  [x=3]" 1 "$(eml_mul 3 "$(eml_div 3)")" "$T"
check_float "x * (1/x) = 1  [x=7]" 1 "$(eml_mul 7 "$(eml_div 7)")" "$T"

# ── 5b. EML applications (iterative algorithms on the EML layer) ───────────────
# eml_pow_int: integer powers via repeated eml_mul.
# eml_recip:   Newton's reciprocal iteration y <- y*(2 - x*y), no division.
# eml_sin_taylor: Maclaurin series for sin via eml powers + accumulation.

section "eml_pow_int (integer powers via repeated eml_mul)"
check_float "1.5^1 = 1.5"   1.5    "$(eml_pow_int 1.5 1)"  "$T"
check_float "1.5^2 = 2.25"  2.25   "$(eml_pow_int 1.5 2)"  "$T"
check_float "1.5^3 = 3.375" 3.375  "$(eml_pow_int 1.5 3)"  "$T"
check_float "2^5   = 32"    32     "$(eml_pow_int 2 5)"    0.0000001
check_float "3^4   = 81"    81     "$(eml_pow_int 3 4)"    0.0000001

section "eml_recip (Newton 1/x) agrees with eml_div"
# The iterative reciprocal must converge to the same value as the direct eml_div.
check_float "recip(1.5)  = 1/1.5"  "$(eml_div 1.5)"  "$(eml_recip 1.5)"           0.000000001
check_float "recip(1.25) = 1/1.25" "$(eml_div 1.25)" "$(eml_recip 1.25)"          0.000000001
check_float "recip(1.9)  = 1/1.9"  "$(eml_div 1.9)"  "$(eml_recip 1.9 7)"         0.000000001
check_float "recip(4)    = 0.25"   0.25   "$(eml_recip 4 8 0.2)"                   0.000000001
check_float "recip(10)   = 0.1"    0.1    "$(eml_recip 10 9 0.05)"                 0.000000001
check_float "recip(100)  = 0.01"   0.01   "$(eml_recip 100 12 0.005)"             0.0000001

section "eml_sin_taylor agrees with bc sin (1 < x <~ pi/2)"
# Taylor truncation error grows with x and shrinks with more terms; tolerances
# are loosened accordingly but stay far tighter than any structural error.
check_float "sin_taylor(1.2)  ~ sin(1.2)"  "$(echo "s(1.2)" | bc -l)" "$(eml_sin_taylor 1.2)"        0.000001
check_float "sin_taylor(1.5)  ~ sin(1.5)"  "$(echo "s(1.5)" | bc -l)" "$(eml_sin_taylor 1.5)"        0.000001
check_float "sin_taylor(pi/2) ~ 1"         1                          "$(eml_sin_taylor "$HALF_PI")" 0.00001
check_float "sin_taylor(1.4, 8 terms)"     "$(echo "s(1.4)" | bc -l)" "$(eml_sin_taylor 1.4 8)"      0.0000001

section "eml_recip_auto (comparator-seeded reciprocal) = eml_div"
# The seed y0 is chosen automatically by bracketing x with the bit comparator;
# the result must still match the direct reciprocal. Values are spread across
# several power-of-two brackets, including the boundaries (63 vs 64, x near 2).
for x in 1.5 1.99 4 10 63 64 100 1000; do
    check_float "recip_auto($x) = 1/$x" "$(eml_div "$x")" "$(eml_recip_auto "$x")" 0.000000001
done

# ── 6. Math library — constants & roots ───────────────────────────────────────
section "pi, sqrt, pow, log_base"

# pi = 4 * atan(1), the Gregory–Leibniz identity. Tolerance is slightly loosened
# because pi itself has a bc residual at the last digit.
check_float "pi ~ 3.14159"       3.14159265358979 "$(pi)"             0.00000000001

# sqrt wraps bc's native sqrt. sqrt(x)^2 = x is a round-trip check.
check_float "sqrt(0) = 0"        0   "$(sqrt 0)"                      "$T"
check_float "sqrt(1) = 1"        1   "$(sqrt 1)"                      "$T"
check_float "sqrt(4) = 2"        2   "$(sqrt 4)"                      "$T"
check_float "sqrt(9) = 3"        3   "$(sqrt 9)"                      "$T"
check_float "sqrt(2)^2 = 2"      2   "$(echo "$(sqrt 2)^2" | bc -l)"  "$T"

# pow(x,y) = exp(y * ln x). Fractional and negative exponents are supported.
# pow(2,10) uses a looser tolerance because the intermediate ln/exp chain
# accumulates more rounding error than simpler expressions.
check_float "pow(2,0)  = 1"      1    "$(pow 2 0)"     "$T"
check_float "pow(2,1)  = 2"      2    "$(pow 2 1)"     "$T"
check_float "pow(2,10) = 1024"   1024 "$(pow 2 10)"    0.000001
check_float "pow(9,.5) = 3"      3    "$(pow 9 .5)"    "$T"
check_float "pow(e,1)  = e"      "$E" "$(pow "$E" 1)"  "$T"
check_float "pow(10,-1)= 0.1"    0.1  "$(pow 10 -1)"   "$T"

# log_base uses the change-of-base formula: log_b(z) = ln(z) / ln(b).
check_float "log10(1)   = 0"     0   "$(log_base 10 1)"       "$T"
check_float "log10(10)  = 1"     1   "$(log_base 10 10)"      "$T"
check_float "log10(100) = 2"     2   "$(log_base 10 100)"     "$T"
check_float "log2(8)    = 3"     3   "$(log_base 2 8)"        "$T"
check_float "log_e(e)   = 1"     1   "$(log_base "$E" "$E")"  "$T"

# ── 7. Trigonometric ──────────────────────────────────────────────────────────
# All trig functions take arguments in radians. bc's s() and c() are the
# primitives; tan, sec, csc, cot are ratios built from them.
section "sin / cos"

# Key angles: 0, pi/2, pi. sin(pi) has a ~1e-19 bc residual (not exactly 0).
check_float "sin(0)     = 0"     0   "$(sin 0)"             "$T"
check_float "sin(pi/2)  = 1"     1   "$(sin "$HALF_PI")"    "$T"
check_float "sin(pi)    ≈ 0"     0   "$(sin "$PI")"         "$T"
check_float "sin(-pi/2) = -1"    -1  "$(sin "-$HALF_PI")"   "$T"

check_float "cos(0)    = 1"      1   "$(cos 0)"             "$T"
check_float "cos(pi/2) ≈ 0"      0   "$(cos "$HALF_PI")"    "$T"
check_float "cos(pi)   = -1"     -1  "$(cos "$PI")"         "$T"

section "Pythagorean identity sin^2 + cos^2 = 1"
# sin²(x) + cos²(x) = 1 for all x. Verified across a range of angles as a
# cross-check: a bug in either function would break this identity.
for x in 0 1 0.5 1.2 -0.7; do
    check_float "sin²+cos²=1  x=$x" 1 \
        "$(echo "s($x)^2 + c($x)^2" | bc -l)" "$T"
done

section "tan, sec, csc, cot"
# tan(pi/4) = sin/cos = 1; sec(0) = 1/cos(0) = 1; csc(pi/2) = 1/sin(pi/2) = 1.
check_float "tan(0)    = 0"     0   "$(tan 0)"                           "$T"
check_float "tan(pi/4) = 1"     1   "$(tan "$(echo "a(1)" | bc -l)")"   "$T"
check_float "sec(0)    = 1"     1   "$(sec 0)"                           "$T"
check_float "csc(pi/2) = 1"     1   "$(csc "$HALF_PI")"                  "$T"
check_float "cot(pi/4) = 1"     1   "$(cot "$(echo "a(1)" | bc -l)")"   "$T"

section "Odd / even symmetry"
# sin, tan are odd: f(-x) = -f(x). cos is even: f(-x) = f(x).
# Tested at three non-special angles to catch sign-handling bugs.
for x in 0.5 1.2 2.3; do
    check_float "sin odd  x=$x"  "$(sin "$x")"  "$(echo "-($(sin "-$x"))" | bc -l)"  "$T"
    check_float "cos even x=$x"  "$(cos "$x")"  "$(cos "-$x")"                        "$T"
    check_float "tan odd  x=$x"  "$(tan "$x")"  "$(echo "-($(tan "-$x"))" | bc -l)"  "$T"
done

# ── 8. Inverse trigonometric ──────────────────────────────────────────────────
# atan is bc's primitive (a()). All other inverse trig functions are derived
# from it using algebraic identities.
section "atan"
check_float "atan(0)  = 0"       0                            "$(atan 0)"       "$T"
check_float "atan(1)  = pi/4"    "$(echo "$PI/4" | bc -l)"   "$(atan 1)"       "$T"
check_float "atan(-1) = -pi/4"   "$(echo "-$PI/4" | bc -l)"  "$(atan -1)"      "$T"
# atan approaches pi/2 asymptotically; at 1,000,000 we are within 1e-6 of pi/2.
check_float "atan(large) ~ pi/2" "$(echo "$PI/2" | bc -l)"   "$(atan 1000000)" 0.000001

section "asin / acos"
check_float "asin(0)   = 0"      0                             "$(asin 0)"    "$T"
check_float "asin(0.5) = pi/6"   "$(echo "$PI/6" | bc -l)"    "$(asin .5)"   "$T"
check_float "asin(-0.5)= -pi/6"  "$(echo "-$PI/6" | bc -l)"   "$(asin -.5)"  "$T"

check_float "acos(0)   = pi/2"   "$HALF_PI"                    "$(acos 0)"    "$T"
check_float "acos(0.5) = pi/3"   "$(echo "$PI/3" | bc -l)"    "$(acos .5)"   "$T"
# acos(-0.5) = 2pi/3 confirms the quadrant fix: the article's original formula
# atan(sqrt(1-x²)/x) returns a negative value for x < 0. Our formula
# pi/2 - atan(x/sqrt(1-x²)) correctly maps to the second quadrant.
check_float "acos(-0.5)= 2pi/3"  "$(echo "2*$PI/3" | bc -l)"  "$(acos -.5)"  "$T"

section "Round-trip: asin(sin(x)) = x  [domain: |x| < pi/2]"
# asin is only the left-inverse of sin on (-pi/2, pi/2); outside that interval
# sin wraps and asin cannot recover the original x.
for x in 0.3 0.7 -0.4; do
    check_float "asin(sin($x)) = $x"  "$x"  "$(asin "$(sin "$x")")"  "$T"
done

section "Round-trip: acos(cos(x)) = x  [domain: x in (0, pi)]"
# acos is only the left-inverse of cos on [0, pi]. Using negative x would give
# acos(cos(-x)) = acos(cos(x)) = x, not -x (the negative test was a prior bug).
for x in 0.3 0.7 1.2; do
    check_float "acos(cos($x)) = $x"  "$x"  "$(acos "$(cos "$x")")"  "$T"
done

section "acot / asec / acsc"
# acot(x) = pi/2 - atan(x). At x=0 this is pi/2; at x=-1 it is 3pi/4 (second
# quadrant), which confirms negative-x handling.
check_float "acot(0)  = pi/2"    "$HALF_PI"                   "$(acot 0)"   "$T"
check_float "acot(1)  = pi/4"    "$(echo "$PI/4" | bc -l)"   "$(acot 1)"   "$T"
check_float "acot(-1) = 3pi/4"   "$(echo "3*$PI/4" | bc -l)" "$(acot -1)"  "$T"

# asec(-2) = 2pi/3 confirms the quadrant fix applied to both asec and acsc.
check_float "asec(2)  = pi/3"    "$(echo "$PI/3" | bc -l)"   "$(asec 2)"   "$T"
check_float "asec(-2) = 2pi/3"   "$(echo "2*$PI/3" | bc -l)" "$(asec -2)"  "$T"

check_float "acsc(2)  = pi/6"    "$(echo "$PI/6" | bc -l)"   "$(acsc 2)"   "$T"
check_float "acsc(-2) = -pi/6"   "$(echo "-$PI/6" | bc -l)"  "$(acsc -2)"  "$T"

# Complementary identity: asec(x) + acsc(x) = pi/2 for all |x| > 1.
# This is the continuous analogue of asin + acos = pi/2.
for x in 2 3 5 -2; do
    check_float "asec+acsc=pi/2  x=$x" "$HALF_PI" \
        "$(echo "$(asec "$x") + $(acsc "$x")" | bc -l)" "$T"
done

# ── 9. Hyperbolic ─────────────────────────────────────────────────────────────
# Hyperbolic functions are defined directly via exp: sinh = (eˣ - e⁻ˣ)/2, etc.
# They share structural analogies with the circular trig functions but with a
# different Pythagorean identity: cosh² - sinh² = 1 (not +1).
section "sinh / cosh / tanh"
check_float "sinh(0) = 0"   0  "$(sinh 0)"  "$T"
check_float "cosh(0) = 1"   1  "$(cosh 0)"  "$T"
check_float "tanh(0) = 0"   0  "$(tanh 0)"  "$T"

check_float "sinh(1) ~ 1.1752"  1.17520119364380  "$(sinh 1)"  0.000000001
check_float "cosh(1) ~ 1.5431"  1.54308063481524  "$(cosh 1)"  0.000000001
check_float "tanh(1) ~ 0.7616"  0.76159415595576  "$(tanh 1)"  0.000000001

section "cosh^2 - sinh^2 = 1 (Pythagorean identity)"
# The hyperbolic Pythagorean identity. Tested over several x values including
# negative, since cosh is even and sinh is odd, both signs must balance correctly.
for x in 0 0.5 1 2 -1; do
    check_float "cosh²-sinh²=1  x=$x" 1 \
        "$(echo "($(cosh "$x"))^2 - ($(sinh "$x"))^2" | bc -l)" "$T"
done

section "tanh = sinh/cosh"
# Verifies the definition tanh = sinh/cosh independently of the direct formula.
for x in 0 0.5 1 -1; do
    check_float "tanh=sinh/cosh  x=$x" "$(tanh "$x")" \
        "$(echo "$(sinh "$x")/$(cosh "$x")" | bc -l)" "$T"
done

section "Odd / even symmetry (hyperbolic)"
# sinh and tanh are odd; cosh is even — same parity as their circular counterparts.
for x in 0.5 1 2; do
    check_float "sinh odd  x=$x"  "$(sinh "$x")"  "$(echo "-($(sinh "-$x"))" | bc -l)"  "$T"
    check_float "cosh even x=$x"  "$(cosh "$x")"  "$(cosh "-$x")"                        "$T"
    check_float "tanh odd  x=$x"  "$(tanh "$x")"  "$(echo "-($(tanh "-$x"))" | bc -l)"  "$T"
done

# tanh saturates to ±1 as x → ±∞. At ±100 the residual is well within 1e-6.
check_float "tanh(large) ~ 1"   1  "$(tanh 100)"   0.000001
check_float "tanh(-large) ~ -1" -1 "$(tanh -100)"  0.000001

# ── 10. Inverse hyperbolic ────────────────────────────────────────────────────
section "asinh / acosh / atanh"
check_float "asinh(0) = 0"  0  "$(asinh 0)"  "$T"
check_float "acosh(1) = 0"  0  "$(acosh 1)"  "$T"   # acosh(1) = ln(1 + 0) = 0
check_float "atanh(0) = 0"  0  "$(atanh 0)"  "$T"

check_float "asinh(1) ~ 0.8814" 0.88137358701954 "$(asinh 1)" 0.000000001
check_float "acosh(2) ~ 1.3170" 1.31695789692481 "$(acosh 2)" 0.000000001
check_float "atanh(.5) ~ 0.5493" 0.54930614433405 "$(atanh .5)" 0.000000001

section "Round-trip: f(f_inv(x)) = x"
# f(f⁻¹(x)) = x is the strongest correctness check: it composes the forward and
# inverse functions and verifies they cancel out to the identity.
for x in 0.5 1 2; do
    check_float "sinh(asinh($x)) = $x"  "$x"  "$(sinh "$(asinh "$x")")"  "$T"
done
for x in 1 1.5 2 3; do
    check_float "cosh(acosh($x)) = $x"  "$x"  "$(cosh "$(acosh "$x")")"  "$T"
done
for x in 0 0.3 0.7 -0.5; do
    check_float "tanh(atanh($x)) = $x"  "$x"  "$(tanh "$(atanh "$x")")"  "$T"
done

# ── 11. Edge cases & domain violations ───────────────────────────────────────
section "Edge cases — domain violations (expect empty output / bc error)"

# asin/acos formula: a(x / sqrt(1 - x²)). At x = ±1, sqrt(1-x²) = 0
# causing a divide-by-zero; bc prints an error to stderr and emits nothing on stdout.
check_domain_err "asin(1)  undefined"  "$(asin  1  2>/dev/null)"
check_domain_err "asin(-1) undefined"  "$(asin -1  2>/dev/null)"
check_domain_err "acos(1)  undefined"  "$(acos  1  2>/dev/null)"
check_domain_err "acos(-1) undefined"  "$(acos -1  2>/dev/null)"

# asec/acsc formula uses sqrt(x²-1). At x = ±1 this is zero, same failure mode.
check_domain_err "asec(1)  undefined"  "$(asec  1  2>/dev/null)"
check_domain_err "asec(-1) undefined"  "$(asec -1  2>/dev/null)"
check_domain_err "acsc(1)  undefined"  "$(acsc  1  2>/dev/null)"
check_domain_err "acsc(-1) undefined"  "$(acsc -1  2>/dev/null)"

# atanh formula: ln((1+x) / sqrt(1-x²)). At x = ±1, the denominator is 0 → ln(∞).
check_domain_err "atanh(1)  undefined" "$(atanh  1  2>/dev/null)"
check_domain_err "atanh(-1) undefined" "$(atanh -1  2>/dev/null)"

# csc(0) and cot(0): sin(0) = 0 exactly in bc → genuine divide-by-zero error.
check_domain_err "csc(0) undefined"  "$(csc 0  2>/dev/null)"
check_domain_err "cot(0) undefined"  "$(cot 0  2>/dev/null)"

# tan(pi/2) and sec(pi/2): cos(pi/2) is NOT exactly zero in bc — it has a
# floating-point residual of ~1e-20. Division by this residual produces ~1e20
# rather than a true error. We assert the result is large (> 10⁹) rather than
# expecting an error, because bc does not consider this a domain violation.
check_float "tan(pi/2) has large magnitude" 1 \
    "$(echo "define abs(x){if(x<0)return-x;return x;} abs($(tan "$HALF_PI"))>1000000000" | bc -l)" "$T"
check_float "sec(pi/2) has large magnitude" 1 \
    "$(echo "define abs(x){if(x<0)return-x;return x;} abs($(sec "$HALF_PI"))>1000000000" | bc -l)" "$T"

section "Edge cases — values near (but not at) domain boundaries"
# Confirm the formulas remain correct just inside the domain edge.
# asin(0.9999) is far from pi/2 (~1.5567, not ~1.5708) because the formula
# involves tan of a steep angle; it degrades gracefully without exploding.
check_float "asin(0.9999) ~ 1.5567"  1.5567 "$(asin .9999)"   0.0001
check_float "acos(0.0001) ~ pi/2"    "$HALF_PI" "$(acos .0001)" 0.001
# atanh diverges towards +∞ as x → 1; at 0.9999 it is already ~4.95.
check_float "atanh(0.9999) ~ 4.952"  4.952  "$(atanh .9999)"   0.001
check_float "asec(1.0001) ~ 0.0141"  0.0141 "$(asec 1.0001)"   0.001

section "Edge cases — large / extreme arguments"
# sin and cos are periodic; at a large multiple of pi the residual is bounded
# by bc's precision (~1e-19), which is well within our tolerance of 1e-7.
check_float "sin(100pi) ≈ 0"  0  "$(sin "$(echo "100*$PI" | bc -l)")"  0.0000001
check_float "cos(100pi) = 1"  1  "$(cos "$(echo "100*$PI" | bc -l)")"  0.0000001
# pow and sqrt with degenerate exponents: anything to the zero is 1, 1 to any
# power is 1, and sqrt(0) = 0.
check_float "pow(2,0)  = 1"   1  "$(pow 2 0)"    "$T"
check_float "pow(1,100)= 1"   1  "$(pow 1 100)"  "$T"
check_float "sqrt(0)   = 0"   0  "$(sqrt 0)"     "$T"

# ── summary ───────────────────────────────────────────────────────────────────
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
