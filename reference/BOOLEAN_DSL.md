# Boolean DSL — Layer 1 (gates → arithmetic → a working ALU)

The foundation the whole project bottoms out in. From a single logic gate (**NAND**) it
grows the full Boolean algebra, lifts it to bit-vectors, and from there builds
ripple-carry arithmetic, comparison, shifting, and a small **arithmetic-logic unit** — a
working processor data path, in pure Bash. Lives in `boolean-funcs-new.sh`; the
plain-English walkthrough is [`../TUTORIAL_LAYER1.md`](../TUTORIAL_LAYER1.md).

## Loading

```bash
source ./boolean-funcs-new.sh
```

## Two conventions

- **Truth is an exit code.** A gate returns `0` = success = **true**, nonzero = **false**
  — so `if and "$a" "$b"; then …` reads naturally. It *also* echoes the string
  `"true"`/`"false"`, so a result can be captured with `$(…)` and passed to another gate.
- **Numbers are LSB-first bit strings.** A multi-bit value is a space-separated string of
  `0`/`1`, least-significant bit first: `"1 0 1"` = 1 + 0·2 + 1·4 = 5. `int_to_bits` /
  `bits_to_int` convert to and from decimal.

> **Mind the seam:** gates speak `true`/`false`, words speak `0`/`1`, and the two `0`s
> mean *opposite* things (exit-code `0` = true; bit `0` = false). `bit_to_bool` /
> `bool_to_bit` bridge them — and the project's one historical bug lived right here.

## Gates — everything from NAND

`nand` is the single primitive; every other gate is derived from it:

```
nand(A,A)            → not
not(nand(A,B))       → and
nand(not A, not B)   → or       (De Morgan)
not(or(A,B))         → nor
```

| gate | logic | only false when |
|---|---|---|
| `nand A B` | ¬(A∧B) | both true |
| `not A` | ¬A | A true |
| `and A B` | A∧B | either false |
| `or A B` | A∨B | both false |
| `nor A B` | ¬(A∨B) | either true |
| `ne A B` | A⊕B (XOR) | inputs match |
| `eq A B` | A↔B (XNOR) | inputs differ |
| `if_then A B` / `then_if A B` | A→B / B→A | implication |
| `if_and_only_if A B` | A↔B | inputs differ |
| `or_nand A B` | A∨B | both false (alternate build) |

```bash
and true false           # false        not "$(or true false)"   # false
ne true false            # true   (they differ)
```

## A genuine Boolean algebra

`(or, and, not, false, true)` is not just a gate zoo — it satisfies the **axioms of a
Boolean algebra**, each verified *exhaustively over every input assignment* by the test
suite: commutativity, associativity, distributivity (both ways), identity (`A∨0=A`,
`A∧1=A`), complement (`A∨¬A=1`, `A∧¬A=0`), annihilator, absorption, idempotence,
involution, and De Morgan.

## Words — bitwise ops & reductions

The algebra lifts from single bits to whole **words**. `word_zip GATE A B` applies any
gate position-wise; `word_not` / `word_and` / `word_or` / `word_xor` are the named cases.
The **reductions** fold a word down to one Boolean:

| reduction | meaning |
|---|---|
| `and_all` / `or_all` / `xor_all` | ∀ set / ∃ set / odd parity |
| `is_zero` | `= ¬or_all` (the ALU's zero flag) |
| `nand_all` / `nor_all` / `xnor_all` | the complements (`xnor_all` = even parity) |
| `all` / `any` / `none` | readable aliases |
| `and_any` / `or_any` / `xor_any A B` | ∃ a position where `A op B` (mask tests; `xor_any` = `¬bits_eq`) |

```bash
word_and "1 1 0 0" "1 0 1 0"   # 1 0 0 0
xor_all  "1 1 0 1"             # true   (odd parity)
and_any  "1 1 0 0" "1 0 1 0"   # true   (masks share bit 0)
```

## Word helpers & predicates

| group | functions | notes |
|---|---|---|
| unit arithmetic | `inc` `dec` `negate` | width-preserving (wrap two's-complement); `inc` is a half-adder carry ripple, `negate` = `¬W` then `inc` |
| predicates | `is_zero` `is_one` `is_even` `is_odd` `is_negative` | true/false + exit code; `is_even` reads the LSB, `is_negative` the MSB |
| readouts | `parity` `popcount` `lsb` `msb` `int_to_bits` `bits_to_int` | `parity` = popcount mod 2; `int_to_bits N [W]` ↔ `bits_to_int` round-trip |

```bash
inc "1 1 0 0"          # 0 0 1 0   (3 + 1 = 4)
negate "1 1 0 0"       # 1 0 1 1   (-3, two's complement)
popcount "1 1 1 0"     # 3
```

## Adders

Built from gates, bottom-up: `half_adder A B` (sum = XOR, carry = AND) → `full_adder A B Cin`
(two half adders + an OR) → `ripple_add4` / `ripple_add8` (chain N full adders, threading
each carry into the next). All LSB-first; inputs accept `0`/`1` or `true`/`false`; the
output is the W sum bits then the carry-out.

```bash
half_adder 1 1                 # 0 1
ripple_add4 1 1 0 0 1 0 1 0    # 0 0 0 1 0     (3 + 5 = 8)
```

`word_add` / `word_sub` are the **width-generic** versions: the same ripple-carry, but
over two bit *strings* of any width (4-, 8-, 16-bit, …), so no 17-positional-argument
calls. Output keeps the "result bits + carry-out" convention.

```bash
bits_to_int "$(word_add "$(int_to_bits 200 8)" "$(int_to_bits 100 8)")"   # 300
```

## Subtractors

Two's complement: `A − B = A + (¬B) + 1`. `flip_bit` inverts a bit; `ripple_sub4` /
`ripple_sub8` flip B's bits and run the adder with carry-in 1. The trailing carry-out
doubles as the **borrow flag**: `1` = no borrow (`A ≥ B`), `0` = borrow (`A < B`, and the
result is the two's-complement negative).

```bash
ripple_sub4 1 0 1 0 1 1 0 0    # 0 1 0 0 1     (5 − 3 = 2, no borrow)
```

## Comparators

`bits_eq A B` is the XNOR of every bit-pair, all ANDed together. `bits_gt A B` uses
**cascaded priority** from the MSB down — the first bit position where the two differ
decides — so a single high bit outweighs any number of lower bits. Both echo true/false
+ exit code (width-generic). `compare4` / `compare8` are positional wrappers echoing
`lt` / `eq` / `gt`. (Less-than needs no function of its own: it is `bits_gt B A`.)

```bash
compare4 0 0 0 1 1 1 1 0    # gt   (8 > 7, decided at the most significant bit)
```

## Multiplexer, min, max

`mux SEL A B` is the gate-level 2:1 selector (`(¬SEL ∧ A) ∨ (SEL ∧ B)`); `word_mux` runs
it across a word with a shared select line. `bits_min` / `bits_max` compose the
comparator (which picks the select line) with the mux (which routes the operand).

```bash
mux 1 1 0                       # 0   (SEL=1 → second input)
bits_min "1 1 0 0" "1 0 1 0"    # 1 1 0 0   (min(3, 5) = 3)
```

## Shifts, rotates, width bridges

| op | effect |
|---|---|
| `shl` / `shr` | logical shift (×2 / ÷2), width-preserving, vacated bits = 0 |
| `sar` | arithmetic right shift — replicates the sign bit (signed ÷2) |
| `rol` / `ror` | cyclic rotate (nothing lost) |
| `zero_extend` / `sign_extend` / `trunc_bits` | move a value between widths |

```bash
shl "1 1 0 0"                          # 0 1 1 0           (3 → 6)
sign_extend "$(int_to_bits 12 4)" 8    # 0 0 1 1 1 1 1 1   (-4, signed value preserved)
```

## The ALU — the capstone

`alu4 OP A0..A3 B0..B3` (and the byte-wide `alu8`) tie the whole layer into one box.
`OP ∈ add sub and or xor not slt shl shr`; the output is `R0..R{w-1} Z C N V` — the
result bits then four status flags (**Z**ero, **C**arry, **N**egative, o**V**erflow),
computed the way real hardware does, over a data path that is *entirely* the circuits
above.

```bash
alu4 add 1 1 0 0 1 0 1 0    # 0 0 0 1 0  0 0 1 1   (3+5=8: V,N set — 8 overflows signed 4-bit)
alu4 sub 1 0 1 0 1 1 0 0    # 0 1 0 0 0  1 0 0 0   (5−3=2: C=1, no borrow)
```

## Tests

```bash
bash tests/test-boolean-funcs.sh    # 1022 passed, 0 failed
```

Exhaustive: every gate truth table, the full Boolean-algebra axiom set over all
assignments, the word ops and reductions, all adder/subtractor/comparator cases (decoded
sums, signed two's-complement results, full lt/eq/gt grids, cascaded-priority edge cases),
the width-generic `word_add`/`word_sub` cross-checked bit-for-bit against the fixed-width
ripple adders, shifts/rotates/width-bridges, and every `alu4`/`alu8` opcode and flag.

---

*Plain-English walkthrough: [`../TUTORIAL_LAYER1.md`](../TUTORIAL_LAYER1.md). This is the
bottom of the stack — [`EML_OPERATOR.md`](EML_OPERATOR.md) (Layer 2) pulls the same
"everything from one primitive" trick for continuous math, and the function-side rebuild
of these very circuits lives in [`COMBINATOR_CIRCUITS.md`](COMBINATOR_CIRCUITS.md). For
every layer in one document, see [`OVERVIEW.md`](OVERVIEW.md).*
