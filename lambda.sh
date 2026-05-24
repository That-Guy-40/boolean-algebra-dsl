#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# LAMBDA — rudiments of the lambda calculus, via combinatory logic (SKI)
#
# The FUNCTION side of the Church–Turing story. Rather than fight bash over
# variable binding / α-renaming / capture, we use COMBINATORY LOGIC: three fixed
# combinators — S, K, I — out of which every closed lambda term can be built
# (combinatory completeness). Two complementary views live here, and they agree:
#
#   PART 1  SKI as real, apply-able "fn values" (code strings), built on the very
#           same `apply` substrate as the combinator layer. They actually COMPUTE,
#           and Church booleans / numerals fall straight out of them (reconnecting
#           to the Church work in alt-arithmetic.sh).
#   PART 2  A symbolic REDUCER over SKI terms written as DATA ("S K K x"), with a
#           normal-order step / normalize / trace — so you can watch a term reduce.
#
# test-lambda.sh exercises both, and cross-checks the SKI numerals against
# alt-arithmetic.sh's Church numerals.
#
#   I x        = x                 (identity)
#   K x y      = x                 (const)
#   S f g x    = f x (g x)         (substitute-and-apply)
#   B f g x    = f (g x)  (compose)   C f x y = f y x  (flip)   W f x = f x x  (dup)
#   and the classic punchline:  S K K  =  I
# ─────────────────────────────────────────────────────────────────────────────

source "$(dirname "${BASH_SOURCE[0]}")/list-processing-kit.sh"   # apply (+ apply2/apply3)

# applyc F a b c …  — apply a CURRIED fn value to several args, left to right.
# (`apply` is unary; SKI combinators are curried, so this chains the applications:
# applyc F a b  =  apply (apply F a) b.)
applyc () { local f="$1"; shift; local x; for x in "$@"; do f="$(apply "$f" "$x")"; done; printf '%s' "$f"; }

# ── PART 1 — SKI (and B/C/W) as curried fn values ─────────────────────────────
# A combinator is a fn value; applying it to one argument returns the next fn
# value, with the captured argument baked in via %q. One tiny staging helper per
# partial step keeps the quoting exactly one level deep (and readable).

SKI_I='printf %s "$1"'                                            # I x = x   (this is FN_ID)

_ski_K1 () { printf 'printf %%s %q' "$1"; }                       # K x = const x
SKI_K='_ski_K1 "$1"'

_ski_S2 () { printf 'apply "$(apply %q "$1")" "$(apply %q "$1")"' "$1" "$2"; }  # S f g = λx. f x (g x)
_ski_S1 () { printf '_ski_S2 %q "$1"' "$1"; }
SKI_S='_ski_S1 "$1"'

_ski_B2 () { printf 'apply %q "$(apply %q "$1")"' "$1" "$2"; }    # B f g = λx. f (g x)   (compose)
_ski_B1 () { printf '_ski_B2 %q "$1"' "$1"; }
SKI_B='_ski_B1 "$1"'

_ski_C2 () { printf 'apply "$(apply %q "$1")" %q' "$1" "$2"; }    # C f x = λy. f y x      (flip)
_ski_C1 () { printf '_ski_C2 %q "$1"' "$1"; }
SKI_C='_ski_C1 "$1"'

_ski_W1 () { printf 'apply "$(apply %q "$1")" "$1"' "$1"; }       # W f = λx. f x x        (duplicate)
SKI_W='_ski_W1 "$1"'

# ── PART 1b — Church booleans & numerals, built ONLY from S, K, I ─────────────
# TRUE selects its first argument, FALSE its second — which is exactly K and K I.
LAMBDA_TRUE="$SKI_K"                                  # λx y. x
LAMBDA_FALSE="$(apply "$SKI_K" "$SKI_I")"             # K I  =  λx y. y

# A Church numeral n applies a function n times. ZERO = K I (apply it zero times);
# the successor SUCC = S B tacks on one more application: SUCC n f x = f (n f x).
LAMBDA_ZERO="$LAMBDA_FALSE"                            # λf x. x
LAMBDA_SUCC="$(apply "$SKI_S" "$SKI_B")"              # S B

lambda_church () {                                    # build the nth numeral: n SUCCs over ZERO
  local n="$1" c="$LAMBDA_ZERO" i
  for ((i=0; i<n; i++)); do c="$(apply "$LAMBDA_SUCC" "$c")"; done
  printf '%s' "$c"
}
lambda_church_to_int () { applyc "$1" 'echo $(($1+1))' 0; }   # read a numeral back: apply "+1" n times to 0

# ── PART 2 — a symbolic reducer over SKI terms written as data ────────────────
# A term is a space-separated string; application is left-associative; parens
# group: "S K K x", "S (K S) K". S/K/I are the combinators, any other token is an
# opaque variable. Reduction is normal order (leftmost-outermost):
#   I a → a        K a b → a        S a b c → a c (b c)

_lc_strip () {   # trim spaces, then peel any parens that wrap the WHOLE term
  local s="$1"
  while [ "${s# }" != "$s" ]; do s="${s# }"; done
  while [ "${s% }" != "$s" ]; do s="${s% }"; done
  while [ "${s:0:1}" = "(" ]; do
    local depth=0 i ch close=-1
    for ((i=0; i<${#s}; i++)); do ch="${s:i:1}"
      [ "$ch" = "(" ] && ((depth++)); [ "$ch" = ")" ] && { ((depth--)); ((depth==0)) && { close=$i; break; }; }
    done
    [ "$close" -eq $(( ${#s}-1 )) ] || break
    s="${s:1:${#s}-2}"
    while [ "${s# }" != "$s" ]; do s="${s# }"; done
    while [ "${s% }" != "$s" ]; do s="${s% }"; done
  done
  printf '%s' "$s"
}
_lc_split () {   # print the top-level tokens (paren groups kept whole), one per line
  local s="$1" depth=0 tok="" i ch
  for ((i=0; i<${#s}; i++)); do ch="${s:i:1}"
    case "$ch" in
      '(') ((depth++)); tok+="$ch" ;;
      ')') ((depth--)); tok+="$ch" ;;
      ' ') if ((depth==0)); then [ -n "$tok" ] && { printf '%s\n' "$tok"; tok=""; }; else tok+="$ch"; fi ;;
      *)   tok+="$ch" ;;
    esac
  done
  [ -n "$tok" ] && printf '%s\n' "$tok"
}
lc_step () {     # one normal-order reduction step; prints the result, exit 1 if already normal
  local term toks head n i
  term="$(_lc_strip "$1")"
  mapfile -t toks < <(_lc_split "$term")
  while [ "${#toks[@]}" -ge 1 ] && [ "${toks[0]:0:1}" = "(" ]; do        # a parenthesised head just flattens
    term="$(_lc_strip "$(_lc_strip "${toks[0]}") ${toks[*]:1}")"
    mapfile -t toks < <(_lc_split "$term")
  done
  head="${toks[0]}"; n="${#toks[@]}"
  case "$head" in
    I) ((n>=2)) && { _lc_strip "${toks[*]:1}"; return 0; } ;;                                              # I a … → a …
    K) ((n>=3)) && { _lc_strip "${toks[1]} ${toks[*]:3}"; return 0; } ;;                                   # K a b … → a …
    S) ((n>=4)) && { _lc_strip "${toks[1]} ${toks[3]} (${toks[2]} ${toks[3]}) ${toks[*]:4}"; return 0; } ;; # S a b c … → a c (b c) …
  esac
  for ((i=1; i<n; i++)); do                                              # else reduce the leftmost reducible argument
    local sub r; sub="$(_lc_strip "${toks[i]}")"; r="$(lc_step "$sub")"
    if [ "$r" != "$sub" ]; then case "$r" in *' '*) r="($r)";; esac; toks[i]="$r"; _lc_strip "${toks[*]}"; return 0; fi
  done
  printf '%s' "$term"; return 1                                          # already in normal form
}
lc_normalize () {  # reduce to normal form (step-capped); prints the normal form
  local t="$1" max="${2:-1000}" i r
  t="$(_lc_strip "$t")"
  for ((i=0; i<max; i++)); do r="$(lc_step "$t")" || { printf '%s' "$t"; return 0; }; t="$r"; done
  printf '%s' "$t"; return 1     # hit the step cap without finishing
}
lc_trace () {      # print the entire reduction sequence, one step per line
  local t r max="${2:-1000}" i
  t="$(_lc_strip "$1")"; printf '%s\n' "$t"
  for ((i=0; i<max; i++)); do r="$(lc_step "$t")" || break; printf '  → %s\n' "$r"; t="$r"; done
}

# Which rule fires next? Mirrors lc_step's normal-order search but reduces nothing —
# it just names the combinator at the leftmost-outermost redex (S / K / I), or "" if
# the term is already in normal form. lc_show pairs it with lc_step to annotate steps.
_lc_redex_rule () {
  local term toks head n i
  term="$(_lc_strip "$1")"
  mapfile -t toks < <(_lc_split "$term")
  while [ "${#toks[@]}" -ge 1 ] && [ "${toks[0]:0:1}" = "(" ]; do
    term="$(_lc_strip "$(_lc_strip "${toks[0]}") ${toks[*]:1}")"
    mapfile -t toks < <(_lc_split "$term")
  done
  head="${toks[0]}"; n="${#toks[@]}"
  case "$head" in
    I) ((n>=2)) && { printf 'I'; return 0; } ;;
    K) ((n>=3)) && { printf 'K'; return 0; } ;;
    S) ((n>=4)) && { printf 'S'; return 0; } ;;
  esac
  for ((i=1; i<n; i++)); do                                   # else: leftmost reducible argument
    local sub r; sub="$(_lc_strip "${toks[i]}")"; r="$(_lc_redex_rule "$sub")"
    [ -n "$r" ] && { printf '%s' "$r"; return 0; }
  done
  return 1                                                    # normal form
}

# Like lc_trace, but ANNOTATES each step with the combinator rule that fired and its
# schema — so you can read *why* the term changed, not just that it did. Ends with the
# normal form and the step count.
lc_show () {
  local t r rule max="${2:-1000}" i n=0 schema
  t="$(_lc_strip "$1")"
  printf '  %s\n' "$t"
  for ((i=0; i<max; i++)); do
    rule="$(_lc_redex_rule "$t")" || break
    r="$(lc_step "$t")" || break
    case "$rule" in
      I) schema='I x → x' ;;
      K) schema='K x y → x' ;;
      S) schema='S x y z → x z (y z)' ;;
    esac
    printf '    → %-22s [%s:  %s]\n' "$r" "$rule" "$schema"
    t="$r"; n=$((n+1))
  done
  printf '  normal form: %s   (%d step%s)\n' "$t" "$n" "$([ "$n" = 1 ] || echo s)"
}

# Symbolic numerals for the reducer: ZERO = K I, SUCC = S B = S (S (K S) K).
LC_ZERO='(K I)'
LC_SUCC='(S (S (K S) K))'
lc_church () { local n="$1" t="$LC_ZERO" i; for ((i=0; i<n; i++)); do t="($LC_SUCC $t)"; done; printf '%s' "$t"; }
