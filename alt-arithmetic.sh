#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# ALTERNATIVE / NONSTANDARD MODELS OF ARITHMETIC
#
# An experimental compositional layer that sits ON TOP of the Boolean DSL
# (boolean-funcs-new.sh) and explores other ways to *define* number and
# arithmetic itself — the same "everything from one tiny piece" spirit as NAND
# (Layer 1) and the eml operator (Layer 2), but applied to the concept of number.
#
#   Peano   — a number is zero + repeated successor; arithmetic is recursion.
#             Here the successor IS the Layer-1 ripple-carry +1 (inc), so the
#             Peano recursion literally drives the Boolean gates.
#   Church  — a number is a function that repeats another function n times.
#   Modular — arithmetic in ℤ/nℤ ("clock" arithmetic). Fixed-width binary already
#             *is* arithmetic mod 2^W, so this generalises the ALU's wraparound.
#
# These are deliberately, gloriously slow: they do arithmetic by counting, and
# every count ripples through the gate layer. That cost is the point — it makes
# the foundations visible. (For fast integer math, use Layer 1's ripple_add /
# alu4 directly; for real numbers, Layers 2–3.)
#
# Usage:  source ./alt-arithmetic.sh   (it pulls in boolean-funcs-new.sh itself)
# ─────────────────────────────────────────────────────────────────────────────

source "$(dirname "${BASH_SOURCE[0]}")/boolean-funcs-new.sh"


# ═════════════════════════════════════════════════════════════════════════════
# PEANO ARITHMETIC  (over Layer-1 bit-strings)
#
# Giuseppe Peano's axioms define the natural numbers from just two things: the
# constant ZERO and a SUCCESSOR function S (".+1"). Every number is a tower of
# successors over zero — 3 is S(S(S(0))) — and every operation is defined by
# recursion that peels successors off one argument.
#
# The recursive *structure* below is transliterated from the example Scheme in
# "The Little Schemer" (Friedman & Felleisen). The twist here: a Peano number is
# represented as an LSB-first Layer-1 bit-string, and the three primitives are
# the Boolean circuits from Tutorial 1 —
#       zero        = a width-W string of 0s        (int_to_bits 0 W)
#       successor   = inc   (the ripple-carry +1)
#       predecessor = dec   (the ripple-borrow −1)
#       is-zero     = is_zero
# — so "addition by counting" is performed, bit by bit, BY the gates.
# ═════════════════════════════════════════════════════════════════════════════

PEANO_W=8        # default bit-width for Peano constants built from decimals

# ── Bridges to the rest of the stack ─────────────────────────────────────────
int_to_peano () { int_to_bits "$1" "${2:-$PEANO_W}"; }   # decimal → Peano bit-string
peano_to_int () { bits_to_int "$1"; }                     # Peano bit-string → decimal

# ── Peano primitives (the only "axioms"; everything else is built from these) ─
peano_zero    () { int_to_bits 0 "${1:-$PEANO_W}"; }     # the constant 0 (width W)
peano_succ    () { inc "$1"; }                            # S(n) = n + 1   (ripple-carry)
peano_pred    () { dec "$1"; }                            # predecessor    (ripple-borrow)
peano_is_zero () { is_zero "$1"; }                        # echoes true/false + exit code

# zero / one matching the WIDTH of a given number, for recursion base cases that
# must return a fresh constant of the right width.
_peano_zero_like () { local -a A; read -ra A <<< "$1"; int_to_bits 0 "${#A[@]}"; }
_peano_one_like  () { local -a A; read -ra A <<< "$1"; int_to_bits 1 "${#A[@]}"; }

# a < b, via the Layer-1 magnitude comparator:  a < b  ≡  bits_gt b a
peano_lt () { if bits_gt "$2" "$1" >/dev/null; then echo true; true; else echo false; false; fi; }

# ── The Little Schemer recursions, over bit-strings ──────────────────────────

peano_add ()
{
  # N1 + N2 = apply successor to N1, N2 times.
  if peano_is_zero "$2" >/dev/null; then echo "$1"
  else peano_succ "$(peano_add "$1" "$(peano_pred "$2")")"; fi
}

peano_sub ()
{
  # N1 − N2 = apply predecessor to N1, N2 times. Natural subtraction: valid for
  # N1 ≥ N2. Below zero it wraps (mod 2^W) — which is exactly the modular layer.
  if peano_is_zero "$2" >/dev/null; then echo "$1"
  else peano_pred "$(peano_sub "$1" "$(peano_pred "$2")")"; fi
}

peano_mult ()
{
  # N1 × N2 = add N1 to itself N2 times (0 when N2 = 0).
  if peano_is_zero "$2" >/dev/null; then _peano_zero_like "$1"
  else peano_add "$1" "$(peano_mult "$1" "$(peano_pred "$2")")"; fi
}

peano_div ()
{
  # ⌊N1 / N2⌋ by repeated subtraction (N2 > 0): how many times N2 fits in N1.
  if peano_lt "$1" "$2" >/dev/null; then _peano_zero_like "$1"
  else peano_succ "$(peano_div "$(peano_sub "$1" "$2")" "$2")"; fi
}

peano_expt ()
{
  # N1 ^ N2 = multiply N1 by itself N2 times.  x^0 = 1, x^1 = x.
  if   peano_is_zero "$2" >/dev/null; then _peano_one_like "$1"
  elif is_one        "$2" >/dev/null; then echo "$1"
  else peano_mult "$1" "$(peano_expt "$1" "$(peano_pred "$2")")"; fi
}

# Peano testing (decimals in/out via the bridges):
#   p () { peano_to_int "$(peano_add "$(int_to_peano 2)" "$(int_to_peano 3)")"; }
#   peano_to_int "$(peano_add  "$(int_to_peano 2)" "$(int_to_peano 3)")"   # 5
#   peano_to_int "$(peano_mult "$(int_to_peano 3)" "$(int_to_peano 4)")"   # 12
#   peano_to_int "$(peano_div  "$(int_to_peano 13)" "$(int_to_peano 4)")"  # 3
#   peano_to_int "$(peano_expt "$(int_to_peano 2)" "$(int_to_peano 5)")"   # 32


# ═════════════════════════════════════════════════════════════════════════════
# FUNCTION-APPLICATION MACHINERY  (a tiny combinator layer)
#
# To treat functions as values, a "fn value" here is a STRING of bash code that
# reads its argument(s) from $1 (and $2) and echoes its result. Strings pass
# through `$(…)` unharmed (no closures needed), so functions become data and
# composition is just string-building. A "list" is a space-separated string of
# atoms (the LSB-first / Scheme convention; atoms must not contain spaces).
#
#   FN_ID                identity            λx. x
#   apply  f x           application         f(x)
#   apply2 f a b         binary application  f(a, b)
#   lift   name          command → fn value  wrap a unary command as `name "$1"`
#   compose f g          composition         λx. f(g(x))
#   lnull/lhead/ltail/llength               Scheme-style list primitives
#   map / mapcar f xs    map a unary f over a list (iterative / recursive)
#   filter pred xs       keep atoms where pred echoes "true"
#   foldl / foldr f z xs left / right fold with a binary f
#
# map/fold accept a FUNCTION ARG that is either a command NAME or a fn value;
# `as_fn`/`as_fn2` normalise the two. The payoff: these rebuild the Layer-1 word
# ops — `map flip_bit bits` = word_not, `foldl and true bools` = and_all.
# ═════════════════════════════════════════════════════════════════════════════

FN_ID='printf %s "$1"'                              # identity as a fn value

apply   () { local __f="$1" __x="$2"; set -- "$__x"; eval "$__f"; }              # f(x)
apply2  () { local __f="$1" __a="$2" __b="$3"; set -- "$__a" "$__b"; eval "$__f"; }  # f(a,b)
lift    () { printf '%s "$1"' "$1"; }               # a command NAME → a fn value
compose () { printf 'apply %q "$(apply %q "$1")"' "$1" "$2"; }                   # (f ∘ g)(x) = f(g(x))

# Normalise a function argument: a fn value (mentions $1/$2) is used as-is; a bare
# command name is wrapped so it reads its argument(s) positionally.
as_fn   () { case "$1" in *'$1'*)        printf '%s' "$1" ;; *) printf '%s "$1"' "$1" ;; esac; }
as_fn2  () { case "$1" in *'$1'*|*'$2'*) printf '%s' "$1" ;; *) printf '%s "$1" "$2"' "$1" ;; esac; }

# Scheme-style list primitives (space-separated word lists).
lnull   () { set -- $1; [ $# -eq 0 ]; }
lhead   () { set -- $1; printf '%s' "$1"; }
ltail   () { set -- $1; shift; echo "$*"; }
llength () { set -- $1; echo $#; }

map () {                                  # map FN list   (FN unary; command or fn value)
  local f res="" e; f=$(as_fn "$1")
  for e in $2; do res+=" $(apply "$f" "$e")"; done
  echo "${res# }"
}

mapcar () {                               # recursive (Scheme) twin of map
  local f="$1" list="$2" h t
  lnull "$list" && return 0
  h=$(apply "$(as_fn "$f")" "$(lhead "$list")")
  t=$(mapcar "$f" "$(ltail "$list")")
  if [ -z "$t" ]; then printf '%s\n' "$h"; else printf '%s %s\n' "$h" "$t"; fi
}

filter () {                               # filter PRED list  (PRED echoes "true"/"false")
  local p res="" e; p=$(as_fn "$1")
  for e in $2; do [ "$(apply "$p" "$e")" = true ] && res+=" $e"; done
  echo "${res# }"
}

foldl () {                                # foldl F acc list  (F binary; command or fn value)
  local f acc="$2" e; f=$(as_fn2 "$1")
  for e in $3; do acc=$(apply2 "$f" "$acc" "$e"); done
  printf '%s' "$acc"
}

foldr () {                                # foldr F end list  (right fold)
  local f="$1" end="$2" list="$3" cf h rest
  lnull "$list" && { printf '%s' "$end"; return; }
  cf=$(as_fn2 "$f"); h=$(lhead "$list"); rest=$(foldr "$f" "$end" "$(ltail "$list")")
  apply2 "$cf" "$h" "$rest"
}


# ═════════════════════════════════════════════════════════════════════════════
# CHURCH NUMERALS  (number = iterated composition — the canonical encoding)
#
# Alonzo Church's lambda calculus: a number n IS the function "compose f with
# itself n times".  0 = λf x. x ,  1 = λf x. f x ,  n = λf x. fⁿ x.  A numeral is
# therefore a fn value (a lam) whose argument is another fn value f; applying it
# to f yields the fn "fⁿ", and applying that to x gives fⁿ(x). Every operation is
# the textbook lambda-calculus identity, expressed with the combinators above:
#       succ n   = λf. f ∘ (n f)
#       plus m n = λf. (m f) ∘ (n f)
#       mult m n = λf. m (n f)
#       pow  b e = e b                       (b^e: apply the numeral e to b)
# Nothing is a stored integer here — numbers really are composition. The numeral
# can iterate ANY fn value, so handing it the Layer-1 `inc` (lifted) makes a
# Church number build a bit-string by self-composition — number reaching the gates.
# ═════════════════════════════════════════════════════════════════════════════

# n-fold composition of f: fold `compose` over n copies of f, starting at FN_ID.
# (Uses its own loop rather than the list-`foldr` above, because fn values contain
# spaces and so can't ride in a space-separated list.)
church_iter ()
{
  local n="$1" f="$2" acc="$FN_ID" i
  for ((i=0; i<n; i++)); do acc=$(compose "$f" "$acc"); done
  printf '%s' "$acc"
}

int_to_church () { printf 'church_iter %s "$1"' "$1"; }    # numeral n = λf. (f composed n times)
church_zero   () { int_to_church 0; }
church_one    () { int_to_church 1; }

church_succ () { local n="$1"; printf 'compose "$1" "$(apply %q "$1")"' "$n"; }                          # λf. f ∘ (n f)
church_plus () { local m="$1" n="$2"; printf 'compose "$(apply %q "$1")" "$(apply %q "$1")"' "$m" "$n"; }  # λf. (m f) ∘ (n f)
church_mult () { local m="$1" n="$2"; printf 'apply %q "$(apply %q "$1")"' "$m" "$n"; }                  # λf. m (n f)
church_pow  () { apply "$2" "$1"; }                                                                       # b^e = e b

# is-zero, canonically:  n (const false) true  →  true only when n applies const
# zero times (i.e. n = 0).  Takes a numeral; echoes true/false.
__const_false='printf false'
church_is_zero () { apply "$(apply "$1" "$__const_false")" true; }

# ── bridges ──────────────────────────────────────────────────────────────────
__intsucc='echo $(( $1 + 1 ))'
church_to_int  () { apply "$(apply "$1" "$__intsucc")" 0; }     # numeral applied to (+1) then 0
# church_to_bits takes a plain int for convenience: the numeral composes the
# Layer-1 `inc` circuit, building the LSB-first bit-string by self-iteration.
church_to_bits () { local num W="${2:-8}"; num=$(int_to_church "$1"); apply "$(apply "$num" "$(lift inc)")" "$(int_to_bits 0 "$W")"; }

# Church testing (numerals are fn-value strings; use the bridges to read them):
#   church_to_int "$(int_to_church 5)"                                # 5
#   church_to_int "$(church_plus "$(int_to_church 2)" "$(int_to_church 3)")"  # 5
#   church_to_int "$(church_mult "$(int_to_church 3)" "$(int_to_church 4)")"  # 12
#   church_to_int "$(church_pow  "$(int_to_church 2)" "$(int_to_church 5)")"  # 32
#   bits_to_int "$(church_to_bits 5)"                                 # 5  (numeral drove inc)
#   apply "$(compose "$(lift inc)" "$(lift inc)")" "$(int_to_bits 3 4)"  # 3+2 via composed gates


# ═════════════════════════════════════════════════════════════════════════════
# MODULAR / CLOCK ARITHMETIC  (ℤ/nℤ)
#
# Arithmetic on a clock of n positions: count past n−1 and you wrap back to 0
# (10 + 5 on a 12-hour clock is 3). This is a *finite* number system, and it is
# not exotic — it is what the hardware already does. A fixed width of W bits can
# only hold 0…2^W−1, so binary addition that keeps W bits is exactly arithmetic
# mod 2^W: the ALU's carry-out/overflow is the clock hand sweeping past the top.
# mod_add_bits4 makes that literal by running the Layer-1 ripple adder.
# ═════════════════════════════════════════════════════════════════════════════

mod_reduce ()
{
  # Least non-negative residue of a (mod n). NOTE: r must be assigned on its own
  # line — in `local a=$1 n=$2 r=$((a%n))` the a/n inside the arithmetic resolve
  # to the CALLER's variables, not these locals (the project's recurring footgun).
  local a=$1 n=$2 r
  r=$(( a % n )); [ "$r" -lt 0 ] && r=$(( r + n ))
  echo "$r"
}

mod_add () { mod_reduce $(( $1 + $2 )) "$3"; }   # (a + b) mod n
mod_sub () { mod_reduce $(( $1 - $2 )) "$3"; }   # (a − b) mod n
mod_mul () { mod_reduce $(( $1 * $2 )) "$3"; }   # (a × b) mod n

mod_pow ()
{
  # base^exp mod n, by repeated squaring (so the intermediates never blow up).
  local base=$1 e=$2 n=$3 result=1
  base=$(mod_reduce "$base" "$n")
  while [ "$e" -gt 0 ]; do
    (( e & 1 )) && result=$(mod_mul "$result" "$base" "$n")
    base=$(mod_mul "$base" "$base" "$n"); e=$(( e >> 1 ))
  done
  echo "$result"
}

mod_inverse ()
{
  # Multiplicative inverse of a (mod n) via the extended Euclidean algorithm:
  # the x with a·x ≡ 1 (mod n). Exists iff gcd(a, n) = 1; otherwise echoes "none".
  local a=$1 n=$2 t=0 newt=1 r=$2 newr q tmp
  newr=$(( a % n )); [ "$newr" -lt 0 ] && newr=$(( newr + n ))
  while [ "$newr" -ne 0 ]; do
    q=$(( r / newr ))
    tmp=$newt; newt=$(( t - q*newt )); t=$tmp
    tmp=$newr; newr=$(( r - q*newr )); r=$tmp
  done
  if [ "$r" -gt 1 ]; then echo "none"; return 1; fi
  [ "$t" -lt 0 ] && t=$(( t + n ))
  echo "$t"
}

mod_add_bits4 ()
{
  # (a + b) mod 16, computed BY the Layer-1 4-bit ripple adder (carry-out
  # discarded). Concrete proof that fixed-width binary is clock arithmetic.
  local a=$1 b=$2 A B r; local -a R
  A=$(int_to_bits "$a" 4); B=$(int_to_bits "$b" 4)
  r=$(ripple_add4 $A $B)              # S0 S1 S2 S3 Cout (unquoted splat into args)
  read -ra R <<< "$r"
  bits_to_int "${R[0]} ${R[1]} ${R[2]} ${R[3]}"
}

# Modular testing:
#   mod_add 10 5 12        # 3    (10 + 5 on a clock face)
#   mod_sub 2 5 12         # 9
#   mod_pow 2 10 1000      # 24   (2^10 = 1024 ≡ 24)
#   mod_inverse 3 7        # 5    (3·5 = 15 ≡ 1 mod 7)
#   mod_inverse 4 6        # none (gcd(4,6) = 2)
#   mod_add_bits4 12 11    # 7    (= 23 mod 16, via the ripple adder)
