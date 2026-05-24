# EML Operator — Layer 2 (all of continuous math from one binary operator)

What NAND is to Boolean logic, the **EML operator** is to continuous mathematics: a
single binary operator that, combined with just the constant `1`, generates the whole
standard repertoire of a scientific calculator.

```
eml(x, y) = exp(x) − ln(y)
```

Introduced by Odrzywołek (2026), it is **functionally complete in ℝ** — the continuous
analogue of NAND's completeness in Boolean algebra. Lives in `boolean-funcs-new.sh` (on
the `bc -l` backend); the plain-English walkthrough is
[`../TUTORIAL_LAYER2.md`](../TUTORIAL_LAYER2.md).

## Loading

```bash
source ./boolean-funcs-new.sh
eml 1 1     # 2.71828…   = exp(1) − ln(1) = e
```

## The primitives, as eml-trees over {1}

Every function here is a finite tree of `eml` nodes — no other building blocks:

| function | eml tree | value |
|---|---|---|
| `eml_exp x` | `eml(x, 1)` | `exp(x) − ln(1) = exp(x)` |
| `eml_e` | `eml(1, 1)` | `e ≈ 2.71828` |
| `eml_ln x` | `eml(1, eml(eml(1,x), 1))` | `ln(x)` — a 3-node tree |
| `eml_zero` | `eml(1, eml(eml(1,1), 1))` | `e − ln(eᵉ) = 0` |

The **`eml_ln` derivation** is the clever bit — peel it apart one node at a time:

```
eml(1, x)        = e − ln(x)
eml(e−ln x, 1)   = exp(e − ln x) = eᵉ / x
eml(1, eᵉ/x)     = e − ln(eᵉ/x) = e − (e − ln x) = ln(x)   ✓
```

```bash
eml_ln 7     # 1.94591…    (matches bc's l(7))
eml_zero     # ≈ 1e-20 ≈ 0 (a bc rounding residual, not an exact zero)
```

## Bootstrapped arithmetic

With `exp` and `ln` in hand, the four operations follow — each a small eml-tree:

| op | tree | = | domain |
|---|---|---|---|
| `eml_sub x y` | `eml(ln x, exp y)` | `x − y` | `x > 0` |
| `eml_neg z`   | `0 − z` | `−z` | (uses bc for the `ln 0` limit) |
| `eml_add x y` | `eml(ln x, exp(−y))` | `x + y` | `x > 0` |
| `eml_mul x y` | `exp(ln x + ln y)` | `x · y` | `x > 1` |
| `eml_div z`   | `exp(−ln z)` | `1 / z` | `z > 0` |

```bash
eml_sub 7 3    # 4         eml_add 3 5    # 8
eml_mul 4 3    # 12        eml_div 4      # 0.25        eml_neg 3   # -3
```

`eml_neg` is the lone spot that touches bc arithmetic directly: the pure form would need
`eml(ln 0, exp z)`, but `ln 0 = −∞` isn't representable.

## Algorithms on top of EML

Once arithmetic exists, ordinary numerical methods run *using only the EML ops*:

| function | does | method |
|---|---|---|
| `eml_pow_int base n` | `base`ⁿ (integer n) | `n` repeated `eml_mul`s |
| `eml_recip x [iters] [y0]` | `1/x`, **no division** | Newton: `y ← y·(2 − x·y)` |
| `eml_recip_auto x [iters]` | `1/x`, seed chosen for you | brackets `x` with the **Layer-1 bit comparator**, then `eml_recip` |
| `eml_sin_taylor x [terms]` | `sin x` | Maclaurin series via the above |

```bash
eml_pow_int 2 8        # 256
eml_recip 1.5          # 0.66666…    (Newton, from × and − alone)
eml_recip_auto 10      # 0.1         (no hand-tuned seed)
eml_sin_taylor 1.5 6   # 0.99749…    (≈ bc's sin 1.5, to ~1e-8)
```

**`eml_recip`** recovers `1/x` from *multiplication and subtraction only*, converging
quadratically (correct digits roughly double each step). Two EML-domain facts shape it:
the seed must be an underestimate (`0 < y0 < 1/x`) so the correction `2 − x·y` stays
`> 1` for `eml_mul`; and the loop must **stop at convergence** — once `x·y ≥ 1` the next
correction dips just below 1, out of `eml_mul`'s domain.

**`eml_recip_auto`** removes the manual seed and, in doing so, **reaches back to Layer 1**.
A valid underestimate of `1/x` is `2^−k`, where `k` is the bit-length of `floor(x)`; it
finds `k` by asking the Boolean comparator *"is `2^k > floor(x)`?"* (`int_to_bits` +
`bits_gt`) for `k = 0, 1, 2, …`. So the bottom layer's gate comparator chooses the
starting point for the top layer's Newton iteration — one function spanning the whole
stack (domain `1 < x < 2¹²`, the comparator width used).

## Domains & precision

Every `eml_mul`-based function inherits its `x > 1` domain; `eml_sub`/`eml_add` need a
positive first argument; `eml_ln`/`eml_div` need `> 0`. Results carry bc's ~20-digit
precision, so exact integers surface tiny residuals (`eml_sub 7 3` → `4.00…04`) — far
below any real error.

## Tests

The EML layer is pinned against **independent `bc` oracles**, never against itself: the
base `eml(x,y)` against `e(x)−l(y)`; every op (`+ − × ÷ ^ neg exp ln`) against plain bc
arithmetic — proving the `exp − ln` construction rebuilds ordinary math; both reciprocals
against bc's `1/x`; and `eml_sin_taylor` against bc's `sin`. (The suite's shared `e` is
bc's `e(1)`, not `eml_e`, so the "= e" checks can't be circular.) Run via
`bash tests/test-boolean-funcs.sh`.

---

*Plain-English walkthrough: [`../TUTORIAL_LAYER2.md`](../TUTORIAL_LAYER2.md). Below it sits
[`BOOLEAN_DSL.md`](BOOLEAN_DSL.md) (Layer 1 — whose comparator `eml_recip_auto` borrows);
above it, [`MATH_LIBRARY.md`](MATH_LIBRARY.md) (Layer 3) adds the trig / hyperbolic
batteries. Every layer at once: [`OVERVIEW.md`](OVERVIEW.md).*
