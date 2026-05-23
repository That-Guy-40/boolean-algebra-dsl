# Project TODOs / Roadmap

**North star:** demonstrate the **Church–Turing thesis** *in action* — show that the
two great models of computation, the **machine** side (a Turing machine) and the
**function** side (the lambda calculus), compute the very same things. The project
already has both halves in embryo: the circuit side (gates → ripple adder → `alu4`)
and the function side (the combinator layer + Church numerals/booleans/pairs in
`alt-arithmetic.sh`). These TODOs build the missing pieces and then join them.

**Working convention** (so each layer stays understandable and self-contained):
- Each new layer gets **its own `.sh` file**, sourcing what it builds on.
- Each gets **its own test file** (`test-*.sh`), kept out of the fast 952-test core
  if it's slow/experimental.
- Each eventually gets a **plain-English `TUTORIAL_*.md`** in the Layer 1–3 voice.
- **Wire down** into existing layers wherever natural (the recurring theme: a new
  idea bottoming out in the same logic gates).

---

## TODO 1 — A machine layer: Finite State Machine, then Turing Machine

> *Theory anchor:* a Turing machine **is** a finite-state control **plus** an
> unbounded read/write tape. So build the FSM first; the TM is then literally
> "FSM + tape." (An FSM is the restricted special case — it's a TM that can't write
> and only moves one way.)

**Suggested files:** `state-machine.sh` + `turing-machine.sh` (or one `machines.sh`),
`test-machines.sh`, later `TUTORIAL_MACHINES.md`.

### 1a. Finite State Machine (`state-machine.sh`)
- [ ] Generic FSM driver: a transition table `(state, symbol) → state`, a start
      state, and a set of accept states; `fsm_run TABLE START INPUT` returns the
      final state (and accept/reject).
- [ ] **Lovely reuse:** *running an FSM is a left fold of the transition function
      over the input list* — so implement it with the kit's `foldl` (input symbols
      as a space-separated list, the transition as the binary combiner, the state
      as the accumulator).
- [ ] Example machines: parity detector (ties to `xor_all`), "divisible by 3" over
      a binary string, a sequence detector (e.g. spot `1 0 1`), a turnstile.
- [ ] Tests comparing FSM verdicts to a ground-truth check.

### 1b. Turing Machine (`turing-machine.sh`)
- [ ] Finite-state control (reuse the FSM idea) + a **bounded tape** (a large fixed
      width, e.g. `TM_TAPE=256` cells; document the bound and the blank symbol).
- [ ] Represent the tape as a space-separated atom list (so the list kit applies)
      or a bash array; track head index + current state.
- [ ] Transition: `(state, symbol) → (new_state, write_symbol, move L|R)`;
      `tm_step` + `tm_run` (run to a halt state, with a `max_steps` guard).
- [ ] Example programs: unary increment, unary addition, binary increment, copy a
      string, palindrome checker, a small busy-beaver.
- [ ] **Wire to Layer 1:** let tape cells be bits; a TM that increments a binary
      number can be checked against `inc` / `ripple_add4`.
- [ ] Tests; keep them small (this will be slow).

---

## TODO 2 — Rudiments of the lambda calculus

> *Theory anchor:* the lambda calculus is the **function** side of Church–Turing.
> We already have the substrate — "fn values" as code strings, `apply`/`compose`,
> and Church numerals/booleans/pairs in `alt-arithmetic.sh`.

**Suggested files:** `lambda.sh` (sources `list-processing-kit.sh` for the combinator
core), `test-lambda.sh`, later `TUTORIAL_LAMBDA.md`.

- [ ] Start with **combinatory logic (SKI)** — the pragmatic core, because it
      sidesteps variable binding / α-renaming / capture, which are painful in bash:
      - `I x       = x`            (identity)
      - `K x y     = x`            (const)
      - `S f g x   = f x (g x)`    (substitute-and-apply)
- [ ] Show `SKK = I` (identity falls out of S and K).
- [ ] Derive a few standard combinators: `B` (compose), `C` (flip), `W` (duplicate).
- [ ] Rebuild Church `TRUE`/`FALSE`/numerals on top of SKI, reconnecting to the
      Church work already in `alt-arithmetic.sh` (note **combinatory completeness**:
      SKI can express any closed lambda term).
- [ ] *(Stretch)* a tiny **β-reduction stepper** over lambda terms represented as
      data, with a normal-order reduction strategy — enough to evaluate small terms.
- [ ] Tests checking reductions against expected normal forms.

---

## The capstone — Church–Turing in action (`TUTORIAL_CHURCH_TURING.md`)

Once TODO 1 and TODO 2 exist, land the punchline by computing the **same function
two ways** and showing the answers agree:

- [ ] Pick a function (e.g. "double", "add", or "is even").
- [ ] Implement it as a **Turing machine** (TODO 1) and in the **lambda/Church**
      world (TODO 2 + existing Church numerals), run both, assert equality.
- [ ] Reuse the bridge that already exists: a Church numeral drives the Layer-1
      `inc` circuit (`church_to_bits`) — the literal handshake between "function"
      and "machine." Extend it: e.g. a unary-increment TM vs `church_succ`, or a
      TM computing `n + m` vs `church_plus`.
- [ ] A plain-English tutorial that ties the whole project together: gates →
      arithmetic → machines → lambda → "they're all the same power."

---

## Possible later threads (parked)
- The other nonstandard arithmetic models noted in `ALT_ARITHMETIC.md` (balanced
  ternary, Zeckendorf/Fibonacci base).
- A pushdown automaton (FSM + a stack) to fill the middle of the Chomsky hierarchy
  between the FSM and the TM.
