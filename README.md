# Boolean Algebra DSL

A pure-Bash library for Boolean logic and continuous mathematics, built from the ground up in three layers — each one derived entirely from the layer below it.

```
┌─────────────────────────────────────────────┐
│  Continuous math library                    │  sin, cos, eml_mul, sigmoid, …
│  (bc -l on the backend)                     │
├─────────────────────────────────────────────┤
│  EML operator                               │  eml, eml_exp, eml_ln, eml_sub, …
│  (functionally complete in ℝ)              │
├─────────────────────────────────────────────┤
│  Boolean DSL                                │  nand, and, or, not, ne, eq, …
│  (shell exit codes + echoed strings)        │
└─────────────────────────────────────────────┘
```

## Quick start

```bash
source ./boolean-funcs-new.sh

# Boolean logic
and true false        # exits 1; echoes "false"
not "$(or true false)"  # "false"

# EML arithmetic
eml_add 3 5           # 8
eml_mul 4 3           # 12

# Math library
sin "$(pi)"           # ≈ 0  (sin π)
acos -0.5             # ≈ 2.094  (2π/3)
```

## Layer 1 — Boolean DSL

Shell functions return **exit codes**: `0` = true, nonzero = false. This lets them compose naturally with `if`, `&&`, and `||`. They also echo the strings `"true"` / `"false"` for capture via `$(...)`.

Every gate is derived from a single primitive — **NAND**:

```
nand(A,A)            → not
not(nand(A,B))       → and
nand(not A, not B)   → or      (De Morgan)
not(or(A,B))         → nor
```

| Function | Logic | False when |
|---|---|---|
| `nand A B` | ¬(A∧B) | both true |
| `not A` | ¬A | A is true |
| `and A B` | A∧B | either false |
| `or A B` | A∨B | both false |
| `nor A B` | ¬(A∨B) | either true |
| `ne A B` | A⊕B (XOR) | inputs match |
| `eq A B` | A↔B (XNOR) | inputs differ |
| `if_then A B` | A→B | A true, B false |

### Adders

`half_adder` and `full_adder` operate on `0`/`1` bit strings and accept either digit or `true`/`false` string inputs.

```bash
half_adder true true    # "0 1"  (1+1 = 0, carry 1)
full_adder 1 1 1        # "1 1"  (1+1+1 = 3 = binary 11)
```

## Layer 2 — EML Operator

The EML operator (`eml(x,y) = exp(x) − ln(y)`) is **functionally complete in continuous mathematics** — combining it with the constant `1` is sufficient to express all standard calculator functions, in the same way NAND is sufficient for all Boolean logic.

Original paper: Andrzej Odrzywołek, *"A Single Binary Operator for All Elementary Functions"*, arXiv:2603.21852v2 (2026).
https://arxiv.org/abs/2603.21852v2

```bash
eml 1 1               # e  (exp(1) − ln(1))
eml_exp 2             # e²
eml_ln  7             # ln(7)
eml_zero              # 0
```

All arithmetic is derived from EML trees:

```bash
eml_sub 7 3           # 4   (x − y = eml(ln x, exp y))
eml_add 3 5           # 8   (x + y = eml(ln x, exp(−y)))
eml_mul 3 4           # 12  (exp(ln x + ln y))
eml_div 4             # 0.25 (exp(−ln z) = 1/z)
```

## Layer 3 — Math Library

All functions call `bc -l` and are bootstrapped from its six primitives (`s`, `c`, `a`, `l`, `e`, `sqrt`), following [John D. Cook's bootstrapping article](https://www.johndcook.com/blog/2021/01/05/bootstrapping-math-library/).

```bash
pi                    # 3.14159265358979323844
sqrt 9                # 3
pow  2 10             # ≈ 1024
log_base 10 100       # 2

sin 0                 # 0
cos "$(pi)"           # -1
atan 1                # π/4

sinh 1                # ≈ 1.1752
asinh 1               # ≈ 0.8814
```

Two formulas from the original article were incorrect for negative inputs and have been fixed:

| Function | Article formula | Problem | Corrected |
|---|---|---|---|
| `acos(x)` | `atan(√(1−x²)/x)` | Wrong quadrant for x < 0 | `π/2 − atan(x/√(1−x²))` |
| `asec(x)` | `atan(√(x²−1))` | Returns `asec(|x|)` for x < 0 | `π/2 − atan(sign(x)/√(x²−1))` |

## Compositional example — sigmoid via EML chain

```bash
sigmoid() {
    local denom
    denom=$(eml_add 1 "$(eml_exp "$(eml_neg "$1")")")
    eml_div "$denom"
}

sigmoid 0    # 0.5
sigmoid 2    # 0.8808…
sigmoid -2   # 0.1192…  (symmetric: σ(-x) = 1 - σ(x))
```

## Tests

```bash
bash test-boolean-funcs.sh
# 280 passed, 0 failed
```

Coverage: all gate truth tables, Boolean identities (De Morgan, absorption, XOR inverse), all 8 full-adder combinations, EML mutual inverses, arithmetic round-trips, trig/inverse-trig/hyperbolic round-trips, domain error cases.

## Attribution

- **[That-Guy-40](https://github.com/That-Guy-40)** — original idea, Boolean DSL layer, half-adder (subsequently debugged), integration work, and manual testing.
- **Claude Opus** — EML operator derivations, bootstrapped math library, full-adder fix, and test suite.

## Reference

```
# Boolean
true  false  is_true  is_false
nand  not  and  or  nor  ne  eq  or_nand
if_then  then_if  if_and_only_if

# Adders
half_adder  full_adder

# List accessors
lhead  ltail  first  second

# EML operator
eml  eml_exp  eml_e  eml_ln  eml_zero
eml_sub  eml_neg  eml_add  eml_mul  eml_div

# Math library
pi  sqrt  pow  log_base
sin  cos  tan  sec  csc  cot
atan  asin  acos  acot  asec  acsc
sinh  cosh  tanh
asinh  acosh  atanh
```
