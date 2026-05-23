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
