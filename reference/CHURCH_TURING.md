# Church–Turing — One Function, Every Model, The Same Answer

The **capstone** (`church-turing.sh`). The project spent its layers building "computing"
out of wildly different stuff — logic gates, a single `eml` operator, iterated
composition, three combinators, a tape and a rule-follower. This file pits them against
each other: it computes the **same function on every model** and shows they all land on
the same answer. That different definitions of "computable" agree is the **Church–Turing
thesis**; that they all bottom out in the same NAND gates is this project's running theme,
carried to its conclusion.

```
       the FUNCTION side                    the MACHINE side
     ┌──────────────────────┐            ┌──────────────────────┐
     │ pure lambda  (SKI)    │            │ a Turing machine     │
     │ Church numerals       │            │ (bounded tape)       │
     └──────────────────────┘            └──────────────────────┘
                      ╲                  ╱
                       ╲                ╱
                     the CIRCUIT side: Layer-1 logic gates
```

Two functions are each computed **four ways**: the **successor** `n → n+1`, and
**addition** `n + m`. `test-church-turing.sh` (46 passing) asserts the four answers match
for a range of inputs — the point of the whole project, pinned.

## Loading

```bash
source ./church-turing.sh
```

That one line loads *everything* the project built. It sources `alt-arithmetic.sh`
(Church numerals + the Layer-1 gates + the list kit), `lambda.sh` (pure lambda / SKI), and
`turing-machine.sh` (the FSM and the tape machine) — in that order, which is the same one
`alt-arithmetic.sh` already relies on to settle the kit-vs-Layer-1 name clashes
(`all`/`any`/`lhead`/`ltail`). `CT_WIDTH` (default `12`) is the bit width used for the
circuit and binary-tape number representations — room to grow past the small demo inputs.

## The headline — side-by-side, four ways

`ct_show_succ` and `ct_show_add` run all four models and print their verdicts in a column,
with a final agreement line:

```bash
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

```bash
ct_show_add 3 4
```
```
3 + 4  ->  7
  function side  ·  pure lambda / SKI (SUCC x m)     : 7
  function side  ·  Church numeral   (church_plus)   : 7
  machine side   ·  Turing machine   (TM_UNARY_ADD)  : 7
  circuit        ·  Layer-1 gates    (word_add)      : 7
  => all four models agree
```

`ct_demo` runs the whole show — successor and addition at a couple of inputs each, plus the
function→circuit handshake below:

```bash
ct_demo
```

## The four models, one per row

Each model is also exposed as a bare function returning a plain integer, so you can drive
them yourself (the `ct_show_*` functions above are just these four, printed together).

**Successor `n → n+1`:**

| model | function | how it computes |
|---|---|---|
| function · pure lambda / SKI | `ct_succ_lambda N`  | `apply` `LAMBDA_SUCC` (= `S B`) to the numeral `lambda_church N`, read back |
| function · Church numeral    | `ct_succ_church N`  | `church_succ` of `int_to_church N` |
| machine · Turing machine     | `ct_succ_machine N` | `tm_run TM_BINARY_INC` over `int_to_bits N` (the carry ripple, walked along a tape) |
| circuit · Layer-1 gates      | `ct_succ_circuit N` | `inc` of `int_to_bits N` (the ripple-carry **+1**) |

**Addition `n + m`:**

| model | function | how it computes |
|---|---|---|
| function · pure lambda / SKI | `ct_add_lambda N M`  | start at numeral `N`, `apply` `LAMBDA_SUCC` `M` times |
| function · Church numeral    | `ct_add_church N M`  | `church_plus` of `int_to_church N` and `int_to_church M` |
| machine · Turing machine     | `ct_add_machine N M` | `tm_run TM_UNARY_ADD` over `N` tallies `+` `M` tallies, then count the `1`s |
| circuit · Layer-1 gates      | `ct_add_circuit N M` | `word_add` of the two `int_to_bits` words |

```bash
ct_succ_machine 5     # 6     (a tape gadget)
ct_succ_circuit 5     # 6     (a gate circuit) — same answer, no shared parts
ct_add_lambda 3 4     # 7     (three SUCCs is 3; four more SUCCs lands on 7)
ct_add_church 3 4     # 7
```

Note the two halves of the **machine side** even use *different tape encodings*: successor
runs on a binary tape (`TM_BINARY_INC`, the carry ripple) while addition runs on a unary
tally tape (`TM_UNARY_ADD`, walk to the end and join the two runs of marks). Two
representations, one machine model, still agreeing with the other three.

## The handshake — a pure function reaches into the hardware

The literal cross-side moment. A Church numeral is a **pure function**; `church_to_bits`
hands it the real Layer-1 `inc` circuit and lets it **build its own bit pattern** by
self-iteration, starting from all-zeros. `ct_church_to_bits_value` decodes the result:

```bash
ct_church_to_bits_value 5     # 5
```

The number 5 — living as "do-it-five-times" — drove the `+1` gate circuit five times to
construct the bits for 5. The function side didn't just *match* the circuit side; it
**worked it**. (This is `church_to_bits` from `alt-arithmetic.sh`, surfaced here as the
capstone's punchline.)

## A note on speed

The lambda and Church contestants do their arithmetic by **actually counting through the
gates** (and lambda composition nests its escaping as it goes), so they are gloriously
slow — keep the inputs small. That slowness is the point: it makes the foundations
visible. The circuit and tape models are the fast ones if you only want the answer.

## Tests

```bash
bash tests/test-church-turing.sh    # 46 passed, 0 failed
```

The suite asserts the four models agree on `succ n` for `n ∈ {0,1,2,5,8}`, on `n + m` for
several pairs, that `church_to_bits` round-trips through the gates, and — as a single
cross-model assertion — that `sort -u` of all four successor answers collapses to one value.

---

*This is the precise reference; the plain-English finale is
[`../TUTORIAL_LAYER8_CHURCH_TURING.md`](../TUTORIAL_LAYER8_CHURCH_TURING.md) (four
contestants, one contest). The two sides it joins have their own docs —
[`LAMBDA.md`](LAMBDA.md) and [`ALT_ARITHMETIC.md`](ALT_ARITHMETIC.md) (function side),
[`MACHINES.md`](MACHINES.md) (machine side), [`BOOLEAN_DSL.md`](BOOLEAN_DSL.md) (the gates
underneath). For every layer at once, see [`OVERVIEW.md`](OVERVIEW.md).*
</content>
</invoke>
