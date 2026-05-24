# Circuit Trace — a viewer for Layer 1 (the carry you couldn't see)

Layer 1's adders and ALU hand you the **answer** but hide the **journey** — you never
see the carry ripple from bit to bit, or watch the status flags get decided. This is a
**read-only viewer** over the gates, in the spirit of `fsm_trace` / `tm_trace`: it
changes *nothing* in the pristine core (`boolean-funcs-new.sh`) and re-runs the **same
`full_adder`** the real adder uses, one bit at a time — so the picture it draws can
never drift from the circuit. Lives in `circuit-trace.sh`.

Bit strings are **LSB-first**, exactly as everywhere else in the project.

## Loading

```bash
source ./circuit-trace.sh        # sources boolean-funcs-new.sh (the gates) for you
```

## The functions

| function | shows |
|---|---|
| `add_trace A B [Cin]` | the ripple-carry adder as a per-bit table — equals `word_add` |
| `sub_trace A B`       | subtraction as the two's-complement add `A + (¬B) + 1` — equals `word_sub` |
| `alu_trace OP A B`    | the ALU dashboard: result + decoded `Z` / `C` / `N` / `V` flags |
| `bits_show "BITS"`    | a bit string with its decimal value, e.g. `1 0 1 0  (=5)` |

## `add_trace` — watch the carry ripple

One row per bit, least-significant first. Each row is a real `full_adder` call; its
**Cout** becomes the next row's **Cin**, and a `◄ carry in` marker flags where a carry
rippled in.

```bash
add_trace "1 0 1 0" "0 1 1 0"      # 5 + 6
```
```
  ripple-carry ADD — LSB-first

  A   = 1 0 1 0  (=5)
  B   = 0 1 1 0  (=6)
  Cin = 0

  bit │ A  B  Cin → Sum  Cout
  ────┼─────────────────────
   0  │ 1  0   0  →  1     0
   1  │ 0  1   0  →  1     0
   2  │ 1  1   0  →  0     1
   3  │ 0  0   1  →  1     0   ◄ carry in from bit 2
  ────┴─────────────────────
  Sum = 1 1 0 1  (=11)   Cout = 0
```

A carry off the top (e.g. `15 + 1`) is called out as overflow beyond the word width.
Width is generic — `max(|A|,|B|)`, the shorter operand zero-extended.

## `sub_trace` — subtraction is just addition in disguise

It shows the standard trick: `A − B = A + (¬B) + 1`. It prints `¬B`, runs the same
ripple table with `Cin = 1`, then reads the final carry the way a subtractor does —
**Cout = 1 → no borrow (A ≥ B)**, **Cout = 0 → borrow (A < B)**.

```bash
sub_trace "1 0 1 0" "1 1 0 0"      # 5 - 3  ->  ends "no borrow (A ≥ B)", result 0 1 0 0 (=2)
```

## `alu_trace` — the dashboard with decoded flags

Runs the **real** `alu4` (or `alu8`, chosen by operand width) and decodes the four
status flags into plain English. For `add` / `sub` it also embeds the ripple trace of
the data path. Ops: `add sub and or xor not slt shl shr`.

```bash
alu_trace add "1 0 1 0" "0 1 1 0"      # 5 + 6
```
```
  ══ ALU (4-bit)  op = add ══
    A      = 1 0 1 0  (=5)
    B      = 0 1 1 0  (=6)
    result = 1 1 0 1  (=11)

    Z = 0  result is non-zero
    C = 0  no carry-out
    N = 1  negative (sign bit set)
    V = 1  signed overflow
    … (then the ripple-carry table for the add)
```

The flags decode per op: `C` is the carry-out for `add`, "no borrow / borrow" for
`sub`, and "the bit shifted out" for `shl` / `shr`; `Z` is zero, `N` the sign bit, `V`
signed overflow. (Here `11` overflows signed 4-bit — it reads as `−5` — so `N` and `V`
both fire: a real teaching moment the bare `alu4` output only hints at.)

## Why it can't lie

The viewer never re-implements the math — `add_trace` threads real `full_adder`s,
`sub_trace` builds on it, and `alu_trace` calls the real `alu4` / `alu8`. The test
suite pins every trace's reported result and flags against an **independent** `word_add`
/ `word_sub` / `alu` computation across a sweep of inputs (and the 8-bit dispatch), so
the drawing is guaranteed faithful to the circuit.

## Tests

```bash
bash tests/test-circuit-trace.sh     # 1118 passed, 0 failed   (standalone; ~40s)
```

A standalone (non-core) suite, kept separate from the fast core per the project
convention.

---

*This is a viewer over **Layer 1** — see [`BOOLEAN_DSL.md`](BOOLEAN_DSL.md) for the gates,
adders, and ALU it traces, and [`../TUTORIAL_LAYER1.md`](../TUTORIAL_LAYER1.md) for the
plain-English build. It's the same idea as the machine-layer traces in
[`MACHINES.md`](MACHINES.md) (`fsm_trace` / `tm_trace`), pointed back at the gates. For
every layer at once, see [`OVERVIEW.md`](OVERVIEW.md).*
