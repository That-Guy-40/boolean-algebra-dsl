#!/bin/bash
# Tests for eml-trace.sh — the Layer-2 viewer (eml-tree, Newton reciprocal, Taylor sine).
#
# Same promise as the other viewers: it CANNOT lie. Each trace's reported result is
# pinned against an INDEPENDENT call to the real Layer-2 function it visualises
# (eml_add/eml_sub/eml_mul/eml_div, eml_recip, eml_sin_taylor) — byte-for-byte, since
# both run the identical bc -l pipeline. A standalone (non-core) suite.

source "$(dirname "${BASH_SOURCE[0]}")/../eml-trace.sh"   # pulls in boolean-funcs-new.sh

PASS=0; FAIL=0
section () { printf '\n── %s\n' "$1"; }
check_str () {
  local desc="$1" exp="$2" got="$3"
  if [ "$got" = "$exp" ]; then PASS=$((PASS+1))
  else FAIL=$((FAIL+1)); printf 'FAIL  %-40s want=[%s] got=[%s]\n' "$desc" "$exp" "$got"; fi
}
result_of () { printf '%s\n' "$1" | sed -n 's/^  result = \([^ ]*\).*/\1/p' | tail -1; }

# ── eml_trace add/sub/mul/div == the real eml_* ------------------------------
section "eml_trace — result vs the real eml_add / eml_sub / eml_mul / eml_div"
for pair in "3 5" "2.5 4" "7 1.5"; do set -- $pair
  check_str "eml_trace add $1 $2" "$(eml_add "$1" "$2")" "$(result_of "$(eml_trace add "$1" "$2")")"
done
for pair in "7 3" "5 2" "10 4.5"; do set -- $pair
  check_str "eml_trace sub $1 $2" "$(eml_sub "$1" "$2")" "$(result_of "$(eml_trace sub "$1" "$2")")"
done
for pair in "3 4" "2 5" "1.5 6"; do set -- $pair
  check_str "eml_trace mul $1 $2" "$(eml_mul "$1" "$2")" "$(result_of "$(eml_trace mul "$1" "$2")")"
done
for z in 4 2.5 8 1.25; do
  check_str "eml_trace div $z" "$(eml_div "$z")" "$(result_of "$(eml_trace div "$z")")"
done

# ── eml_recip_trace == eml_recip --------------------------------------------
section "eml_recip_trace — result vs eml_recip (same Newton loop)"
check_str "recip 1.5"        "$(eml_recip 1.5)"        "$(result_of "$(eml_recip_trace 1.5)")"
check_str "recip 1.25"       "$(eml_recip 1.25)"       "$(result_of "$(eml_recip_trace 1.25)")"
check_str "recip 10 9 0.05"  "$(eml_recip 10 9 0.05)"  "$(result_of "$(eml_recip_trace 10 9 0.05)")"

# ── eml_sin_trace == eml_sin_taylor -----------------------------------------
section "eml_sin_trace — result vs eml_sin_taylor (same Maclaurin series)"
check_str "sin 1.5"        "$(eml_sin_taylor 1.5)"        "$(result_of "$(eml_sin_trace 1.5)")"
check_str "sin 1.2 5"      "$(eml_sin_taylor 1.2 5)"      "$(result_of "$(eml_sin_trace 1.2 5)")"
check_str "sin 1.5707963"  "$(eml_sin_taylor 1.5707963)"  "$(result_of "$(eml_sin_trace 1.5707963)")"

# ── format smoke -------------------------------------------------------------
section "format — traces render their headers"
check_str "mul shows exp(ln x + ln y)" "yes" "$(eml_trace mul 3 4    | grep -q 'exp(ln x + ln y)'        && echo yes)"
check_str "recip shows Newton rule"    "yes" "$(eml_recip_trace 1.5  | grep -q 'y ← y·(2 − x·y)'         && echo yes)"
check_str "sin shows the series"       "yes" "$(eml_sin_trace 1.5    | grep -q 'x − x³/3! + x⁵/5!'       && echo yes)"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
