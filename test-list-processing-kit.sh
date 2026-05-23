#!/bin/bash
# Standalone tests for list-processing-kit.sh.
#
# The kit is self-contained (it bundles its own apply/apply2), so we source ONLY
# the kit — no arithmetic models, no Layer-1 gates, nothing else. This proves it
# stands alone. Fast: pure list processing, no subshelled circuits.

source "$(dirname "${BASH_SOURCE[0]}")/list-processing-kit.sh"

PASS=0; FAIL=0
section () { printf '\n── %s\n' "$1"; }
check_str () {
  local desc="$1" exp="$2" got="$3"
  if [ "$got" = "$exp" ]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); printf 'FAIL  %-44s want=[%s] got=[%s]\n' "$desc" "$exp" "$got"; fi
}

# fn-value combinators / predicates used throughout
INC='echo $(($1+1))'; DBL='echo $(($1*2))'; SQ='echo $(($1*$1))'
ADD='echo $(($1+$2))'; MUL='echo $(($1*$2))'; SUB='echo $(($1-$2))'
EVEN='if (( $1 % 2 == 0 )); then echo true; else echo false; fi'
LT4='if (( $1 < 4 )); then echo true; else echo false; fi'
# bare commands, to confirm as_fn / as_fn2 also accept a command NAME
dbl ()  { echo $(($1*2)); }
add2 () { echo $(($1+$2)); }

section "list primitives"
check_str "lhead"   "3"      "$(lhead '3 1 4 1')"
check_str "ltail"   "1 4 1"  "$(ltail '3 1 4 1')"
check_str "llength" "4"      "$(llength '3 1 4 1')"
check_str "lnull '' "  "yes" "$(lnull '' && echo yes || echo no)"
check_str "lnull list" "no"  "$(lnull '1 2' && echo yes || echo no)"

section "map / mapcar / filter  (fn value AND command name)"
check_str "map square"      "1 4 9 16"  "$(map "$SQ" '1 2 3 4')"
check_str "map dbl (cmd)"   "2 4 6"     "$(map dbl '1 2 3')"
check_str "mapcar square"   "1 4 9 16"  "$(mapcar "$SQ" '1 2 3 4')"
check_str "filter even"     "2 4 6"     "$(filter "$EVEN" '1 2 3 4 5 6')"

section "folds: foldl / foldr / foldl1 / scanl"
check_str "foldl + 0"       "15"        "$(foldl "$ADD" 0 '1 2 3 4 5')"
check_str "foldl add2 (cmd)" "6"        "$(foldl add2 0 '1 2 3')"
check_str "foldl - left"    "-6"        "$(foldl "$SUB" 0 '1 2 3')"
check_str "foldr - right"   "2"         "$(foldr "$SUB" 0 '1 2 3')"
check_str "foldl1 + (no seed)" "10"     "$(foldl1 "$ADD" '1 2 3 4')"
check_str "foldl1 * (no seed)" "24"     "$(foldl1 "$MUL" '1 2 3 4')"
check_str "foldl1 single atom" "7"      "$(foldl1 "$ADD" '7')"
check_str "scanl + (running sums)" "0 1 3 6 10" "$(scanl "$ADD" 0 '1 2 3 4')"
check_str "scanl * (running prods)" "1 1 2 6 24" "$(scanl "$MUL" 1 '1 2 3 4')"
check_str "scanl empty = [z]" "0"       "$(scanl "$ADD" 0 '')"

section "zipwith / zip / unzip / flatten"
check_str "zipwith +"        "11 22 33" "$(zipwith "$ADD" '1 2 3' '10 20 30')"
check_str "zipwith * min-len" "5 12"    "$(zipwith "$MUL" '1 2 3 4' '5 6')"
check_str "zip"              "a:1 b:2 c:3" "$(zip 'a b c' '1 2 3')"
check_str "zip min-len"      "a:1 b:2"  "$(zip 'a b c' '1 2')"
check_str "flatten pairs"    "a 1 b 2 c 3" "$(flatten "$(zip 'a b c' '1 2 3')")"
check_str "flatten plain (no-op)" "a b c" "$(flatten 'a b c')"
check_str "flatten triples"  "1 2 3 4 5 6" "$(flatten '1:2:3 4:5:6')"
# unzip emits two lines: firsts then seconds
{ read -r U1; read -r U2; } <<< "$(unzip 'a:1 b:2 c:3')"
check_str "unzip firsts"     "a b c"    "$U1"
check_str "unzip seconds"    "1 2 3"    "$U2"
# round-trip: unzip ∘ zip recovers both lists
{ read -r R1; read -r R2; } <<< "$(unzip "$(zip '4 5 6' '7 8 9')")"
check_str "unzip∘zip firsts"  "4 5 6"   "$R1"
check_str "unzip∘zip seconds" "7 8 9"   "$R2"

section "slicing: take / drop / take_while / drop_while / take_until / drop_until"
check_str "take 2"          "a b"       "$(take 2 'a b c d')"
check_str "drop 2"          "c d"       "$(drop 2 'a b c d')"
check_str "take 9 (over)"   "a b"       "$(take 9 'a b')"
check_str "drop 9 (over)"   ""          "$(drop 9 'a b')"
check_str "take_while <4"   "1 2"       "$(take_while "$LT4" '1 2 5 3')"
check_str "drop_while <4"   "5 3"       "$(drop_while "$LT4" '1 2 5 3')"
check_str "take_until <4"   ""          "$(take_until "$LT4" '1 2 5 3')"
check_str "drop_until <4"   "1 2 5 3"   "$(drop_until "$LT4" '1 2 5 3')"

section "generators: lrange / lreverse / iterate"
check_str "lrange 3 7"      "3 4 5 6 7" "$(lrange 3 7)"
check_str "lrange 5 2 (empty)" ""       "$(lrange 5 2)"
check_str "lreverse"        "4 3 2 1"   "$(lreverse '1 2 3 4')"
check_str "iterate *2 (5)"  "1 2 4 8 16" "$(iterate "$DBL" 1 5)"
check_str "iterate +1 (4)"  "10 11 12 13" "$(iterate "$INC" 10 4)"

section "quantifiers: any / all"
check_str "any even (none)" "false"     "$(any "$EVEN" '1 3 5')"
check_str "any even (one)"  "true"      "$(any "$EVEN" '1 3 4')"
check_str "all even (all)"  "true"      "$(all "$EVEN" '2 4 6')"
check_str "all even (gap)"  "false"     "$(all "$EVEN" '2 3 6')"
check_str "all over empty"  "true"      "$(all "$EVEN" '')"
check_str "any over empty"  "false"     "$(any "$EVEN" '')"

section "composition with the kit (a small pipeline)"
# sum of squares of the even numbers in 1..6  = 4 + 16 + 36 = 56
check_str "Σ even² in 1..6 = 56" "56" "$(foldl "$ADD" 0 "$(map "$SQ" "$(filter "$EVEN" "$(lrange 1 6)")")")"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
