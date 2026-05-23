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

## TODO 3 — Layer 1: full 8-bit word support

> *Theory anchor:* a "word" is just a fixed-width row of bits. Layer 1 grew up as a
> **4-bit nibble** machine (`ripple_add4`, `alu4`); the natural next tier is the
> **8-bit byte**. The good news from an audit: most of the word layer is *already
> width-generic* (it reads a bit string into an array and loops over its length), so
> this is mostly **finishing the few fixed-width spots** and rounding out the
> byte-level conveniences — not a rewrite. *(Foundational and independent — this
> doesn't block the capstone, but a richer bit layer makes it land harder.)*

**Files:** extend `boolean-funcs-new.sh` + `test-boolean-funcs.sh` in place (these are
fast, pure Layer 1 — they stay in the 952-test core).

**Width audit (current state — the grounding for this TODO):**
- *Already arbitrary-width* (consume a space-separated string of any length):
  `word_not/and/or/xor/zip`, every `*_all` reduction (`and_all`/`or_all`/`xor_all`/
  `is_zero`/…), `inc`/`dec`/`negate`, the `is_*` predicates, `parity`/`popcount`/
  `lsb`/`msb`/`bits_to_int`, `bits_eq`/`bits_gt`, `word_mux`/`bits_min`/`bits_max`,
  `shl`/`shr`, and `int_to_bits N [width]`. These already work at 8 bits today.
- *Pinned to a fixed width* (positional args): `ripple_add4`/`ripple_add8`,
  `ripple_sub4`/`ripple_sub8`, `compare4`/`compare8` (positional wrappers), and
  **`alu4` (4-bit only — the main gap).**

**Tasks:**
- [ ] **`alu8`** — an 8-bit ALU mirroring `alu4`: same op set (`add sub and or xor
      not slt shl shr`), output `R0..R7 Z C N V`, built on `ripple_add8`/`ripple_sub8`
      and the (already generic) word ops. Document that the flags are byte-width.
- [ ] **Width-generic `word_add` / `word_sub`** taking two equal-width LSB-first
      strings (→ result + carry/borrow), so 8-bit (or any-bit) addition needs no
      17-positional-arg call; make `ripple_add4`/`ripple_add8` thin wrappers over it.
      *(Heads-up: this is the same n-bit adder TODO 4 builds from the function side —
      see the cross-note there; building both and asserting they agree is the point.)*
- [ ] **Arithmetic shift right `sar`** (sign-replicating — two's-complement ÷2ⁿ) to
      complement the logical `shl`/`shr`; optional **rotates** `rol`/`ror`.
- [ ] **Width bridges:** `sign_extend BITS NEWWIDTH`, `zero_extend`, `truncate` — since
      "8-bit support" really means moving cleanly between 4-, 8-, and 16-bit words.
- [ ] Byte conveniences: confirm `int_to_bits N 8` round-trips through `bits_to_int`;
      add an 8-bit demo block; consider named byte constants.
- [ ] **Tests at 8 bits:** add/sub/carry/overflow vs `bits_to_int`, all `alu8` flags,
      `sar` vs arithmetic division, sign-extension round-trips.
- [ ] *(Doc)* a short sidebar (in `TUTORIAL_LAYER3.md` or the ALU notes): the same
      chip scales from nibble to byte by widening the bit string.

---

## TODO 4 — The combinator payoff: rebuild the circuits from the function side

> *Theory anchor:* Layer 1 builds words **imperatively** — loops that walk a bit
> array. The list-processing kit lets us build the *same* words **declaratively**, as
> one-line folds and maps: `word_not = map flip_bit`, `word_xor = zipwith xor`,
> `and_all = foldl and true`. The kit's header already *promises* this; this TODO
> **fully realizes it**, culminating in the **ripple adder as a carry-threading
> fold/scan** — the elegant statement that "addition is a one-line recurrence." Two
> independent constructions of the same circuit (machine-style loop vs. function-style
> fold), proven bit-for-bit identical, is itself a Church–Turing-flavored result in
> miniature.

**File-layout decision (worth a moment):** keep `list-processing-kit.sh`
**domain-neutral and standalone** — it must not depend on Layer 1's gates. So:
- *Generic / "truthy" FP combinators* (no bit knowledge) → go **into the kit**.
- *Bit/word reconstructions* (which we want to cross-check against Layer 1) → a **new
  file**, proposed `combinator-circuits.sh`, that sources the kit; its test file also
  sources `boolean-funcs-new.sh` to assert equivalence. (Recommended over stuffing
  Layer-1 rebuilds into the kit, which would couple a general tool to this project.)

### 4a. Round out the kit's generic FP combinators (`list-processing-kit.sh`)
- [ ] `none`, `count` / `count_if pred xs`, `elem` / `member`, `find_index`.
- [ ] Boolean folds over `true`/`false` atoms: `and_list` / `or_list` (the
      domain-neutral cousins of Layer 1's `and_all`/`or_all`); numeric `sum`/`product`.
- [ ] **Predicate combinators:** `complement p`, `conj p q`, `disj p q` — so identities
      like `take_until p = take_while (complement p)` become literally true.
- [ ] `replicate n x`, `concat`, `intercalate`, maybe `zipwith3`.
- [ ] Tests added to `test-list-processing-kit.sh` (still standalone, still fast).

### 4b. Reconstruct the Layer-1 word ops compositionally (`combinator-circuits.sh`)
- [ ] **Bitwise algebra as one-liners:** `word_not = map flip_bit`,
      `word_and/or/xor = zipwith and/or/ne`, the `*_all` reductions = `foldl <gate>
      <seed>`. Re-derive the whole word-Boolean algebra from the kit.
- [ ] **Half/full adder that build on each other** (the user's phrase): `full_adder`
      composed from two `half_adder`s via `apply`/`compose`, returning a `(sum, carry)`
      pair (reuse the Church pair trick, or the kit's `:`-joined tuples).
- [ ] **★ The centerpiece — ripple adder as a fold/scan:** thread the carry with
      `foldl` over the zipped bit-pairs, accumulator `= (carry, output-so-far)`; or use
      **`scanl`** to expose the *entire carry chain* (you can literally watch the carry
      propagate — gorgeous for a tutorial). Width is just the list length, so it is
      **n-bit automatically**. Cross-check against `ripple_add4`/`ripple_add8`.
- [ ] **Arbitrary width + n-ary input** — clarifying the terminology that was reached
      for ("n-ary bit input", "extensible bit length"):
      - A fixed-arity gate (2-input `and`) becomes **variadic** by *folding it over a
        list* — that fold-of-a-binary-op is the **reducer** in question; "n-ary input"
        = reduce a gate across an N-element bit list.
      - Because the word ops are reducers over a bit *list*, the **width is just the
        list's length** — the same `word_add` runs at 4, 8, 16, … bits with no change.
        That is what makes the top-level functions' bit length arbitrarily extensible.
      - n-ary *word* reducers: `add_all "wA wB wC …" = foldl1 word_add` (sum a whole
        list of words); `and_all_words` / `or_all_words = foldl1 word_and/word_or`.
- [ ] **Shifts as pure list surgery** (no arithmetic): `shl xs = take w (0 : xs)`,
      `shr xs = drop 1 xs ++ 0`, built from the kit's `take`/`drop`/`concat`/
      `replicate`. Cross-check against Layer 1's `shl`/`shr`; cover 8-bit widths.
- [ ] **★ Equivalence tests** (`test-combinator-circuits.sh`): for many words at width
      4 *and* 8, assert the combinator version equals the Layer-1 version bit-for-bit
      (`map flip_bit` vs `word_not`, the fold-adder vs `ripple_add*`, the list-shifts vs
      `shl`/`shr`). **This is the payoff** — the function side and the machine side,
      shown to compute the identical circuit.
- [ ] *(Doc)* a future `TUTORIAL_*` (or a section folded into the combinator tutorial)
      showing "the adder is a one-line recurrence" and the carry chain via `scanl`.

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
