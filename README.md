# Boolean Algebra DSL

A pure-Bash library for Boolean logic and continuous mathematics, built from the ground up in three layers — each one derived entirely from the layer below it.

> **New to this? Start here →** three plain-English, no-math walkthroughs build the project from the ground up: [`TUTORIAL_LAYER1.md`](TUTORIAL_LAYER1.md) (yes/no switches → gates → binary → a working calculator chip), [`TUTORIAL_LAYER2.md`](TUTORIAL_LAYER2.md) (one math operator, `eml`, rebuilds the whole calculator keypad — add, multiply, division, even sine), and [`TUTORIAL_LAYER3.md`](TUTORIAL_LAYER3.md) (six primitives become a full scientific calculator, ending on the `sigmoid` function behind neural networks). If you're not a math person, read those first.

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

### A genuine Boolean algebra

The gates aren't just a NAND demo — `(or, and, not, false, true)` form a true **Boolean algebra**, and the test suite verifies every axiom exhaustively over all input assignments: commutativity, associativity, distributivity (both ways), identity (`A∨0=A`, `A∧1=A`), complement (`A∨¬A=1`, `A∧¬A=0`), annihilator, plus absorption, idempotence, involution, and De Morgan.

The algebra lifts to whole **bit-vectors** (LSB-first strings) with word-level ops and reductions:

```bash
word_not "1 0 1 1"               # "0 1 0 0"   (bitwise ¬)
word_and "1 1 0 0" "1 0 1 0"     # "1 0 0 0"   (also word_or, word_xor)
word_zip nand "1 1" "1 0"        # any gate, applied position-wise

and_all "1 1 1 1"                # true   (∧-reduce: all bits set?)
or_all  "0 0 1 0"                # true   (∨-reduce: any bit set?)
xor_all "1 1 0 1"                # true   (parity: odd number of 1s)
is_zero "0 0 0 0"                # true   (¬or_all — the ALU zero flag)

# complement reductions + readable aliases
nand_all "1 1 0 1"               # true   (not all set)
nor_all  "0 0 0 0"               # true   (no bits set, = is_zero)
xnor_all "1 1 0 0"               # true   (even parity)
all "1 1 1 1";  any "0 0 1 0";  none "0 0 0 0"   # = and_all / or_all / is_zero

# two-word "any-position" predicates: ∃ a bit where A op B holds
and_any "1 1 0 0" "1 0 1 0"      # true   (masks overlap — share a set bit)
or_any  "0 0 0 0" "0 1 0 0"      # true   (any bit set in either)
xor_any "1 0 1 0" "1 1 0 0"      # true   (differ somewhere; = ¬bits_eq)
```

### Word helpers and predicates

Convenience functions over bit-vectors. `inc`/`dec`/`negate` are width-preserving (results wrap two's-complement style); the `is_*` predicates echo `true`/`false` + exit code like the gates, so they compose with `if`.

```bash
inc "1 1 0 0"          # "0 0 1 0"   (3 + 1 = 4, width-preserving)
dec "0 0 1 0"          # "1 1 0 0"   (4 - 1 = 3)
negate "1 1 0 0"       # "1 0 1 1"   (-3 = 13 in 4-bit two's complement = ¬W + 1)

is_one  "1 0 0 0"      # true        (also is_zero)
is_even "1 1 0 0"      # false       (3 is odd; is_odd too — by the LSB)
is_negative "0 0 1 1"  # true        (MSB set; the ALU's N flag as a predicate)

parity   "1 1 1 0"     # 1           (parity bit: XOR of all bits, odd count)
popcount "1 0 1 1"     # 3           (Hamming weight)
lsb "1 0 0 1"          # 1     msb "1 0 0 1"   # 1
bits_to_int "0 0 1 0"  # 4           (decode; inverse of int_to_bits)
```

### Adders, subtractors, and comparators

`half_adder` and `full_adder` operate on `0`/`1` bit strings and accept either digit or `true`/`false` string inputs. They compose into multi-bit ripple-carry adders, two's-complement subtractors, and magnitude comparators. All multi-bit strings are **LSB-first** (bit 0 first).

```bash
half_adder true true    # "0 1"  (1+1 = 0, carry 1)
full_adder 1 1 1        # "1 1"  (1+1+1 = 3 = binary 11)

# ripple_add4: A0..A3 B0..B3 [Cin] -> S0..S3 Cout
ripple_add4 1 1 0 0  1 0 1 0    # 3 + 5  -> "0 0 0 1 0"  (= 8)
ripple_add4 1 1 1 1  1 0 0 0    # 15 + 1 -> "0 0 0 0 1"  (= 16, carry set)

# ripple_add8: chains two ripple_add4 units (low-nibble carry feeds the high nibble)
# ripple_sub4 / ripple_sub8: A - B via A + (~B) + 1 (flip B bits, force Cin=1)
# Trailing carry-out is the borrow flag: 1 = no borrow (A>=B), 0 = borrow (A<B)

# compare4 / compare8: echo lt / eq / gt
compare4 1 0 1 0  1 1 0 0       # 5 vs 3 -> "gt"
compare4 0 0 0 1  1 1 1 0       # 8 vs 7 -> "gt"  (decided at the MSB)

# bits_eq / bits_gt: width-generic predicates (true/false + exit code)
if bits_gt "$(echo 1 0 1 0)" "$(echo 1 1 0 0)"; then echo "5 > 3"; fi
```

Equality is the XNOR of every bit pair, all ANDed together; greater-than uses cascaded priority logic from the MSB down (the first differing bit decides). Less-than is `bits_gt` with the operands swapped.

### Multiplexer, min, and max

`mux` is the gate-level 2:1 selector (`out = (¬sel ∧ a) ∨ (sel ∧ b)`); `word_mux` applies it across a word. `bits_min` / `bits_max` then fall out by composition — the comparator picks the select line, the mux routes the operand:

```bash
mux 0 1 0                       # 1   (sel=0 → a);  mux 1 1 0 → 0  (sel=1 → b)
word_mux 1 "1 1 0 0" "1 0 1 0"  # "1 0 1 0"   (sel=1 → second word)

bits_min "1 1 0 0" "1 0 1 0"    # "1 1 0 0"   (min(3,5) = 3)
bits_max "1 1 0 0" "1 0 1 0"    # "1 0 1 0"   (max(3,5) = 5)
```

### Shifts and the ALU

`shl` / `shr` are width-preserving logical shifts. The capstone is **`alu4`** — a 4-bit arithmetic-logic unit whose data path is built entirely from the circuits above (ripple adder/subtractor, word-level bitwise ops, the comparator for `slt`, the shifters) plus `is_zero` for a status flag:

```bash
# alu4 OP  A0 A1 A2 A3  B0 B1 B2 B3   ->   "R0 R1 R2 R3 Z C N V"
#   OP ∈ add sub and or xor not slt shl shr
#   flags: Z zero, C carry/shift-out, N negative (sign), V signed overflow

alu4 add 1 1 0 0  1 0 1 0    # 3+5  -> "0 0 0 1 0 0 1 1"  (=8: V=1 overflow, N=1)
alu4 sub 1 0 1 0  1 1 0 0    # 5-3  -> "0 1 0 0 0 1 0 0"  (=2: C=1 no borrow)
alu4 and 1 1 0 0  1 0 1 0    # 3&5  -> "1 0 0 0 0 0 0 0"  (=1)
alu4 slt 1 1 0 0  1 0 1 0    # 3<5  -> "1 0 0 0 0 0 0 0"  (set: 1)
```

The `add 3+5` result shows the flags working: 8 is outside signed 4-bit's −8..+7 range, so the overflow flag `V` and negative flag `N` both fire.

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

### EML applications — iterative algorithms

Higher-level numerical algorithms built on the EML arithmetic, using only those operations (no `bc` math in the algorithm itself). They inherit the EML domain caveats — chiefly that `eml_mul` needs its first argument > 1, so these operate on `x > 1`.

```bash
eml_pow_int 1.5 3     # 3.375   (integer power via repeated eml_mul)

# Reciprocal 1/x by Newton's iteration y <- y*(2 - x*y) — no division at all.
# Domain: x > 1, seed 0 < y0 < 1/x. Default y0=0.5 suits 1<x<2; pass a smaller
# y0 for larger x. Converges quadratically; agrees with eml_div.
eml_recip 1.5         # 0.6667
eml_recip 10 9 0.05   # 0.1   (x, max_iters, y0)

# Same reciprocal, but the seed is chosen automatically: the Layer-1 bit
# comparator brackets x's magnitude (smallest k with 2^k > floor(x)) and seeds
# Newton with 2^-k. No hand-tuned y0 — a genuine Layer-1 → Layer-2 composition.
eml_recip_auto 10     # 0.1
eml_recip_auto 1000   # 0.001

# sin(x) from its Maclaurin series x - x³/3! + x⁵/5! - …  (1 < x <~ π/2)
eml_sin_taylor 1.5    # 0.99749…   (matches bc's sin to ~1e-8 with 6 terms)
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

## Experimental — alternative arithmetic

A separate, optional layer (`alt-arithmetic.sh`, see [`ALT_ARITHMETIC.md`](ALT_ARITHMETIC.md)) plays with **other ways to define number**, each wired back down into the Boolean layer:

```bash
source ./alt-arithmetic.sh

# Peano — number = zero + successor; successor IS the Layer-1 ripple-carry +1
peano_to_int "$(peano_mult "$(int_to_peano 3)" "$(int_to_peano 4)")"   # 12

# Church — number = iterated composition, on a tiny combinator layer (apply/compose/foldr)
church_to_int "$(church_pow "$(int_to_church 2)" "$(int_to_church 5)")"   # 32
bits_to_int "$(church_to_bits 5)"  # 5   (a Church numeral composes the Layer-1 inc circuit)

# Modular — clock arithmetic; fixed-width binary already IS arithmetic mod 2^W
mod_pow 2 10 1000                  # 24
mod_add_bits4 12 11                # 7   (= 23 mod 16, computed by the 4-bit adder)
```

These do arithmetic by *counting through the gates*, so they're intentionally slow and kept out of the core; their own suite is `test-alt-arithmetic.sh` (142 passing).

## Tests

```bash
bash test-boolean-funcs.sh
# 952 passed, 0 failed
```

Coverage: all gate truth tables, the full Boolean-algebra axiom set verified exhaustively (commutativity, associativity, distributivity, identity, complement, annihilator, absorption, idempotence, involution, De Morgan), word-level bitwise ops and reductions (incl. complement reductions `nand_all`/`nor_all`/`xnor_all` as exact negations, `all`/`any`/`none` aliases, and two-word `and_any`/`or_any`/`xor_any` cross-checked against `bits_eq` and `is_zero`), the `mux`/`word_mux` selector and `bits_min`/`bits_max` over a full grid, word helpers and predicates (inc/dec/negate wrap and inverses, is_one/is_even/is_odd/is_negative, parity = popcount mod 2, bits_to_int round-trips), all 8 full-adder combinations, multi-bit ripple adders/subtractors (decoded sums and signed two's-complement results), magnitude comparators (full lt/eq/gt grids plus cascaded-priority edge cases), `int_to_bits` round-trips, logical shifts, the `alu4` ALU (every opcode plus Z/C/N/V flag cases — overflow, carry, borrow, zero), EML mutual inverses, arithmetic round-trips, EML applications (integer powers, Newton reciprocal vs `eml_div`, comparator-seeded `eml_recip_auto`, Taylor sine vs `bc`), trig/inverse-trig/hyperbolic round-trips, domain error cases. The numeric layers are pinned against **independent `bc` oracles**: the base `eml(x,y)` operator against `e(x)−ln(y)`, the EML ops (`+`, `−`, `×`, `÷`, `^`, `neg`, `exp`, `ln`) against plain `bc` arithmetic — proving the `exp(x)−ln(y)` construction rebuilds ordinary math — both `eml_recip` and `eml_recip_auto` against `bc`'s `1/x`, the inverse hyperbolics against their `ln`/`sqrt` closed forms, and the derived trig (`tan`/`cot`/`sec`/`csc`) against `bc`'s `s()`/`c()` ratios. The shared `e` constant in the suite is `bc`'s `e(1)`, not `eml_e`, so the EML "= e" checks never compare the layer to itself.

## Attribution

- **Claude Opus** — EML operator derivations, bootstrapped math library, full-adder fix, and test suite.
- **[That-Guy-40](https://github.com/That-Guy-40)** — original idea, Boolean DSL layer, half-adder (subsequently debugged), integration work, and manual testing.

## Reference

```
# Boolean
true  false  is_true  is_false
nand  not  and  or  nor  ne  eq  or_nand
if_then  then_if  if_and_only_if

# Word-level Boolean algebra (LSB-first bit strings)
bool_to_bit  word_zip  word_not  word_and  word_or  word_xor
and_all  or_all  xor_all  is_zero
nand_all  nor_all  xnor_all  all  any  none
and_any  or_any  xor_any

# Word helpers & predicates
inc  dec  negate  bits_to_int
is_one  is_even  is_odd  is_negative
parity  popcount  lsb  msb

# Adders, subtractors & comparators (LSB-first bit strings)
half_adder  full_adder
ripple_add4  ripple_add8
flip_bit  ripple_sub4  ripple_sub8
bit_to_bool  bits_eq  bits_gt  compare4  compare8
int_to_bits

# Multiplexer, min & max
mux  word_mux  bits_min  bits_max

# Shifts & ALU
shl  shr  alu4

# List accessors
lhead  ltail  first  second

# EML operator
eml  eml_exp  eml_e  eml_ln  eml_zero
eml_sub  eml_neg  eml_add  eml_mul  eml_div

# EML applications (iterative algorithms)
eml_pow_int  eml_recip  eml_recip_auto  eml_sin_taylor

# Math library
pi  sqrt  pow  log_base
sin  cos  tan  sec  csc  cot
atan  asin  acos  acot  asec  acsc
sinh  cosh  tanh
asinh  acosh  atanh
```
