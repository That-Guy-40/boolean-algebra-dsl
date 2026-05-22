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

### `ripple_add4` / `ripple_add8` — multi-bit ripple-carry adders

`ripple_add4` chains four full adders, threading the carry-out of each stage
into the carry-in of the next. `ripple_add8` chains two `ripple_add4` units, so
the carry-out of the low nibble (bits 0–3) feeds the carry-in of the high nibble
(bits 4–7). Both are built-in library functions. All bit strings are LSB-first.

```bash
# ripple_add4: A0..A3 B0..B3 [Cin] -> S0..S3 Cout
ripple_add4 1 1 0 0  1 0 1 0      # 3 + 5  -> 0 0 0 1 0   (= 8)

# ripple_add8: A0..A7 B0..B7 [Cin] -> S0..S7 Cout
ripple_add8 $(dec_to_bits 200 8) $(dec_to_bits 100 8)   # 200 + 100 (= 300)
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

### `ripple_sub4` / `ripple_sub8` — two's-complement subtractors

Subtraction reuses the adders: `A − B = A + (~B) + 1`. The helper `flip_bit`
inverts each bit of `B` (an XOR with 1), and the adder is run with carry-in = 1.

```bash
ripple_sub4 1 0 1 0  1 1 0 0      # 5 - 3  ->  0 1 0 0 1   (D = 2,  Cout=1: no borrow)
ripple_sub4 1 1 0 0  1 0 1 0      # 3 - 5  ->  0 1 1 1 0   (D = 14 = -2, Cout=0: borrow)
```

The trailing carry-out doubles as the borrow flag: `1` means no borrow (`A ≥ B`)
and the sum bits are the literal difference; `0` means borrow (`A < B`) and the
sum bits hold the two's-complement of the negative result.

### `compare4` / `compare8` — magnitude comparators

Two comparison primitives, both built purely from Boolean gates:

- **Equality** (`bits_eq`): `A = B` iff the XNOR (`eq`) of every bit pair is
  true — i.e. all pairs match. The per-bit XNORs are ANDed together.
- **Greater-than** (`bits_gt`): cascaded priority logic, scanning from the most
  significant bit down. `A > B` at the first bit where the two differ and `A`
  holds the 1; a running "all higher bits equal" flag gates each lower bit's
  contribution, so the highest differing bit always decides.

`bits_eq` and `bits_gt` are width-generic predicates (they take two LSB-first
bit strings, echo `true`/`false`, and set the exit code). `compare4` / `compare8`
are positional wrappers that echo `lt` / `eq` / `gt`. Less-than needs no separate
function — it is `bits_gt` with the operands swapped.

```bash
compare4 1 0 1 0  1 1 0 0      # 5 vs 3 -> gt
compare4 1 1 0 0  1 0 1 0      # 3 vs 5 -> lt
compare4 0 0 0 1  1 1 1 0      # 8 vs 7 -> gt   (decided at the MSB, not bit count)

if bits_eq "1 0 1 0" "1 0 1 0"; then echo equal; fi   # composes with if
```

The `8 vs 7` case (`1000` vs `0111`) is the one a naive "count the 1s" approach
gets wrong: cascaded priority correctly lets the single high bit of 8 outweigh
the three low bits of 7.

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

### EML applications — iterative algorithms

Once arithmetic exists, ordinary numerical algorithms can run *on top of the EML
layer*, using only `eml_mul` / `eml_sub` / `eml_add` / `eml_div`. Three are
included; all inherit the domain caveat that `eml_mul` needs its first argument
> 1, so they operate on `x > 1`.

| Function | What it does | Method |
|---|---|---|
| `eml_pow_int base n` | `base`ⁿ for integer n | `n` repeated `eml_mul`s |
| `eml_recip x [iters] [y0]` | reciprocal `1/x`, no division | Newton iteration `y ← y·(2 − x·y)` |
| `eml_sin_taylor x [terms]` | `sin x` | Maclaurin series via the above |

**`eml_recip`** is the interesting one: although `eml_div` already gives `1/x`
directly, Newton's iteration recovers the same value from *multiplication and
subtraction alone*. It converges quadratically (correct digits roughly double
each step). Two practical points fall out of the EML domain:

- The seed must satisfy `0 < y0 < 1/x` (an underestimate), so the correction
  factor `c = 2 − x·y` stays `> 1` for `eml_mul`. The default `y0 = 0.5` suits
  `1 < x < 2`; larger `x` needs a smaller seed.
- The loop **must stop at convergence**. Once `x·y` reaches 1, iterating again
  rounds `c` just *below* 1 — outside `eml_mul`'s domain — so `eml_recip` breaks
  the moment `x·y ≥ 1`.

**`eml_sin_taylor`** sums `x − x³/3! + x⁵/5! − …`, taking powers from
`eml_pow_int`, reciprocal factorials from `eml_div`, and accumulating with
`eml_sub`/`eml_add`. It holds for `1 < x ≲ π/2`: above 1 keeps the powers in
`eml_mul`'s domain, and not far past `π/2` keeps every partial sum positive
(so `eml_sub`/`eml_add`, whose first argument must be `> 0`, stay valid). With
6 terms it matches `bc`'s `sin` to roughly `10⁻⁸`.

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
# 477 passed, 0 failed
```

Coverage summary:

| Category | What is tested |
|---|---|
| Boolean primitives | All synonym inputs to `is_true` / `is_false` |
| Gate truth tables | All 4-row truth tables for every binary gate |
| Boolean identities | De Morgan, double negation, idempotence, absorption, XOR inverse |
| Adders | All 4 `half_adder` combinations with `true`/`false` strings; all 4 with `0`/`1` bit digits; 4 mixed inputs; all 8 `full_adder` combinations; `full_adder` string inputs |
| Multi-bit adders | `ripple_add4` exact bit patterns + decoded sums over 30 input pairs + carry-in; `ripple_add8` low→high nibble carry propagation, 8-bit overflow, carry-in |
| Subtractors | `flip_bit` truth table; `ripple_sub4` / `ripple_sub8` signed two's-complement results (positive and negative) and borrow-flag (carry-out) semantics |
| Comparators | `bit_to_bool`; `bits_eq` / `bits_gt` predicate exit codes; `compare4` over the full 8×8 grid and `compare8` over a 6×6 grid vs shell `-lt`/`-gt`; cascaded-priority edge cases (8 vs 7) |
| EML | Base constructions; exp/ln mutual inverses; all five arithmetic ops; mul/div round-trips |
| EML applications | `eml_pow_int` powers; `eml_recip` Newton reciprocal vs `eml_div` (incl. larger x with custom seeds); `eml_sin_taylor` vs `bc` sin, with term-count convergence |
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

# Adders, subtractors & comparators (LSB-first bit strings)
half_adder  full_adder
ripple_add4  ripple_add8
flip_bit  ripple_sub4  ripple_sub8
bit_to_bool  bits_eq  bits_gt  compare4  compare8

# List accessors
lhead  ltail  first  second

# EML operator
eml  eml_exp  eml_e  eml_ln  eml_zero
eml_sub  eml_neg  eml_add  eml_mul  eml_div

# EML applications (iterative algorithms)
eml_pow_int  eml_recip  eml_sin_taylor

# Math library
pi  sqrt  pow  log_base
sin  cos  tan  sec  csc  cot
atan  asin  acos  acot  asec  acsc
sinh  cosh  tanh
asinh  acosh  atanh
```
