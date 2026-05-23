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
# CHURCH NUMERALS  (number as repeated application)
#
# Alonzo Church's encoding from the lambda calculus: a number n IS a function
# that, given any function f and a starting value x, applies f to x exactly n
# times.  0 = "do nothing", 1 = "do f once", 3 = "do f three times", etc. Numbers
# aren't things you store — they're *behaviours*.
#
# True closure-based numerals can't be expressed in bash (no first-class
# functions/closures that survive command substitution). So we realise a numeral
# as a repetition count, but treat it strictly as an ITERATOR: it is only ever
# used to drive `apply f n times` — never as an operand of + or *. The successor
# (+1) is the sole arithmetic primitive; add / mult / expt are built purely by
# composing iteration, mirroring the lambda-calculus identities:
#       add M N = apply succ, N times, to M
#       mul M N = apply (+M),  N times, to 0
#       exp B E = apply (×B),  E times, to 1
# The higher-order heart survives intact: `church_apply` will iterate ANY unary
# function — including the Layer-1 `inc` circuit (see church_to_bits), which is
# how a Church numeral reaches down and drives the gates.
# ═════════════════════════════════════════════════════════════════════════════

church_zero    () { echo 0; }
church_one     () { echo 1; }
church_succ    () { echo $(( $1 + 1 )); }                 # the one arithmetic primitive
church_is_zero () { if [ "$1" -eq 0 ]; then echo true; true; else echo false; false; fi; }

# THE combinator — a Church numeral in action: apply command F to X, n times.
church_apply ()
{
  # church_apply N F X  ->  F(F(…F(X)…)), n times.  F is any unary command.
  local n="$1" f="$2" x="$3" i
  for ((i=0; i<n; i++)); do x=$("$f" "$x"); done
  printf '%s' "$x"
}

church_add ()
{
  # M + N = apply the successor to M, N times.
  church_apply "$2" church_succ "$1"
}

church_mult ()
{
  # M × N = apply "+M" to 0, N times. (Repeated addition; no * on the numerals.)
  local M="$1" N="$2" acc i; acc=$(church_zero)
  for ((i=0; i<N; i++)); do acc=$(church_add "$M" "$acc"); done
  printf '%s' "$acc"
}

church_expt ()
{
  # B ^ E = apply "×B" to 1, E times. (Repeated multiplication.)
  local B="$1" E="$2" acc i; acc=$(church_one)
  for ((i=0; i<E; i++)); do acc=$(church_mult "$B" "$acc"); done
  printf '%s' "$acc"
}

# Bridges. The carrier already is the count, so to/from int is the identity; the
# interesting bridge is church_to_bits, which feeds the numeral the Layer-1 +1.
church_to_int  () { printf '%s' "$1"; }
int_to_church  () { printf '%s' "$1"; }
church_to_bits () { church_apply "$1" inc "$(int_to_bits 0 "${2:-8}")"; }   # iterate the gate-level +1

# Church testing:
#   church_apply 5 church_succ 0     # 5   (apply +1 five times to 0)
#   church_add  2 3                  # 5
#   church_mult 3 4                  # 12
#   church_expt 2 5                  # 32
#   bits_to_int "$(church_to_bits 5)"  # 5   (the numeral drove Layer-1 inc)


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
