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

# ── 4. Adders ─────────────────────────────────────────────────────────────────
section "half_adder"
# A half adder adds two single bits with no carry-in.
# Output is "sum carry" as 0/1 digits; 1+1 = 0 with carry 1 (binary overflow).
check_str "0+0 = sum=0 carry=0" "0 0" "$(half_adder false false)"
check_str "0+1 = sum=1 carry=0" "1 0" "$(half_adder false true)"
check_str "1+0 = sum=1 carry=0" "1 0" "$(half_adder true false)"
check_str "1+1 = sum=0 carry=1" "0 1" "$(half_adder true true)"

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
