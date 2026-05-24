# Math Library — Layer 3 (a scientific calculator on six primitives)

The batteries-included top of the continuous stack: constants, roots, and the full
trigonometric / inverse-trigonometric / hyperbolic suite. Every function is a thin
wrapper over **bc's six primitives** — `s` (sin), `c` (cos), `a` (atan), `l` (ln),
`e` (exp), `sqrt` — assembled with the identities from John D. Cook's bootstrapping
article. Lives in `boolean-funcs-new.sh`; the plain-English walkthrough is
[`../TUTORIAL_LAYER3.md`](../TUTORIAL_LAYER3.md).

## Loading

```bash
source ./boolean-funcs-new.sh
```

## Constants & roots

```bash
pi               # 3.14159…   (= 4·atan 1)
sqrt 9           # 3
pow 2 10         # 1024       (xʸ = exp(y·ln x); domain x > 0)
log_base 10 100  # 2          (logᵦ z = ln z / ln b)
```

## Trigonometric (radians)

`sin` `cos` `tan` `sec` `csc` `cot` — the three reciprocal functions are built from
bc's `s` / `c`.

```bash
sin "$(pi)"      # ≈ 0        cos 0   # 1        tan 0   # 0
```

## Inverse trigonometric

`atan` `asin` `acos` `acot` `asec` `acsc`.

```bash
atan 1           # 0.78539…   (π/4)
asin 0.5         # 0.52359…   (π/6)
acos -0.5        # 2.09439…   (2π/3)
```

Two of the article's formulas were **wrong for negative inputs**, and are corrected here:

| function | article's formula | problem | corrected |
|---|---|---|---|
| `acos x` | `atan(√(1−x²)/x)` | wrong quadrant for `x < 0` | `π/2 − atan(x/√(1−x²))` |
| `asec x` | `atan(√(x²−1))` | returns `asec(\|x\|)` for `x < 0` | `π/2 − atan(sign(x)/√(x²−1))` |

## Hyperbolic & inverse hyperbolic

`sinh` `cosh` `tanh` and `asinh` `acosh` `atanh`, from the `exp` / `ln` / `sqrt` closed
forms.

```bash
sinh 1     # 1.17520…     cosh 0    # 1        tanh 0    # 0
asinh 1    # 0.88137…     acosh 1   # 0        atanh 0.5 # 0.54930…
```

## Composition — the sigmoid (cross-layer)

The layers compose. The **sigmoid** `σ(x) = 1 / (1 + e^−x)` — the squashing function
behind neural networks — is built entirely from the EML layer below it:

```bash
sigmoid() { eml_div "$(eml_add 1 "$(eml_exp "$(eml_neg "$1")")")"; }
sigmoid 0     # ≈ 0.5              sigmoid 2   # ≈ 0.880797
```

It traces a smooth S-curve from ~0 to ~1, with `σ(x) + σ(−x) = 1`. (Tutorial 3 ends on
exactly this — a "soft yes/no," the continuous echo of Layer 1's hard one.)

## Tests

Round-trips (`f(f⁻¹(x)) = x`), identities (`sin² + cos² = 1`, `cosh² − sinh² = 1`,
`tanh = sinh/cosh`), odd/even symmetry, and the corrected inverses are all checked — with
the derived trig (`tan`/`cot`/`sec`/`csc`) and the inverse hyperbolics pinned against bc's
own `s`/`c`/`l`/`sqrt` closed forms. Domain violations (`asin(±1)`, `csc 0`, …) are
confirmed to fail cleanly. Run via `bash tests/test-boolean-funcs.sh`.

---

*Want to **watch** a function decompose into the six primitives? [`MATH_TRACE.md`](MATH_TRACE.md)
is a read-only viewer — `math_trace NAME args` takes a derived function apart into bc's
`s`/`c`/`a`/`l`/`e`/`sqrt` and shows each sub-expression evaluate.*

*Plain-English walkthrough: [`../TUTORIAL_LAYER3.md`](../TUTORIAL_LAYER3.md). This is the
top of the continuous-math tower; it stands on [`EML_OPERATOR.md`](EML_OPERATOR.md)
(Layer 2), which stands on [`BOOLEAN_DSL.md`](BOOLEAN_DSL.md) (Layer 1). Every layer at
once: [`OVERVIEW.md`](OVERVIEW.md).*
