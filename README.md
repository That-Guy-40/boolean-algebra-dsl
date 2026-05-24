# Boolean Algebra DSL

A pure-Bash library for Boolean logic and continuous mathematics, built from the ground up in three layers — each one derived entirely from the layer below it. The project's guiding **ethos** and aim — *why* it's built this way — live in [`ETHOS.md`](ETHOS.md).

> **New to this? Start here →** three plain-English, no-math walkthroughs build the project from the ground up: [`TUTORIAL_LAYER1.md`](TUTORIAL_LAYER1.md) (yes/no switches → gates → binary → a working calculator chip), [`TUTORIAL_LAYER2.md`](TUTORIAL_LAYER2.md) (one math operator, `eml`, rebuilds the whole calculator keypad — add, multiply, division, even sine), and [`TUTORIAL_LAYER3.md`](TUTORIAL_LAYER3.md) (six primitives become a full scientific calculator, ending on the `sigmoid` function behind neural networks). If you're not a math person, read those first. Four companion walkthroughs go further once the trilogy clicks: [`TUTORIAL_LAYER4_ALT_ARITHMETIC.md`](TUTORIAL_LAYER4_ALT_ARITHMETIC.md) (stranger ways to define *number*), [`TUTORIAL_LAYER5_COMBINATORS.md`](TUTORIAL_LAYER5_COMBINATORS.md) (the same calculator, rebuilt from recipes instead of wiring), [`TUTORIAL_LAYER6_LAMBDA.md`](TUTORIAL_LAYER6_LAMBDA.md) (all of computing, out of three tiny functions), and [`TUTORIAL_LAYER7_MACHINES.md`](TUTORIAL_LAYER7_MACHINES.md) (the machine side — a rule-follower and a roll of tape). The **finale**, [`TUTORIAL_LAYER8_CHURCH_TURING.md`](TUTORIAL_LAYER8_CHURCH_TURING.md), shows every one of those roads computing the very same things.

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

# word_add / word_sub: the SAME ripple adder, width-generic — two bit STRINGS of any
# width (4, 8, 16, …) instead of fixed positional bits. Output: result bits + carry.
word_add "1 1 0 0" "1 0 1 0"                            # 3 + 5 (4-bit) -> "0 0 0 1 0" (= 8)
word_add "$(int_to_bits 200 8)" "$(int_to_bits 100 8)"  # 8-bit -> decodes to 300 (carry set)

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

`shl` / `shr` are width-preserving logical shifts; `sar` is the arithmetic (sign-replicating) right shift, and `rol` / `ror` rotate cyclically. The capstone is **`alu4`** — a 4-bit arithmetic-logic unit whose data path is built entirely from the circuits above (ripple adder/subtractor, word-level bitwise ops, the comparator for `slt`, the shifters) plus `is_zero` for a status flag:

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

**`alu8`** is the byte-width sibling — the same nine ops and four flags over 8-bit words, built on the width-generic `word_add` / `word_sub`. Step a value between widths with `zero_extend`, `sign_extend`, and `trunc_bits`:

```bash
# alu8 OP  A0..A7  B0..B7   ->   "R0..R7 Z C N V"   (same op set / flags as alu4)
alu8 add $(int_to_bits 100 8) $(int_to_bits 50 8)   # 150 -> "... 0 0 1 1"  (N,V: >127)
alu8 add $(int_to_bits 128 8) $(int_to_bits 128 8)  # 256 wraps to 0 -> Z=C=V=1

sign_extend "$(int_to_bits 12 4)" 8   # -4 in 4-bit  -> "0 0 1 1 1 1 1 1"  (still -4)
```

**Want to *see* the carry ripple?** `circuit-trace.sh` (see [`reference/CIRCUIT_TRACE.md`](reference/CIRCUIT_TRACE.md)) is a read-only viewer over this layer — `add_trace` / `sub_trace` draw the ripple-carry adder one bit at a time, and `alu_trace` decodes the Z/C/N/V flags into plain English. It's `fsm_trace` for the gates: it re-runs the real `full_adder`, so the picture can't drift from the circuit.

```bash
source ./circuit-trace.sh
add_trace "1 0 1 0" "0 1 1 0"        # 5 + 6, watch the carry thread down the column
alu_trace add "1 0 1 0" "0 1 1 0"    # result + decoded flags (here: signed overflow, V=1)
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

**Want to *see* eml rebuild arithmetic?** `eml-trace.sh` (see [`reference/EML_TRACE.md`](reference/EML_TRACE.md)) is a read-only viewer: `eml_trace` shows `+ − × ÷` as a tree of `eml` calls, `eml_recip_trace` walks the Newton reciprocal iteration, and `eml_sin_trace` lays out the Maclaurin sine term by term.

```bash
source ./eml-trace.sh
eml_trace mul 3 4         # × rebuilt from the eml operator -> ≈ 12
eml_recip_trace 1.5       # 1/1.5 by Newton's iteration, watch it converge
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

**Want to *see* the six primitives at work?** `math-trace.sh` (see [`reference/MATH_TRACE.md`](reference/MATH_TRACE.md)) is a read-only viewer: `math_trace NAME args` decomposes a derived function into bc's `s`/`c`/`a`/`l`/`e`/`sqrt` and shows each sub-expression evaluate.

```bash
source ./math-trace.sh
math_trace pow 2 10       # xʸ taken apart into ln and exp
math_trace sinh 1         # built from eˣ and e⁻ˣ
```

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

A separate, optional layer (`alt-arithmetic.sh`, see [`reference/ALT_ARITHMETIC.md`](reference/ALT_ARITHMETIC.md) for the reference and [`TUTORIAL_LAYER4_ALT_ARITHMETIC.md`](TUTORIAL_LAYER4_ALT_ARITHMETIC.md) for a plain-English walkthrough) plays with **other ways to define number**, each wired back down into the Boolean layer:

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

**Want to *see* a number get built?** `alt-arithmetic-trace.sh` (see [`reference/ALT_ARITHMETIC_TRACE.md`](reference/ALT_ARITHMETIC_TRACE.md)) is a read-only viewer over this layer, with a trace shaped to each model: `peano_trace` shows the successor tower (each `+1` a Layer-1 `inc`), `church_trace` watches a numeral apply a step function *n* times (`bits` mode drives the real gates — the function↔circuit handshake), and `mod_trace` / `mod_trace_pow` show the clock wrap and square-and-multiply.

```bash
source ./alt-arithmetic-trace.sh
peano_trace add 0 5          # the tower: 5 = S(S(S(S(S(0))))), each S a real inc
church_trace 4 bits          # numeral 4 driving Layer-1 inc to build its own bits
mod_trace add 10 5 12        # 10 + 5 on a 12-clock -> 3
```

## Combinator circuits — Layer 1 from the function side

The flip side of the experimental layer: `combinator-circuits.sh` (see [`reference/COMBINATOR_CIRCUITS.md`](reference/COMBINATOR_CIRCUITS.md) for the reference and [`TUTORIAL_LAYER5_COMBINATORS.md`](TUTORIAL_LAYER5_COMBINATORS.md) for a plain-English walkthrough) rebuilds Layer 1's word ops **declaratively**, from the `list-processing-kit.sh` combinators (`map`/`zipwith`/`foldl`/`scanl`) — and the test suite proves the two constructions agree bit-for-bit.

```bash
source ./combinator-circuits.sh

fp_word_not "1 0 1 1"                 # = word_not        (map flip_bit)
fp_word_xor "1 1 0 0" "1 0 1 0"       # = word_xor        (zipwith bit_xor)
fp_word_add "1 1 0 0" "1 0 1 0"       # = word_add: 3+5   (a foldl threading the carry)
fp_carry_chain "1 1 0 0" "1 0 1 0"    # 0 1 1 1 0         (the carry chain, via scanl)
```

The punchline: **`word_add` (Layer-1 loop) == `fp_word_add` (foldl) == `fp_word_add_scan` (scanl + zipwith3) == `ripple_add8` (chained nibbles)** — four independent constructions of the adder, one answer. Verified in `test-combinator-circuits.sh` (111 passing).

**Want to *see* the fold?** `combinator-trace.sh` (see [`reference/COMBINATOR_TRACE.md`](reference/COMBINATOR_TRACE.md)) is a read-only viewer over this layer: `fold_trace` / `scan_trace` / `map_trace` light up the kit combinators, and `fp_add_trace` shows the ripple adder *as a carry-threading `foldl`* — the same carry ripple `add_trace` drew for the gates, now revealed as a fold.

```bash
source ./combinator-trace.sh
fold_trace 'echo $(($1+$2))' 0 '1 2 3 4 5'   # collapse a list to 15, step by step
fp_add_trace "1 0 1 0" "0 1 1 0"             # 5 + 6: the carry ripple AS a fold
```

## Lambda calculus — the function side

`lambda.sh` (see [`reference/LAMBDA.md`](reference/LAMBDA.md) for the combinators reference, [`reference/LAMBDA_TRACE.md`](reference/LAMBDA_TRACE.md) for the step-by-step reducer, and [`TUTORIAL_LAYER6_LAMBDA.md`](TUTORIAL_LAYER6_LAMBDA.md) for a plain-English walkthrough) builds the **function side** of Church–Turing: the lambda calculus, via **combinatory logic** — the three combinators **S**, **K**, **I**, which sidestep variable-capture by having no variables at all. Two views, cross-checked against each other and against the Church numerals in `alt-arithmetic.sh`:

```bash
source ./lambda.sh

# SKI as real, apply-able functions (curried):
applyc "$SKI_S" "$SKI_K" "$SKI_K" q                  # q     ← the classic S K K = I
applyc "$(lambda_church 3)" 'printf "%s*" "$1"' ''   # ***   (a numeral built from S,K,I)

# …and as data you can watch reduce, by the rules  I a→a,  K a b→a,  S a b c→a c (b c):
lc_normalize 'S (K S) K f g x'        # f (g x)       (compose, B = S(KS)K, falling out of S/K)
lc_trace "$(lc_church 1) f x"         # SUCC ZERO f x  →  …  →  f x
lc_show 'S K K x'                     # the same reduction, each step labelled [S/K/I: schema]
```

`test-lambda.sh` (45 passing) checks both views agree, and that the SKI numerals match `int_to_church`.

## A machine layer — the other side of Church–Turing

If `lambda.sh` is the **function** side, `state-machine.sh` and `turing-machine.sh` (see [`reference/MACHINES.md`](reference/MACHINES.md) for the reference and [`TUTORIAL_LAYER7_MACHINES.md`](TUTORIAL_LAYER7_MACHINES.md) for a plain-English walkthrough) are the **machine** side: a finite state machine — where *running it is a left fold of the transition over the input* — and then a Turing machine, that same control plus a bounded read/write tape.

```bash
source ./turing-machine.sh        # sources state-machine.sh (the FSM) too

fsm_run "$FSM_PARITY" e '1 1 0 1'                 # o   (odd number of 1s; an FSM run = a foldl)

# a Turing machine that increments a binary number, LSB-first…
tm_run "$TM_BINARY_INC" h c '1 1 0 0'             # 0 0 1 0   (3 -> 4)
inc "1 1 0 0"                                     # 0 0 1 0   (…the SAME function as Layer 1's gate-built inc)

TM_BLANK=0; tm_steps "$TM_BB3" H A '' 100 $((TM_TAPE/2))   # 14   (a busy beaver: six 1s, then it halts)
```

The wire-backs are the point: the binary-increment TM equals `inc`, the bit-flip TM equals `word_not`, the parity FSM equals `xor_all`, and an FSM *is* a TM that only moves right and never writes. `test-state-machine.sh` (37) and `test-turing-machine.sh` (40) check it all.

## The capstone — Church–Turing in action

The point of the whole project, in one script. `church-turing.sh` computes the **same function on every model** — pure lambda (SKI), Church numerals, a Turing machine, and the Layer-1 gate circuit — and shows they all land on the same answer. That different definitions of "computable" agree is the **Church–Turing thesis**; that they all bottom out in the same NAND gates is this repo's running theme:

```bash
source ./church-turing.sh
ct_show_succ 5
```
```
successor of 5  ->  6
  function side  ·  pure lambda / SKI (LAMBDA_SUCC)  : 6
  function side  ·  Church numeral   (church_succ)   : 6
  machine side   ·  Turing machine   (TM_BINARY_INC) : 6
  circuit        ·  Layer-1 gates    (inc)           : 6
  => all four models agree
```

`ct_show_add N M` does the same for addition; `ct_demo` runs a tour; and `ct_church_to_bits_value N` is the literal handshake — a Church numeral (a pure function) driving the `inc` gate circuit to build its own bits. `test-church-turing.sh` (46 passing) asserts the agreement. **This is the gates → arithmetic → machines → lambda → "all the same power" payoff the whole repo builds toward** — and [`TUTORIAL_LAYER8_CHURCH_TURING.md`](TUTORIAL_LAYER8_CHURCH_TURING.md) is its plain-English walkthrough.

## Viewers — watch each layer compute

Every layer has a **viewer**: read-only functions that print the layer's hidden work — the carry rippling through the adder, one `eml` operator rebuilding `×`, a Church numeral counting, an SKI term reducing. Each is read-only (it changes nothing in the layer it views), drives the layer's *real* functions (so the picture can't drift from the computation), and ships a standalone test suite that pins its output against those functions.

**How to run a viewer.** They are **functions, not runnable programs**: `source` the script once (it pulls in the layers it needs), then call a function by name with arguments. Running a `*-trace.sh` file directly does nothing — it only *defines* functions (the usage examples live in comments at the foot of each file). The exception is the matching `tests/test-*.sh`, which you *do* run directly (`bash tests/test-eml-trace.sh`).

```bash
source ./eml-trace.sh      # defines the functions (prints nothing)
eml_trace mul 3 4          # then call one  →  watch × rebuilt from the eml operator
eml_recip_trace 1.5        # …or the Newton reciprocal, step by step
```

| Layer | `source` once | Functions to call |
|---|---|---|
| 1 — Boolean DSL / ALU | `./circuit-trace.sh` | `add_trace A B [Cin]` · `sub_trace A B` · `alu_trace OP A B` · `bits_show "BITS"` |
| 2 — EML operator | `./eml-trace.sh` | `eml_trace OP a b` · `eml_recip_trace x [iters] [y0]` · `eml_sin_trace x [terms]` |
| 3 — Math library | `./math-trace.sh` | `math_trace NAME args…` |
| 4 — Alt arithmetic | `./alt-arithmetic-trace.sh` | `peano_trace OP a b` · `church_trace N [int\|bits]` · `mod_trace OP a b n` · `mod_trace_pow base e n` |
| 5 — Combinator circuits | `./combinator-trace.sh` | `fold_trace F init "list"` · `scan_trace F init "list"` · `map_trace F "list"` · `fp_add_trace A B [Cin]` |
| 6 — Lambda / SKI | `./lambda.sh` | `lc_trace TERM` · `lc_show TERM` (also `lc_step`, `lc_normalize`) |
| Machines | `./turing-machine.sh` | `fsm_trace TABLE START INPUT` · `tm_trace TABLE HALTS START INPUT` |

Each viewer's `reference/*_TRACE.md` documents its functions in full; this table is the "what do I type" quick map. (For Layer 6 the reducer/`lc_show` live in `lambda.sh` itself; the machines' `fsm_trace`/`tm_trace` ship with their layer — the rest are dedicated `*-trace.sh` files.) Bit strings are LSB-first throughout.

## Repository layout

```
.                          ← source the scripts from here (so `source ./x.sh` just works)
├── *.sh                   the library: boolean-funcs-new · alt-arithmetic ·
│                            list-processing-kit · combinator-circuits · lambda ·
│                            state-machine · turing-machine · church-turing ·
│                            circuit-trace · eml-trace · math-trace ·
│                            alt-arithmetic-trace · combinator-trace  (viewers)
├── tests/                 one suite per script   (run: bash tests/test-*.sh)
├── reference/             function-by-function deep dives: OVERVIEW · BOOLEAN_DSL ·
│                            EML_OPERATOR · MATH_LIBRARY · ALT_ARITHMETIC ·
│                            LIST_PROCESSING_KIT · COMBINATOR_CIRCUITS · LAMBDA · LAMBDA_TRACE ·
│                            MACHINES · CIRCUIT_TRACE · EML_TRACE · MATH_TRACE ·
│                            ALT_ARITHMETIC_TRACE · COMBINATOR_TRACE
├── ETHOS.md               the project's ethos & guiding aim (why it's built this way)
├── TUTORIAL_*.md          the plain-English walkthroughs (Layers 1–8)
├── MANUAL_TESTING_IDEAS.md   interactive experiments to try by hand
└── TODO.md                the roadmap (the whole Church–Turing arc: done)
```

The scripts stay at the top level so every `source ./x.sh` example works as written;
the test suites and the reference docs each get their own folder.

## Tests

```bash
bash tests/test-boolean-funcs.sh
# 1022 passed, 0 failed
```

Coverage: all gate truth tables, the full Boolean-algebra axiom set verified exhaustively (commutativity, associativity, distributivity, identity, complement, annihilator, absorption, idempotence, involution, De Morgan), word-level bitwise ops and reductions (incl. complement reductions `nand_all`/`nor_all`/`xnor_all` as exact negations, `all`/`any`/`none` aliases, and two-word `and_any`/`or_any`/`xor_any` cross-checked against `bits_eq` and `is_zero`), the `mux`/`word_mux` selector and `bits_min`/`bits_max` over a full grid, word helpers and predicates (inc/dec/negate wrap and inverses, is_one/is_even/is_odd/is_negative, parity = popcount mod 2, bits_to_int round-trips), all 8 full-adder combinations, multi-bit ripple adders/subtractors (decoded sums and signed two's-complement results), magnitude comparators (full lt/eq/gt grids plus cascaded-priority edge cases), `int_to_bits` round-trips, logical shifts (plus arithmetic `sar` and cyclic `rol`/`ror`), the width-generic `word_add`/`word_sub` (cross-checked bit-for-bit against `ripple_add4`/`ripple_add8`/`ripple_sub4`, and run at 8- and 16-bit width), the `zero_extend`/`sign_extend`/`trunc_bits` width bridges, the `alu4` and `alu8` ALUs (every opcode plus Z/C/N/V flag cases — overflow, carry, borrow, zero), EML mutual inverses, arithmetic round-trips, EML applications (integer powers, Newton reciprocal vs `eml_div`, comparator-seeded `eml_recip_auto`, Taylor sine vs `bc`), trig/inverse-trig/hyperbolic round-trips, domain error cases. The numeric layers are pinned against **independent `bc` oracles**: the base `eml(x,y)` operator against `e(x)−ln(y)`, the EML ops (`+`, `−`, `×`, `÷`, `^`, `neg`, `exp`, `ln`) against plain `bc` arithmetic — proving the `exp(x)−ln(y)` construction rebuilds ordinary math — both `eml_recip` and `eml_recip_auto` against `bc`'s `1/x`, the inverse hyperbolics against their `ln`/`sqrt` closed forms, and the derived trig (`tan`/`cot`/`sec`/`csc`) against `bc`'s `s()`/`c()` ratios. The shared `e` constant in the suite is `bc`'s `e(1)`, not `eml_e`, so the EML "= e" checks never compare the layer to itself.

The slower / standalone layers have their own suites (all under `tests/`): `test-list-processing-kit.sh` (77 — the combinator kit alone, no Layer 1), `test-alt-arithmetic.sh` (142 — Peano / Church / modular), `test-combinator-circuits.sh` (111 — the function-side `fp_*` rebuilds, each checked bit-for-bit against its Layer-1 twin), `test-lambda.sh` (67 — SKI combinatory logic, cross-checked against the Church layer, incl. `lc_show`'s annotated reduction), `test-state-machine.sh` (37 — FSM verdicts vs ground truth), `test-turing-machine.sh` (40 — Turing machines, incl. binary-increment == `inc`), `test-church-turing.sh` (46 — the capstone: one function, every model, same answer), `test-circuit-trace.sh` (1118 — the Layer-1 viewer, every trace pinned against the real `word_add`/`word_sub`/`alu`), `test-alt-arithmetic-trace.sh` (131 — the Layer-4 viewer, pinned against the real `peano_*`/`church_*`/`mod_*`), `test-combinator-trace.sh` (75 — the Layer-5 viewer, pinned against the real `foldl`/`scanl`/`map`/`fp_word_add`), `test-eml-trace.sh` (22 — the Layer-2 viewer, pinned against the real `eml_*`), and `test-math-trace.sh` (21 — the Layer-3 viewer, pinned against the real library functions).

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
ripple_add4  ripple_add8       word_add  word_sub   # word_add/sub: width-generic
flip_bit  ripple_sub4  ripple_sub8
bit_to_bool  bits_eq  bits_gt  compare4  compare8
int_to_bits  zero_extend  sign_extend  trunc_bits

# Multiplexer, min & max
mux  word_mux  bits_min  bits_max

# Shifts & ALU
shl  shr  sar  rol  ror
alu4  alu8

# List accessors
lhead  ltail  first  second

# List-processing kit (list-processing-kit.sh — standalone)
map  mapcar  filter  foldl  foldr  foldl1  scanl
zipwith  zipwith3  zip  unzip  flatten
take  drop  take_while  drop_while  take_until  drop_until
lrange  lreverse  iterate  replicate  intercalate
any  all  none  count_if  elem  find_index
and_list  or_list  lsum  lproduct  complement  conj  disj

# Combinator circuits (combinator-circuits.sh — Layer 1, function-side)
bit_and  bit_or  bit_xor  bit_xor3
fp_word_not  fp_word_and  fp_word_or  fp_word_xor
fp_and_all  fp_or_all  fp_xor_all
fp_half_adder  fp_full_adder
fp_word_add  fp_word_add_scan  fp_carry_chain
fp_and_words  fp_or_words  fp_xor_words  fp_add_words
fp_shl  fp_shr  fp_rol  fp_ror

# Lambda calculus / SKI (lambda.sh)
applyc
SKI_I  SKI_K  SKI_S  SKI_B  SKI_C  SKI_W
LAMBDA_TRUE  LAMBDA_FALSE  LAMBDA_ZERO  LAMBDA_SUCC
lambda_church  lambda_church_to_int
lc_step  lc_normalize  lc_trace  lc_show  lc_church

# Finite state machine (state-machine.sh)
fsm_step  fsm_run  fsm_trace  fsm_accepts
FSM_PARITY  FSM_DIV3  FSM_SEQ101  FSM_TURNSTILE

# Turing machine (turing-machine.sh)
tm_step  tm_run  tm_trace  tm_steps
TM_UNARY_INC  TM_UNARY_ADD  TM_FLIP  TM_BINARY_INC  TM_PARITY  TM_BB2  TM_BB3

# The capstone — one function, every model (church-turing.sh)
ct_show_succ  ct_show_add  ct_demo
ct_succ_lambda  ct_succ_church  ct_succ_machine  ct_succ_circuit
ct_add_lambda   ct_add_church   ct_add_machine   ct_add_circuit
ct_church_to_bits_value

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
