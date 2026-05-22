# Boolean Algebra DSL & Bootstrapped Math Library

A pure-Bash DSL for Boolean logic and arithmetic, extended with a continuous
math library bootstrapped from a single binary operator.

Two source files, ~1 000 lines total:

| File | Purpose |
|---|---|
| `boolean-funcs-new.sh` | 54 functions across three layers |
| `test-boolean-funcs.sh` | 272 automated tests |

---

## Architecture: Three Layers

The library is built from the bottom up. Each layer depends only on the one
below it.

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

---

## Layer 1 — Boolean DSL

### Value convention

Shell functions return **exit codes**: `0` = success = **true**, `1` (or
any nonzero) = **false**. This is the opposite of most languages, and it is
what makes `if cmd; then …` work naturally in the shell.

Gates also **echo** the strings `"true"` or `"false"` so their output can
be captured by subshell substitution and passed as an argument to another gate.

```bash
source ./boolean-funcs-new.sh

not true            # exits 1; echoes "false"
and true false      # exits 1; echoes "false"
or  true false      # exits 0; echoes "true"

# Compose with $()
not "$(and true true)"   # = not true = "false"
```

### Primitive: NAND

Every other gate is derived from `nand` alone — it is the single axiom of
this DSL. The derivation chain:

```
nand(A,A)        → not
not(nand(A,B))   → and
nand(not A, not B) → or      (De Morgan)
not(or(A,B))     → nor
nor(and A B, nor A B) → eq   (XNOR)
nor(and A B, nor A B) with an extra not → ne (XOR)
not(A) or B      → if_then
```

### Gates at a glance

| Function | Logic | Only false when |
|---|---|---|
| `nand A B` | ¬(A∧B) | both true |
| `not A` | ¬A | A is true |
| `and A B` | A∧B | either false |
| `or A B` | A∨B | both false |
| `nor A B` | ¬(A∨B) | either true |
| `ne A B` | A⊕B (XOR) | inputs match |
| `eq A B` | A↔B (XNOR) | inputs differ |
| `if_then A B` | A→B | A true, B false |
| `then_if A B` | B→A | B true, A false |
| `if_and_only_if A B` | A↔B | inputs differ |
| `or_nand A B` | A∨B | both false (alt. impl.) |

### Boolean algebraic identities

The test suite verifies these hold across all input combinations:

- **Double negation**: `not(not A) = A`
- **De Morgan (AND)**: `not(A and B) = or(not A)(not B)`
- **De Morgan (OR)**: `not(A or B) = and(not A)(not B)`
- **Idempotence**: `and A A = A`, `or A A = A`
- **Absorption**: `or A (and A B) = A`
- **XOR self-inverse**: `ne A A = false`

---

## Layer 1 — Adders

The adder functions bridge the Boolean layer and integer arithmetic by
operating on `0`/`1` bit strings.

### `half_adder A B` → `"sum carry"`

Adds two bits with no carry-in. Sum is XOR; carry is AND.

Accepts either `true`/`false` strings or `0`/`1` bit digits — the same input
convention as `full_adder`. Input normalisation uses a `case` statement rather
than `is_true`, because `is_true` follows the shell exit-code convention where
`"0"` = success = true, which is the opposite of the bit convention (0 = false).

```bash
half_adder false true   # "1 0"  (0+1 = 1, no carry)
half_adder true  true   # "0 1"  (1+1 = 0, carry 1)
half_adder 0 1          # "1 0"  (same, using bit digits)
half_adder 1 1          # "0 1"  (same, using bit digits)
```

### `full_adder A B Cin` → `"sum carry"`

Adds two bits plus a carry-in from a previous stage. Accepts `0`/`1` digits
or `true`/`false` strings.

```bash
full_adder 1 1 1   # "1 1"  (1+1+1 = 3 = binary 11)
```

### Composing full adders into a ripple-carry adder

Chain four full adders, threading the carry-out of each stage into the
carry-in of the next:

```bash
ripple_add4() {
    # Inputs: A[0..3] B[0..3] Cin  (all LSB first)
    # Output: S[0..3] Cout
    local r c
    r=$(full_adder "$1" "$5" "${9:-0}"); local s0; s0=$(first "$r"); c=$(second "$r")
    r=$(full_adder "$2" "$6" "$c");      local s1; s1=$(first "$r"); c=$(second "$r")
    r=$(full_adder "$3" "$7" "$c");      local s2; s2=$(first "$r"); c=$(second "$r")
    r=$(full_adder "$4" "$8" "$c");      local s3; s3=$(first "$r"); local cout; cout=$(second "$r")
    echo "$s0 $s1 $s2 $s3 $cout"
}
```

```
3 + 5 = 8:   ripple_add4  1 1 0 0  1 0 1 0  0  →  0 0 0 1 0
                           └─3─┘   └─5─┘        └──8──┘  └carry=0
7 + 7 = 14:  ripple_add4  1 1 1 0  1 1 1 0  0  →  0 1 1 1 0
15 + 1 = 16: ripple_add4  1 1 1 1  1 0 0 0  0  →  0 0 0 0 1  ← 4-bit overflow
             (all bits in LSB-first order)
```

The overflow case (carry-out = 1 with all sum bits 0) correctly signals that
the result does not fit in 4 bits.

---

## Layer 2 — EML Operator

The EML operator was introduced by Odrzywołek (2026):

```
eml(x, y) = exp(x) − ln(y)
```

It is **functionally complete in continuous mathematics** in the same sense
that NAND is complete in Boolean logic: combining `eml` with the constant `1`
is sufficient to express the entire standard repertoire of a scientific
calculator.

### Derivations from eml trees over {1}

Every function below is a finite composition of `eml` nodes — no other
primitives are used.

| Function | eml tree | Derivation |
|---|---|---|
| `eml_exp(x)` | `eml(x, 1)` | `exp(x) − ln(1) = exp(x)` |
| `eml_e` | `eml(1, 1)` | `exp(1) − ln(1) = e` |
| `eml_ln(x)` | `eml(1, eml(eml(1,x), 1))` | 3-node tree; see below |
| `eml_zero` | `eml(1, eml(eml(1,1), 1))` | `e − ln(exp(e)) = 0` |

**`eml_ln` derivation (step by step):**

```
eml(1, x)         = e − ln(x)
eml(e−ln(x), 1)   = exp(e−ln(x)) = eᵉ / x
eml(1, eᵉ/x)      = e − ln(eᵉ/x) = e − (e − ln x) = ln(x)  ✓
```

### Bootstrapped arithmetic

With `eml_ln` and `eml_exp` in hand, the four arithmetic operations follow:

```
eml_sub(x, y) = eml(ln x, exp y)       x − y        (domain: x > 0)
eml_neg(z)    = 0 − z                  −z            (bc handles ln(0) limit)
eml_add(x, y) = eml(ln x, exp(−y))     x + y        (domain: x > 0)
eml_mul(x, y) = exp(ln x + ln y)        x · y        (domain: x > 1)
eml_div(z)    = exp(−ln z)             1 / z         (domain: z > 0)
```

The `eml_neg` step is the only place bc arithmetic is used directly: the pure
eml form would require `eml(ln 0, exp z)`, but `ln(0) = −∞` is not
representable.

---

## Layer 3 — Bootstrapped Math Library

All functions wrap bc's six primitives (`s` sin, `c` cos, `a` atan, `l` ln,
`e` exp, `sqrt`) using the formulas from John D. Cook's bootstrapping article.

### Constants and roots

```bash
pi            # 4·atan(1) = 3.14159265…
sqrt 9        # 3
pow  2 10     # 2^10 ≈ 1024
log_base 10 100  # log₁₀(100) = 2
```

### Trigonometric (radians)

```bash
sin  cos  tan  sec  csc  cot
```

### Inverse trigonometric

```bash
atan  asin  acos  acot  asec  acsc
```

Two of the article's formulas were incorrect for negative inputs and have been
fixed:

| Function | Article's formula | Problem | Corrected formula |
|---|---|---|---|
| `acos(x)` | `atan(√(1−x²)/x)` | Wrong quadrant for x < 0 | `π/2 − atan(x/√(1−x²))` |
| `asec(x)` | `atan(√(x²−1))` | Returns `asec(|x|)` for x < 0 | `π/2 − atan(sign(x)/√(x²−1))` |

### Hyperbolic and inverse hyperbolic

```bash
sinh  cosh  tanh
asinh  acosh  atanh
```

---

## Integration

Source the file to bring all functions into the current shell session:

```bash
source /path/to/boolean-funcs-new.sh
```

Or place it in `.bashrc` / `.bash_profile` for persistent availability.

Functions are plain shell functions — they compose with standard shell idioms:
pipeline capture via `$(...)`, loops, conditionals on exit codes, and
parameter passing by position.

---

## Compositional Examples

### 1. Sigmoid function — pure EML chain

The sigmoid `σ(x) = 1 / (1 + e⁻ˣ)` is the activation function in logistic
regression and neural networks. It maps any real number to (0, 1).

It decomposes cleanly into four sequential EML operations:

```
x  →[eml_neg]→  −x  →[eml_exp]→  e⁻ˣ  →[eml_add 1]→  1+e⁻ˣ  →[eml_div]→  σ(x)
```

```bash
sigmoid() {
    local denom
    denom=$(eml_add 1 "$(eml_exp "$(eml_neg "$1")")")
    eml_div "$denom"
}
```

```
sigmoid(0)    →  0.5000…     (midpoint, as expected by symmetry)
sigmoid(2)    →  0.8808…
sigmoid(-2)   →  0.1192…     (symmetric: σ(-x) = 1 - σ(x))
```

### 2. Compound angle formula — trig composition

`sin(A + B) = sin(A)cos(B) + cos(A)sin(B)` can be expressed directly:

```bash
sin_sum() {
    echo "s($1)*c($2) + c($1)*s($2)" | bc -l
}
```

Verify with two angles that sum to π/2, where the result must be exactly 1:

```bash
PI=$(pi)
sin_sum "$(echo "$PI/3" | bc -l)" "$(echo "$PI/6" | bc -l)"
# → 0.99999999999999999997  (sin(π/3 + π/6) = sin(π/2) = 1)

sin_sum "$(echo "$PI/4" | bc -l)" "$(echo "$PI/4" | bc -l)"
# → 0.99999999999999999998  (sin(π/4 + π/4) = sin(π/2) = 1)
```

The residual from 1 is ~2 × 10⁻²⁰ — within bc's 20-digit precision limit.

### 3. Cross-layer: binary arithmetic into a trig function

This example spans all three layers. `ripple_add4` uses the Boolean layer to
add two 4-bit numbers; the result is converted to a radian angle and passed to
`sin` from the math library.

```bash
ripple_add4() {
    local r c
    r=$(full_adder "$1" "$5" "${9:-0}"); local s0; s0=$(first "$r"); c=$(second "$r")
    r=$(full_adder "$2" "$6" "$c");      local s1; s1=$(first "$r"); c=$(second "$r")
    r=$(full_adder "$3" "$7" "$c");      local s2; s2=$(first "$r"); c=$(second "$r")
    r=$(full_adder "$4" "$8" "$c");      local s3; s3=$(first "$r"); local cout; cout=$(second "$r")
    echo "$s0 $s1 $s2 $s3 $cout"
}

# Convert LSB-first bit string "s0 s1 s2 s3" to a decimal integer
bits_to_dec() {
    local b0=$1 b1=$2 b2=$3 b3=$4
    echo "$b0 + 2*$b1 + 4*$b2 + 8*$b3" | bc
}

# Add two 4-bit numbers at the gate level, then compute sin of the result
gate_add_then_sin() {
    local bits result_decimal angle
    bits=$(ripple_add4 "$@")
    result_decimal=$(bits_to_dec $bits)  # strips trailing carry
    angle=$(echo "$result_decimal * $(pi) / 12" | bc -l)  # scale to radians
    echo "bits: $bits  decimal: $result_decimal  sin(n·pi/12): $(sin "$angle")"
}

gate_add_then_sin  0 1 0 0  0 1 0 0  0   # 2+2=4  → sin(4π/12)=sin(π/3)=√3/2
gate_add_then_sin  1 1 0 0  1 0 1 0  0   # 3+5=8  → sin(8π/12)=sin(2π/3)=√3/2
gate_add_then_sin  0 0 1 0  0 0 1 0  0   # 4+4=8  → same
```

```
bits: 0 0 1 0 0  decimal: 4   sin(n·pi/12):  .86602540378443864675  (√3/2 ✓)
bits: 0 0 0 1 0  decimal: 8   sin(n·pi/12):  .86602540378443864677  (√3/2 ✓)
bits: 0 0 0 1 0  decimal: 8   sin(n·pi/12):  .86602540378443864677
```

The same value from three different gate-level additions demonstrates that the
layers compose correctly end to end.

---

## Test Suite

Run with:

```bash
bash test-boolean-funcs.sh
# 280 passed, 0 failed
```

Coverage summary:

| Category | What is tested |
|---|---|
| Boolean primitives | All synonym inputs to `is_true` / `is_false` |
| Gate truth tables | All 4-row truth tables for every binary gate |
| Boolean identities | De Morgan, double negation, idempotence, absorption, XOR inverse |
| Adders | All 4 `half_adder` combinations with `true`/`false` strings; all 4 with `0`/`1` bit digits; 4 mixed inputs; all 8 `full_adder` combinations; `full_adder` string inputs |
| EML | Base constructions; exp/ln mutual inverses; all five arithmetic ops; mul/div round-trips |
| Math library | Key angles; Pythagorean identity `sin²+cos²=1`; odd/even symmetry; `cosh²−sinh²=1`; `tanh=sinh/cosh`; forward/inverse round-trips |
| Edge cases — domain errors | `asin(±1)`, `acos(±1)`, `asec(±1)`, `acsc(±1)`, `atanh(±1)`, `csc(0)`, `cot(0)` — all produce empty output as expected |
| Edge cases — floating-point | `tan(π/2)` and `sec(π/2)` produce a large-but-finite value (~10²⁰) rather than an error, because `cos(π/2)` has a bc residual of ~10⁻²⁰ |
| Edge cases — extremes | `sin(100π)`, `pow(1,100)`, `sqrt(0)`, `atanh(0.9999)` |

---

## Quick Reference

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
