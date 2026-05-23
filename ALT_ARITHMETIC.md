# Alternative Arithmetic — an experimental layer

The main stack answers *"how do you build math up from one tiny piece?"* twice:
**NAND** generates all of Boolean logic (Layer 1), and the **`eml`** operator
generates all of continuous math (Layer 2). This experimental layer
(`alt-arithmetic.sh`) asks a sideways version of the same question:

> What *is* a number, and how few ideas do you actually need to do arithmetic?

It collects several **nonstandard models of arithmetic** — different answers to
"what is a number" — and, where possible, wires each one back down into the
Boolean layer so you can watch foundations touch hardware.

```bash
source ./alt-arithmetic.sh   # pulls in boolean-funcs-new.sh automatically
bash test-alt-arithmetic.sh  # 56 passed, 0 failed  (~10s — see "speed" below)
```

> **A note on speed.** These models do arithmetic by *counting* — and the count
> often ripples through the gate layer. They are deliberately, gloriously slow;
> that slowness is the point, because it makes the foundations visible. For fast
> integer math use Layer 1 (`ripple_add4`, `alu4`); for real numbers, Layers 2–3.
> The models live in their own file and test suite so the fast 952-test core
> stays pristine.

---

## 1. Peano arithmetic — *number = zero + successor*

Giuseppe Peano's axioms define the natural numbers from just two things: a
constant **zero** and a **successor** function `S` ("+1"). Every number is a tower
of successors — `3` is `S(S(S(0)))` — and every operation is recursion that peels
successors off one argument. The recursion structure here is transliterated from
*The Little Schemer*.

The twist: **a Peano number is represented as a Layer-1 bit-string**, and the
three primitives *are the Boolean circuits from Tutorial 1*:

| Peano primitive | is literally | from |
|---|---|---|
| zero | `int_to_bits 0 W` | a width-W string of 0s |
| successor `S` | `inc` | the ripple-carry **+1** circuit |
| predecessor | `dec` | the ripple-borrow **−1** circuit |
| is-zero | `is_zero` | |
| less-than | `bits_gt` (swapped) | the magnitude comparator |

So "addition by counting" is performed, bit by bit, **by the gates**.

```bash
int_to_peano 3                                              # 1 1 0 0 0 0 0 0  (LSB-first bits)
peano_to_int "$(peano_add  "$(int_to_peano 2)" "$(int_to_peano 3)")"   # 5
peano_to_int "$(peano_mult "$(int_to_peano 3)" "$(int_to_peano 4)")"   # 12
peano_to_int "$(peano_div  "$(int_to_peano 13)" "$(int_to_peano 4)")"  # 3
peano_to_int "$(peano_expt "$(int_to_peano 2)" "$(int_to_peano 5)")"   # 32
```

Functions: `peano_zero` `peano_succ` `peano_pred` `peano_is_zero` `peano_lt`
`peano_add` `peano_sub` `peano_mult` `peano_div` `peano_expt`, plus bridges
`int_to_peano` / `peano_to_int`. Width defaults to `PEANO_W=8`.

Natural subtraction is only defined for `N1 ≥ N2`; going below zero **wraps**
(mod 2ᵂ) — which is exactly the modular model below.

---

## 2. Church numerals — *number = repeated application*

Alonzo Church's lambda-calculus encoding: a number `n` *is* a function that
applies some other function `f` to a value `x` exactly `n` times. `0` does nothing,
`3` does `f` three times. Numbers aren't things you store — they're **behaviours**.

True closure-based numerals aren't expressible in bash (functions don't survive
command-substitution subshells), so a numeral is realised as a repetition count —
but used **strictly as an iterator**, never as an operand of `+` or `*`. Successor
(`+1`) is the only arithmetic primitive; `add`/`mult`/`expt` are pure composition
of iteration:

```
add M N = apply succ, N times, to M
mul M N = apply (+M),  N times, to 0
exp B E = apply (×B),  E times, to 1
```

The higher-order heart survives: the central combinator `church_apply N F X`
iterates **any** unary function — including non-arithmetic ones, and including the
Layer-1 `inc` circuit, which is how a Church number reaches down and drives the
gates.

```bash
church_apply 5 church_succ 0     # 5      (apply +1 five times to 0)
church_apply 5 star ""           # *****  (star() appends "*": number as pure repetition)
church_add  2 3                  # 5
church_mult 3 4                  # 12
church_expt 2 5                  # 32
bits_to_int "$(church_to_bits 5)"  # 5    ← the numeral drove Layer-1 inc to build bits
```

Functions: `church_zero` `church_one` `church_succ` `church_is_zero`
`church_apply` `church_add` `church_mult` `church_expt`, bridges
`int_to_church` / `church_to_int` / `church_to_bits`.

---

## 3. Modular / clock arithmetic — *number = a position on a clock of n*

Arithmetic in ℤ/nℤ: count past `n−1` and you wrap to `0` (10 + 5 on a 12-hour
clock is 3). This finite system isn't exotic — **it is what the hardware already
does.** A fixed width of `W` bits holds only `0…2ᵂ−1`, so binary addition that
keeps `W` bits *is* arithmetic mod 2ᵂ, and the ALU's carry-out/overflow is the
clock hand sweeping past the top.

```bash
mod_add 10 5 12        # 3      (clock arithmetic)
mod_sub 2 5 12         # 9
mod_pow 2 10 1000      # 24     (2^10 = 1024 ≡ 24;  by repeated squaring)
mod_inverse 3 7        # 5      (3·5 = 15 ≡ 1 mod 7;  extended Euclid)
mod_inverse 4 6        # none   (gcd(4,6) = 2, so no inverse)

# the cross-layer punchline: the Layer-1 4-bit ripple adder IS mod-16 arithmetic
mod_add_bits4 12 11    # 7      (= 23 mod 16, computed by the gates)
```

Functions: `mod_reduce` `mod_add` `mod_sub` `mod_mul` `mod_pow` `mod_inverse`
`mod_add_bits4`.

---

## How the models connect to the stack

Each model bottoms out in Layer 1, so they aren't islands:

- **Peano** *is* Layer 1 — its successor/predecessor/zero/compare are the ripple
  adder, borrow subtractor, and comparator.
- **Church** reaches Layer 1 through `church_to_bits`: hand a numeral the `inc`
  circuit and it builds the bit-string by self-iteration.
- **Modular** *describes* Layer 1 — fixed-width binary already is ℤ/2ᵂℤ, made
  literal by `mod_add_bits4`.

Three different answers to "what is a number" — a successor tower, a behaviour, a
clock position — and all three meet the same gates underneath.

---

## Possible future models

Not built yet, but natural next experiments in the same file:

- **Balanced ternary** — base 3 with digits {−, 0, +}; negatives for free,
  symmetric rounding (the Soviet *Setun* computer used it).
- **Zeckendorf / Fibonacci base** — every number as a unique sum of
  non-consecutive Fibonacci numbers, with its own carry rules.
- **Bijective base-k**, **continued fractions**, **Gödel numbering** — other
  representations worth poking at.
