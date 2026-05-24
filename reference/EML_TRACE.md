# EML Trace — a viewer for Layer 2 (one operator, rebuilding arithmetic)

Layer 2 rebuilds ordinary arithmetic from a **single binary operator**,
`eml(x, y) = exp(x) − ln(y)` — the continuous-math analogue of NAND. Combined with the
constant 1, `eml` generates `+`, `−`, `×`, `÷`, `exp`, `ln`. The one-line definitions
hide that rebuild, so this **read-only viewer** shows it: the eml-tree behind each
operation, and the iterative algorithms (Newton, Taylor) built on top. It changes
nothing in Layer 2 and drives the **same building blocks** (`eml` / `eml_ln` / `eml_exp`
/ `eml_mul` / `eml_sub` …), so the picture stays faithful. Lives in `eml-trace.sh`.

See [`EML_OPERATOR.md`](EML_OPERATOR.md) for the operator itself.

## Loading

```bash
source ./eml-trace.sh        # sources boolean-funcs-new.sh (the eml operator + derived ops)
```

## The functions

| function | shows |
|---|---|
| `eml_trace OP a b` | how `+ − × ÷` are rebuilt as a tree of `eml` calls. `OP ∈ add sub mul div` |
| `eml_recip_trace x [iters] [y0]` | `1/x` by Newton's iteration `y ← y·(2 − x·y)`, step by step |
| `eml_sin_trace x [terms]` | `sin(x)` by its Maclaurin series, term by term |

## `eml_trace` — watch eml rebuild arithmetic

Each operation is a small tree of `eml` calls over the constant 1. The trace evaluates
that tree bottom-up, every line the bc value of one building block:

```bash
eml_trace mul 3 4        # 3 × 4
```
```
  eml MUL  3 × 4   =  exp(ln x + ln y)        [first arg must be > 1]
    ln x        = eml_ln 3        = 1.09861228866810969140
    ln y        = eml_ln 4        = 1.38629436111989061884
    ln x + ln y = eml_add(…)        = 2.48490664978800031027
    x × y       = eml_exp(…)        = 12.00000000000000000048
  result = 12.00000000000000000048   (every line is one eml building block; this equals the real eml_mul)
```

`add` shows `x + y = eml(ln x, exp(−y))`, `sub` shows `eml(ln x, exp y)`, `div` shows
`1/z = eml_exp(eml_neg(ln z))`. The `≈ 12` (vs `12` exactly) is the honest `exp`/`ln`
round-off — the whole point is that *ordinary multiplication falls out of one operator*.

## `eml_recip_trace` — Newton's method, no division

`1/x` as the root of `f(y) = 1/y − x`, found by `y ← y·(2 − x·y)` using **only**
`eml_mul` and `eml_sub`. Watch it converge quadratically (the correct digits roughly
double each row):

```bash
eml_recip_trace 1.5
```
```
  Newton reciprocal  1/x   via  y ← y·(2 − x·y)   (root of 1/y − x; no division)
  x = 1.5   y0 = 0.5   — stops once x·y reaches 1 (y has converged)

  iter   y                      t = x·y                c = 2 − t              y' = c·y
  ────────────────────────────────────────────────────────────────────────────────────
    0    0.5                    .75000…                1.25000…               .62500…
    1    .62500…                .93750…                1.06250…               .66406…
    …
  result = .66666666666666666666   (≈ 1/1.5)
```

For larger `x`, pass a smaller seed (`eml_recip_trace 10 9 0.05`), exactly as `eml_recip`
requires.

## `eml_sin_trace` — the Maclaurin series, term by term

`sin(x) = x − x³/3! + x⁵/5! − …`, with powers from `eml_pow_int`, reciprocal factorials
from `eml_div`, and the alternating sum from `eml_add` / `eml_sub`:

```bash
eml_sin_trace 1.5
```
```
  k   exp   term = x^exp / exp!       ±   acc (running sum)
  ──────────────────────────────────────────────────────────────────
  0    1    (the seed: x)            +   1.5
  1    3     .56249…                  −   .93750…
  2    5     .06328…                  +   1.00078…
  …
  result = .99749495568213524746   (≈ sin 1.5)
```

## Why it can't lie

Every trace drives the **real** Layer-2 functions: `eml_trace`'s lines are the actual
`eml_ln` / `eml_exp` / `eml_add` values, `eml_recip_trace` runs `eml_recip`'s exact loop
(`eml_mul` / `eml_sub`), and `eml_sin_trace` runs `eml_sin_taylor`'s exact series. The
suite pins each trace's `result` against the real function — **byte-for-byte**, since
both go through the identical `bc -l` pipeline.

## Tests

```bash
bash tests/test-eml-trace.sh    # 22 passed, 0 failed   (standalone)
```

---

*This is a viewer over **Layer 2** — see [`EML_OPERATOR.md`](EML_OPERATOR.md) for the
operator it traces and [`../TUTORIAL_LAYER2.md`](../TUTORIAL_LAYER2.md) for the
plain-English build. Its Layer-3 sibling is [`MATH_TRACE.md`](MATH_TRACE.md), and the
other viewers are [`CIRCUIT_TRACE.md`](CIRCUIT_TRACE.md),
[`ALT_ARITHMETIC_TRACE.md`](ALT_ARITHMETIC_TRACE.md),
[`COMBINATOR_TRACE.md`](COMBINATOR_TRACE.md), and [`LAMBDA_TRACE.md`](LAMBDA_TRACE.md).
For every layer at once, see [`OVERVIEW.md`](OVERVIEW.md).*
