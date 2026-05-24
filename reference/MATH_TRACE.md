# Math Trace — a viewer for Layer 3 (a calculator on six primitives)

Layer 3 is "a scientific calculator on **six primitives**": every function is a thin
identity over bc's `s` (sin), `c` (cos), `a` (atan), `l` (ln), `e` (exp), `sqrt`. A
one-line wrapper hides that assembly, so this **read-only viewer** takes a derived
function apart and shows each sub-expression evaluate down to those six primitives. It
changes nothing in Layer 3. Lives in `math-trace.sh`.

See [`MATH_LIBRARY.md`](MATH_LIBRARY.md) for the library itself.

## Loading

```bash
source ./math-trace.sh        # sources boolean-funcs-new.sh (the six-primitive library)
```

## The function

```
math_trace NAME args…
```

Covered: `pow` `log_base` · `tan` `sec` `csc` `cot` · `sinh` `cosh` `tanh` ·
`asin` `acos` `asinh` `atanh`.

## Examples

```bash
math_trace pow 2 10        # xʸ = exp(y · ln x)
```
```
  pow(2, 10) = xʸ = exp(y · ln x)        [primitives: l, e]
    ln x        = l(2)            = .69314718055994530941
    y · ln x    = 10 · l(2)       = 6.93147180559945309410
    exp(…)      = e(y · ln x)      = 1023.99999999999999992594
  ── pow 2 10                   = 1023.99999999999999992594   (the real Layer-3 function)
```

```bash
math_trace sinh 1          # built from eˣ and e⁻ˣ
```
```
  sinh(1)   [from the primitive e (exp)]
    eˣ          = e(1)            = 2.71828182845904523536
    e⁻ˣ         = e(-(1))         = .36787944117144232159
    (eˣ − e⁻ˣ)/2              = 1.17520119364380145688
  ── sinh 1                     = 1.17520119364380145688   (the real Layer-3 function)
```

```bash
math_trace asin 0.5        # atan( x / √(1 − x²) ) — built from sqrt and a (atan)
math_trace tan 1           # sin/cos
math_trace asinh 2         # ln( x + √(1 + x²) )
```

The `1023.999…` for `pow 2 10` (vs `1024`) is the honest `exp`/`ln` round-off — the
point is that `xʸ` is *assembled from* `ln` and `exp`, not a built-in.

## Why it can't lie

The per-piece lines are honest bc values of each sub-expression. The **final line is
the real Layer-3 function**, computed in one full-precision bc expression — so the
answer can never drift from the library (the pieces are each rounded on their own, and
are there to show the assembly). The suite pins that final line against the function
itself for every supported `NAME`, and spot-checks that a primitive piece equals its own
bc value.

## Tests

```bash
bash tests/test-math-trace.sh    # 21 passed, 0 failed   (standalone)
```

---

*This is a viewer over **Layer 3** — see [`MATH_LIBRARY.md`](MATH_LIBRARY.md) for the
library it traces and [`../TUTORIAL_LAYER3.md`](../TUTORIAL_LAYER3.md) for the
plain-English build. Its Layer-2 sibling is [`EML_TRACE.md`](EML_TRACE.md), and the other
viewers are [`CIRCUIT_TRACE.md`](CIRCUIT_TRACE.md),
[`ALT_ARITHMETIC_TRACE.md`](ALT_ARITHMETIC_TRACE.md),
[`COMBINATOR_TRACE.md`](COMBINATOR_TRACE.md), and [`LAMBDA_TRACE.md`](LAMBDA_TRACE.md).
For every layer at once, see [`OVERVIEW.md`](OVERVIEW.md).*
