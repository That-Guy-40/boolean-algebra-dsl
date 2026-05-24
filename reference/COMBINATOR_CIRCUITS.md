# Combinator Circuits — Layer 1, rebuilt from the function side

`combinator-circuits.sh` rebuilds Layer 1's word operations a second way: not as
imperative loops over a bit array, but as one-line **maps, zipwiths, folds, and
scans** from `list-processing-kit.sh`. Every reconstruction is named `fp_*`
(function-side) and is checked **bit-for-bit** against the Layer-1 original in
`test-combinator-circuits.sh` (111 passing).

*New to the idea? [`TUTORIAL_LAYER5_COMBINATORS.md`](../TUTORIAL_LAYER5_COMBINATORS.md) is
the plain-English, no-math walkthrough; this file is the precise reference.*

This is the project's *combinator payoff*: the **machine side** (a loop walking the
bits) and the **function side** (a fold over the bit list) compute the identical
circuit. Proving they agree is a Church–Turing wink in miniature — and it still
bottoms out in the very same NAND-built gates, since the bit combiners only bridge
`0/1` to the `true`/`false` the gates speak.

## Loading

```bash
source ./combinator-circuits.sh   # pulls in boolean-funcs-new.sh + list-processing-kit.sh
```

Layer 1 loads first and the kit last, so the kit's list combinators (`map`/`foldl`/…)
win the handful of name clashes (`all`/`any`/`lhead`) while Layer 1's gates and
`and_all`/`or_all`/`word_*`/`ripple_*` stay reachable for the cross-checks. (Same
arrangement `alt-arithmetic.sh` uses.)

## The reconstructions

| function side (`fp_*`) | built from | equals (Layer 1) |
|---|---|---|
| `fp_word_not a`         | `map flip_bit`                       | `word_not` |
| `fp_word_and a b`       | `zipwith bit_and`                    | `word_and` |
| `fp_word_or  a b`       | `zipwith bit_or`                     | `word_or`  |
| `fp_word_xor a b`       | `zipwith bit_xor`                    | `word_xor` |
| `fp_and_all w`          | `and_list ∘ map bit_to_bool`         | `and_all`  |
| `fp_or_all  w`          | `or_list  ∘ map bit_to_bool`         | `or_all`   |
| `fp_xor_all w`          | `foldl ne false ∘ map bit_to_bool`   | `xor_all`  |
| `fp_half_adder a b`     | `bit_xor`, `bit_and`                 | `half_adder` |
| `fp_full_adder a b cin` | two `fp_half_adder`s + `bit_or`      | `full_adder` |
| `fp_word_add a b [cin]` | **`foldl` threading the carry**      | `word_add` |
| `fp_word_add_scan a b`  | **`scanl` carry chain + `zipwith3`** | `word_add` |
| `fp_carry_chain a b`    | **`scanl`** of the carry             | *(diagnostic)* |
| `fp_shl/shr/rol/ror`    | `take`/`drop`/`replicate`            | `shl`/`shr`/`rol`/`ror` |
| `fp_and_words …` etc.   | fold a word op over `"$@"`           | n-ary AND/OR/XOR |
| `fp_add_words …`        | fold `fp_word_add` over `"$@"`       | n-ary sum |

The bit-level gates `bit_and`/`bit_or`/`bit_xor` (and the 3-input `bit_xor3`) are the
only glue: they wrap the Layer-1 gates so they take and return `0/1` instead of
`true/false`. `flip_bit` is already bit-native, so `fp_word_not` is a bare
`map flip_bit`.

## The centerpiece — addition is a one-line recurrence

A ripple adder is a **left fold that threads the carry**. Zip the operands into
bit-pairs, carry an accumulator `(carry, sum-so-far)`, and at each pair run a full
adder:

```bash
fp_word_add "1 1 0 0" "1 0 1 0"   # 3 + 5 -> "0 0 0 1 0" (= 8), identical to word_add
```

`scanl` keeps every intermediate accumulator, so it can expose the **carry chain** —
the carry rippling in at each position (ending with the carry-out):

```bash
fp_carry_chain "$(int_to_bits 3 4)" "$(int_to_bits 5 4)"   # 0 1 1 1 0   (Cin c1 c2 c3 Cout)
```

And once the carry into every bit is known, each sum bit is just
`aᵢ ⊕ bᵢ ⊕ carry_inᵢ` — a single `zipwith3`. That gives a *second* function-side
adder (`fp_word_add_scan`), and the suite proves it all agrees:

> `word_add` (Layer-1 loop) **==** `fp_word_add` (foldl) **==** `fp_word_add_scan`
> (scanl + zipwith3) **==** `ripple_add8` (chained nibbles) — **four constructions,
> one answer.**

## n-ary gates, arbitrary width

A 2-input gate becomes **n-ary by folding it over a list**:

- over the **bits of one word**, that fold *is* `fp_and_all`/`fp_or_all`/`fp_xor_all`
  — an N-input AND/OR/XOR gate. Width is arbitrary precisely because it is a fold
  over a list (4-, 8-, 16-bit, … with no change).
- over several **words**, `fp_and_words`/`fp_or_words`/`fp_xor_words`/`fp_add_words`
  fold a word op across the argument list. (Words contain spaces, so they can't be
  kit-list atoms — the fold runs over `"$@"`.)

```bash
fp_and_words "$(int_to_bits 15 4)" "$(int_to_bits 14 4)" "$(int_to_bits 12 4)"             # 0 0 1 1  (= 12)
bits_to_int "$(fp_add_words "$(int_to_bits 3 4)" "$(int_to_bits 5 4)" "$(int_to_bits 4 4)")"  # 12
```

## Shifts as pure list surgery

No arithmetic — just slice and pad. LSB-first, so a left shift pads a `0` at the
front and drops the top; a right shift drops the front and pads at the top; rotates
carry the wrapped slice around instead of dropping it:

```bash
fp_shl "$(int_to_bits 3 8)"        # 3 << 1 = 6, same as shl
fp_rol "$(int_to_bits 201 8)" 3    # cyclic rotate left by 3, same as rol
```

## Tests

```bash
bash tests/test-combinator-circuits.sh   # 111 passed, 0 failed   (slow: gate-level subshells)
bash tests/test-list-processing-kit.sh   #  77 passed, 0 failed   (the generic kit, standalone)
```

The combinator suite asserts each `fp_*` equals its Layer-1 twin across 4- and 8-bit
grids (and that the three adder constructions agree); the kit suite exercises the
generic combinators (`none`/`count_if`/`and_list`/`complement`/`zipwith3`/…) with no
Layer-1 dependency at all.
