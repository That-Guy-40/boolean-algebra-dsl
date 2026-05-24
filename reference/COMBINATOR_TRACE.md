# Combinator Trace — a viewer for Layer 5 (the adder, revealed as a fold)

Layer 5 rebuilds Layer-1's word ops from the **function side** — `map` / `zipwith` /
`foldl` / `scanl` (`combinator-circuits.sh`, on `list-processing-kit.sh`). Its headline
is that the ripple-carry adder is just a **left fold threading the carry**. This
**read-only viewer** makes that visible: `fp_add_trace` draws the very same carry ripple
that [`add_trace`](CIRCUIT_TRACE.md) drew for the gates — but as a fold (the project's
Church–Turing wink, made concrete). It changes nothing in Layer 5 and drives the **same
combinators** (`apply2`, the real `_fp_add_step` / `fp_carry_chain`), so the picture
stays faithful. Lives in `combinator-trace.sh`.

Lists and bit strings are **LSB-first**, space-separated, as everywhere in the project.

## Loading

```bash
source ./combinator-trace.sh        # sources combinator-circuits.sh (+ the kit + Layer 1)
```

## The functions

| function | shows |
|---|---|
| `fold_trace F init "list"` | `foldl` collapsing a list left-to-right, one step per row |
| `scan_trace F init "list"` | the same, but keeping **every** running accumulator (`scanl`) |
| `map_trace F "list"`       | `F` applied to each element independently |
| `fp_add_trace A B [Cin]`   | the ripple adder rebuilt as a carry-threading `foldl` |

`F` is a kit "fn value" (`'echo $(($1+$2))'`) **or** a bare command name (`flip_bit`) —
the same two forms the kit's `foldl`/`map` accept.

## `fold_trace` / `scan_trace` — a list, collapsed

A left fold seeds an accumulator and updates it with `F(acc, x)` for each element. (This
is also exactly what an FSM run is — see [`MACHINES.md`](MACHINES.md) — so the same trace
shape recurs across the project.)

```bash
fold_trace 'echo $(($1+$2))' 0 '1 2 3 4 5'     # sum -> 15
```
```
  foldl  —  acc starts at init, then  acc = F(acc, x)  for each x, left to right
  F = echo $(($1+$2))   init = 0   list = [1 2 3 4 5]

  step  element   acc-in        →  acc-out
  ──────────────────────────────────────────
    1    1        0            →  1
    2    2        1            →  3
    …
  result = 15   (= foldl F init list)
```

`scan_trace` is the same fold but prints the running accumulator after every element
(`0 1 3 6 10`) — the difference between `foldl` (the last value) and `scanl` (all of them).

## `map_trace` — element by element

```bash
map_trace flip_bit '1 0 1 1'        # = word_not  ->  0 1 0 0
```
```
  map  —  apply F to each element on its own (no accumulator)
    1      → 0
    0      → 1
    …
  result = 0 1 0 0   (= map F list)
```

## `fp_add_trace` — the ripple adder *is* a fold

The star. `fp_word_add` is literally `foldl _fp_add_step "Cin|" (zip A B)`: the
accumulator is `"carry|sum-bits"`, and each step folds one bit-pair `a:b` through a full
adder, threading the carry forward. The trace shows that accumulator evolving:

```bash
fp_add_trace "1 0 1 0" "0 1 1 0"        # 5 + 6
```
```
  fp_word_add — the ripple adder rebuilt as  foldl _fp_add_step "0|" (zip A B)
  A = 1 0 1 0  (=5)
  B = 0 1 1 0  (=6)
  accumulator = "carry|sum-bits"; each step folds one pair a:b through fp_full_adder.

  bit  a:b   acc-in          sum  cout    acc-out
  ──────────────────────────────────────────────────────
   0   1:0   0|              1    0     0|1
   1   0:1   0|1             1    0     0|1 1
   2   1:1   0|1 1           0    1     1|1 1 0
   3   0:0   1|1 1 0         1    0     0|1 1 0 1
  ──────────────────────────────────────────────────────
  fold result = 0|1 1 0 1   →   Sum = 1 1 0 1  (=11)   Cout = 0
  carry chain (scanl): 0 0 0 1 0   — the carry rippling IN at each bit, then the Cout
```

Compare the `Cout` column to the **identical** ripple in [`CIRCUIT_TRACE.md`](CIRCUIT_TRACE.md)'s
`add_trace` for `5 + 6`: a machine-style loop over the gates and a function-style fold,
the same carry, the same answer. The `carry chain` line is `fp_carry_chain` — the `scanl`
that exposes the carry into every bit position.

## Why it can't lie

The viewer never re-implements anything: `fold_trace`/`scan_trace`/`map_trace` drive the
kit's own `apply2`/`apply` (so they match `foldl`/`scanl`/`map`), and `fp_add_trace` folds
with the **real** `_fp_add_step`. The test suite pins every trace's reported result
against an independent call to `foldl` / `scanl` / `map` / `fp_word_add` over a sweep.

## Tests

```bash
bash tests/test-combinator-trace.sh    # 75 passed, 0 failed   (standalone)
```

A standalone (non-core) suite kept separate from the fast core per the project convention.

---

*This is a viewer over **Layer 5** — see [`COMBINATOR_CIRCUITS.md`](COMBINATOR_CIRCUITS.md)
for the `fp_*` rebuilds it traces and [`LIST_PROCESSING_KIT.md`](LIST_PROCESSING_KIT.md)
for the combinators, with the plain-English build in
[`../TUTORIAL_LAYER5_COMBINATORS.md`](../TUTORIAL_LAYER5_COMBINATORS.md). It's the
function-side twin of the Layer-1 viewer [`CIRCUIT_TRACE.md`](CIRCUIT_TRACE.md) and the
Layer-4 viewer [`ALT_ARITHMETIC_TRACE.md`](ALT_ARITHMETIC_TRACE.md). For every layer at
once, see [`OVERVIEW.md`](OVERVIEW.md).*
