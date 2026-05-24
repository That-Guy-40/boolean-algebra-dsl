#!/bin/bash
# Tests for lambda.sh — SKI combinatory logic, the function side of Church–Turing.
#
# Sources lambda.sh AND alt-arithmetic.sh: the SKI-built Church numerals are
# cross-checked against the existing Church layer (int_to_church) and booleans
# (CHURCH_TRUE/FALSE), tying the two together. Fast (string rewriting + apply).

source "$(dirname "${BASH_SOURCE[0]}")/../lambda.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../alt-arithmetic.sh"   # int_to_church / CHURCH_TRUE for the reconnection

PASS=0; FAIL=0
section () { printf '\n── %s\n' "$1"; }
check_str () {
  local desc="$1" exp="$2" got="$3"
  if [ "$got" = "$exp" ]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); printf 'FAIL  %-46s want=[%s] got=[%s]\n' "$desc" "$exp" "$got"; fi
}
stars () { local n=$1 s="" i; for ((i=0; i<n; i++)); do s+="*"; done; printf '%s' "$s"; }
# a curried 2-arg test function: CC a b -> "a:b"  (for flip / dup checks)
_cc1 () { printf 'printf "%q:%%s" "$1"' "$1"; }
CC='_cc1 "$1"'
APP='printf "%s!" "$1"'; QUE='printf "%s?" "$1"'        # two unary fns, for compose

section "PART 1 — SKI combinators as apply-able fn values"
check_str "I x = x"             "x"   "$(applyc "$SKI_I" x)"
check_str "K x y = x"           "x"   "$(applyc "$SKI_K" x y)"
check_str "K drops 2nd arg"     "keep" "$(applyc "$SKI_K" keep drop)"
check_str "S K K x = x  (SKK=I)" "x"  "$(applyc "$SKI_S" "$SKI_K" "$SKI_K" x)"
check_str "S K S x = x"          "x"  "$(applyc "$SKI_S" "$SKI_K" "$SKI_S" x)"
check_str "B f g x = f (g x)"   "hi?!" "$(applyc "$SKI_B" "$APP" "$QUE" hi)"   # !(?(hi)) = hi?!
check_str "C f x y = f y x (flip)" "R:L" "$(applyc "$SKI_C" "$CC" L R)"
check_str "W f x = f x x (dup)"    "X:X" "$(applyc "$SKI_W" "$CC" X)"

section "PART 1b — Church booleans (and = the alt-arithmetic.sh layer's)"
check_str "TRUE a b -> a"  "a" "$(applyc "$LAMBDA_TRUE"  a b)"
check_str "FALSE a b -> b" "b" "$(applyc "$LAMBDA_FALSE" a b)"
check_str "lambda TRUE  == alt CHURCH_TRUE"  "$(apply2 "$CHURCH_TRUE"  a b)" "$(applyc "$LAMBDA_TRUE"  a b)"
check_str "lambda FALSE == alt CHURCH_FALSE" "$(apply2 "$CHURCH_FALSE" a b)" "$(applyc "$LAMBDA_FALSE" a b)"

section "PART 1b — Church numerals built only from S,K,I"
for n in 0 1 2 3 5 7; do
  check_str "numeral $n applies f $n times" "$(stars "$n")" "$(applyc "$(lambda_church "$n")" 'printf "%s*" "$1"' '')"
  check_str "numeral $n reads back to $n"   "$n"            "$(lambda_church_to_int "$(lambda_church "$n")")"
done
# successor really adds one
check_str "SUCC (numeral 4) reads back as 5" "5" "$(lambda_church_to_int "$(apply "$LAMBDA_SUCC" "$(lambda_church 4)")")"

section "PART 1b — SKI numerals == alt-arithmetic.sh's int_to_church"
for n in 0 1 2 3 5; do
  star='printf "%s*" "$1"'
  check_str "SKI numeral $n == int_to_church $n" \
      "$(applyc "$(int_to_church "$n")"  "$star" '')" \
      "$(applyc "$(lambda_church "$n")" "$star" '')"
done

section "PART 2 — symbolic reducer (SKI rewrite rules, normal order)"
check_str "I x"             "x"          "$(lc_normalize 'I x')"
check_str "K x y"           "x"          "$(lc_normalize 'K x y')"
check_str "K x y z"         "x z"        "$(lc_normalize 'K x y z')"
check_str "S a b c"         "a c (b c)"  "$(lc_normalize 'S a b c')"
check_str "S K K x  (SKK=I)" "x"         "$(lc_normalize 'S K K x')"
check_str "S (K S) K f g x = f (g x)  (B)" "f (g x)" "$(lc_normalize 'S (K S) K f g x')"
check_str "S I I x = x x"   "x x"        "$(lc_normalize 'S I I x')"
check_str "nested parens flatten" "y"    "$(lc_normalize '((I) (I)) y')"
check_str "already-normal term unchanged" "f x y" "$(lc_normalize 'f x y')"

section "PART 2 — symbolic numerals reduce to n-fold application"
check_str "ZERO  f x" "x"            "$(lc_normalize "$(lc_church 0) f x")"
check_str "ONE   f x" "f x"          "$(lc_normalize "$(lc_church 1) f x")"
check_str "TWO   f x" "f (f x)"      "$(lc_normalize "$(lc_church 2) f x")"
check_str "THREE f x" "f (f (f x))"  "$(lc_normalize "$(lc_church 3) f x")"

section "the two views agree (symbolic SKK and fn-value SKK both = identity)"
check_str "symbolic  S K K q -> q" "q" "$(lc_normalize 'S K K q')"
check_str "fn-value  S K K q -> q" "q" "$(applyc "$SKI_S" "$SKI_K" "$SKI_K" q)"

section "PART 2 — lc_show: annotated reduction agrees with lc_normalize / lc_trace"
# lc_show must reach the same normal form, in the same number of steps, as the
# unannotated reducer — and its rule labels must match _lc_redex_rule / lc_step.
show_nf ()    { printf '%s\n' "$1" | sed -n 's/^  normal form: \(.*\)   ([0-9].*/\1/p'; }
show_steps () { printf '%s\n' "$1" | sed -n 's/.*(\([0-9]*\) step.*/\1/p'; }
for t in 'I x' 'K x y' 'S K K x' 'S (K S) K f g x' 'S I I x' \
         "$(lc_church 2) f x" "$(lc_church 3) f x" 'f x y'; do
  out="$(lc_show "$t")"
  check_str "lc_show nf [$t]"    "$(lc_normalize "$t")"        "$(show_nf "$out")"
  check_str "lc_show steps [$t]" "$(lc_trace "$t" | grep -c '→')" "$(show_steps "$out")"
done
# the rule detector: present exactly when lc_step reduces, and the right combinator
check_str "rule of 'S K K x' is S" "S" "$(_lc_redex_rule 'S K K x')"
check_str "rule of 'K a b' is K"   "K" "$(_lc_redex_rule 'K a b')"
check_str "rule of 'I a' is I"     "I" "$(_lc_redex_rule 'I a')"
check_str "rule of nested 'a (I b) c' is I" "I" "$(_lc_redex_rule 'a (I b) c')"
check_str "normal term has no rule" "" "$(_lc_redex_rule 'x y z')"
# the annotation actually shows the rule schema
check_str "lc_show labels the S schema" "yes" \
  "$(lc_show 'S K K x' | grep -q 'S:  S x y z → x z (y z)' && echo yes)"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
