#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# MATH TRACE — a viewer for Layer 3, in the spirit of add_trace / fsm_trace
#
# Layer 3 is "a scientific calculator on six primitives": every function is a thin
# identity over bc's  s (sin)  c (cos)  a (atan)  l (ln)  e (exp)  sqrt. A one-line
# wrapper hides that assembly, so this read-only viewer takes a derived function
# apart and shows each sub-expression evaluate down to those six primitives.
#
#   math_trace NAME args…   — decompose a derived function into its primitive pieces
#
# Covered: pow log_base  tan sec csc cot  sinh cosh tanh  asin acos asinh atanh.
# Read-only: it changes nothing in Layer 3. The pieces are honest bc values of each
# sub-expression; the final line is the REAL Layer-3 function (computed in one
# full-precision bc expression), so the answer can never drift from the library.
# ─────────────────────────────────────────────────────────────────────────────

source "$(dirname "${BASH_SOURCE[0]}")/boolean-funcs-new.sh"   # the six-primitive math library

_mt () { echo "$1" | bc -l; }   # evaluate one bc expression at the library's default scale

math_trace () {           # NAME args…  — show the decomposition into bc's six primitives
  local name="$1" x="$2" y="$3"
  case "$name" in
    pow)       # xʸ = exp(y·ln x)
      printf '\n  pow(%s, %s) = xʸ = exp(y · ln x)        [primitives: l, e]\n' "$x" "$y"
      printf '    ln x        = l(%s)            = %s\n'        "$x"      "$(_mt "l($x)")"
      printf '    y · ln x    = %s · l(%s)       = %s\n'       "$y" "$x" "$(_mt "$y*l($x)")"
      printf '    exp(…)      = e(y · ln x)      = %s\n'                 "$(_mt "e($y*l($x))")"
      _mt_final "pow $x $y" ;;
    log_base)  # logᵦ z = ln z / ln b   (NAME b z)
      printf '\n  log_base(%s, %s) = logᵦ z = ln z / ln b   [primitive: l]\n' "$x" "$y"
      printf '    ln z        = l(%s)            = %s\n' "$y" "$(_mt "l($y)")"
      printf '    ln b        = l(%s)            = %s\n' "$x" "$(_mt "l($x)")"
      printf '    ln z / ln b = …                = %s\n'      "$(_mt "l($y)/l($x)")"
      _mt_final "log_base $x $y" ;;
    tan|cot|sec|csc)   # all four from s and c
      printf '\n  %s(%s)   [from the primitives s (sin) and c (cos)]\n' "$name" "$x"
      printf '    sin x       = s(%s)            = %s\n' "$x" "$(_mt "s($x)")"
      printf '    cos x       = c(%s)            = %s\n' "$x" "$(_mt "c($x)")"
      case "$name" in
        tan) printf '    tan = sin/cos             = %s\n' "$(_mt "s($x)/c($x)")" ;;
        cot) printf '    cot = cos/sin             = %s\n' "$(_mt "c($x)/s($x)")" ;;
        sec) printf '    sec = 1/cos               = %s\n' "$(_mt "1/c($x)")" ;;
        csc) printf '    csc = 1/sin               = %s\n' "$(_mt "1/s($x)")" ;;
      esac
      _mt_final "$name $x" ;;
    sinh|cosh|tanh)    # all three from e
      printf '\n  %s(%s)   [from the primitive e (exp)]\n' "$name" "$x"
      printf '    eˣ          = e(%s)            = %s\n'  "$x" "$(_mt "e($x)")"
      printf '    e⁻ˣ         = e(-(%s))         = %s\n'  "$x" "$(_mt "e(-($x))")"
      case "$name" in
        sinh) printf '    (eˣ − e⁻ˣ)/2              = %s\n' "$(_mt "(e($x)-e(-($x)))/2")" ;;
        cosh) printf '    (eˣ + e⁻ˣ)/2              = %s\n' "$(_mt "(e($x)+e(-($x)))/2")" ;;
        tanh) printf '    (eˣ − e⁻ˣ)/(eˣ + e⁻ˣ)    = %s\n' "$(_mt "(e($x)-e(-($x)))/(e($x)+e(-($x)))")" ;;
      esac
      _mt_final "$name $x" ;;
    asin|acos)         # atan(x / sqrt(1 − x²))   [acos = π/2 − that]
      printf '\n  %s(%s) = atan( x / √(1 − x²) )       [primitives: sqrt, a (atan)]\n' "$name" "$x"
      printf '    x²          = %s·%s            = %s\n'   "$x" "$x" "$(_mt "($x)*($x)")"
      printf '    1 − x²      = …                = %s\n'             "$(_mt "1-($x)*($x)")"
      printf '    √(1 − x²)   = sqrt(…)          = %s\n'             "$(_mt "sqrt(1-($x)*($x))")"
      printf '    x / √(…)    = …                = %s\n'             "$(_mt "$x/sqrt(1-($x)*($x))")"
      printf '    atan(…)     = a(…)             = %s\n'             "$(_mt "a($x/sqrt(1-($x)*($x)))")"
      [ "$name" = acos ] && printf '    π/2 − atan(…)             = %s\n' "$(_mt "2*a(1)-a($x/sqrt(1-($x)*($x)))")"
      _mt_final "$name $x" ;;
    asinh)             # ln( x + sqrt(1 + x²) )
      printf '\n  asinh(%s) = ln( x + √(1 + x²) )        [primitives: sqrt, l (ln)]\n' "$x"
      printf '    1 + x²      = …                = %s\n' "$(_mt "1+($x)*($x)")"
      printf '    √(1 + x²)   = sqrt(…)          = %s\n' "$(_mt "sqrt(1+($x)*($x))")"
      printf '    x + √(…)    = …                = %s\n' "$(_mt "$x+sqrt(1+($x)*($x))")"
      printf '    ln(…)       = l(…)             = %s\n' "$(_mt "l($x+sqrt(1+($x)*($x)))")"
      _mt_final "asinh $x" ;;
    atanh)             # ln( (1 + x) / sqrt(1 − x²) )
      printf '\n  atanh(%s) = ln( (1 + x) / √(1 − x²) )   [primitives: sqrt, l (ln)]\n' "$x"
      printf '    1 + x       = …                = %s\n' "$(_mt "1+($x)")"
      printf '    1 − x²      = …                = %s\n' "$(_mt "1-($x)*($x)")"
      printf '    √(1 − x²)   = sqrt(…)          = %s\n' "$(_mt "sqrt(1-($x)*($x))")"
      printf '    ln( (1+x)/√(…) )              = %s\n'  "$(_mt "l((1+($x))/sqrt(1-($x)*($x)))")"
      _mt_final "atanh $x" ;;
    *) printf 'math_trace: unknown function "%s" (try pow/log_base/tan/sec/csc/cot/sinh/cosh/tanh/asin/acos/asinh/atanh)\n' "$name" >&2; return 2 ;;
  esac
}

# the real Layer-3 function has the last word — computed in one full-precision bc
# expression, so the displayed answer is exactly the library's (the per-piece values
# above are each rounded on their own, and are there to show the assembly).
_mt_final () { printf '  ── %-26s = %s   (the real Layer-3 function)\n' "$1" "$($1)"; }

# example use:
#   source ./math-trace.sh
#   math_trace pow 2 10        # xʸ taken apart into ln and exp
#   math_trace tan 1           # sin/cos
#   math_trace sinh 1          # built from eˣ and e⁻ˣ
#   math_trace asin 0.5        # atan( x / sqrt(1 − x²) )
