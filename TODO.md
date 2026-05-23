# Project TODOs / Roadmap

**North star:** demonstrate the **Church–Turing thesis** *in action* — show that the
two great models of computation, the **machine** side (a Turing machine) and the
**function** side (the lambda calculus), compute the very same things. The project
already has both halves in embryo: the circuit side (gates → ripple adder → `alu4`)
and the function side (the combinator layer + Church numerals/booleans/pairs in
`alt-arithmetic.sh`). These TODOs build the missing pieces and then join them.

**Guiding philosophy** (full statement in `CLAUDE.md`): this project celebrates
**building the same idea more than one way — bottom-up *and* top-down — and proving
the constructions agree**, because that equivalence is how we understand how the
concepts relate. The deeper goal is **tools and tutorials that democratize
exploration and learning, starting with ourselves.**

**Working convention** (so each layer stays understandable and self-contained):
- Each new layer gets **its own `.sh` file**, sourcing what it builds on.
- Each gets **its own test file** (`test-*.sh`), kept out of the fast 1022-test core
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

**Status — ✅ DONE (2026-05-23).** Landed `lambda.sh` + `test-lambda.sh` (45 passing)
and the `LAMBDA.md` reference. (Plain-English `TUTORIAL_LAMBDA.md` deferred, like the
other tutorials — available on request.)

- [x] **Combinatory logic (SKI)** as real, curried, `apply`-able fn values — `SKI_I`,
      `SKI_K`, `SKI_S` (each partial application bakes its argument in via `%q`, with a
      one-level staging helper so the quoting stays readable).
- [x] **`S K K = I`** shown both ways — by applying the fn values, and by symbolic
      reduction (`S K K x → K x (K x) → x`).
- [x] Derived **`B`** (compose), **`C`** (flip), **`W`** (duplicate) as fn values.
- [x] **Church `TRUE`/`FALSE`/numerals on SKI** (`TRUE=K`, `FALSE=K I`, `ZERO=K I`,
      `SUCC=S B`), cross-checked in the suite against `alt-arithmetic.sh`'s
      `CHURCH_TRUE`/`FALSE` and `int_to_church` — two constructions, same numbers.
- [x] *(Stretch — done)* a **symbolic reducer** over SKI terms-as-data
      (`lc_step` / `lc_normalize` / `lc_trace`), normal order, rules `I a→a`, `K a b→a`,
      `S a b c→a c (b c)`. (SKI specifically — it sidesteps the variable-capture that a
      full β-reducer over binders would drag in.) Symbolic numerals reduce to n-fold
      application: `lc_church 3 f x → f (f (f x))`.
- [x] Tests checking reductions against expected normal forms (`test-lambda.sh`).

---

## TODO 3 — Layer 1: full 8-bit word support

> *Theory anchor:* a "word" is just a fixed-width row of bits. Layer 1 grew up as a
> **4-bit nibble** machine (`ripple_add4`, `alu4`); the natural next tier is the
> **8-bit byte**. The good news from an audit: most of the word layer is *already
> width-generic* (it reads a bit string into an array and loops over its length), so
> this is mostly **finishing the few fixed-width spots** and rounding out the
> byte-level conveniences — not a rewrite. *(Foundational and independent — this
> doesn't block the capstone, but a richer bit layer makes it land harder.)*

**Files:** extended `boolean-funcs-new.sh` + `test-boolean-funcs.sh` in place (these
are fast, pure Layer 1 — they stay in the now-1022-test core).

**Width audit (state *before* this work — the grounding for the TODO):**
- *Already arbitrary-width* (consume a space-separated string of any length):
  `word_not/and/or/xor/zip`, every `*_all` reduction (`and_all`/`or_all`/`xor_all`/
  `is_zero`/…), `inc`/`dec`/`negate`, the `is_*` predicates, `parity`/`popcount`/
  `lsb`/`msb`/`bits_to_int`, `bits_eq`/`bits_gt`, `word_mux`/`bits_min`/`bits_max`,
  `shl`/`shr`, and `int_to_bits N [width]`. These already work at 8 bits today.
- *Pinned to a fixed width* (positional args): `ripple_add4`/`ripple_add8`,
  `ripple_sub4`/`ripple_sub8`, `compare4`/`compare8` (positional wrappers), and
  `alu4` (4-bit only — the main gap, now joined by `alu8`).

**Tasks — ✅ DONE (2026-05-23):**
- [x] **`alu8`** — 8-bit ALU mirroring `alu4` (same op set, output `R0..R7 Z C N V`),
      built on the new width-generic `word_add`/`word_sub`; every opcode and all four
      flags tested (incl. 128+128 → Z,C,V).
- [x] **Width-generic `word_add` / `word_sub`** over two LSB-first bit STRINGS of any
      width (4/8/16-bit all tested); output = result bits + carry, two's-complement sub.
      **Deviation from the original note:** `ripple_add4`/`ripple_add8` were *kept* as
      their own explicit constructions (not made wrappers) — the docs/tutorial describe
      `ripple_add8`'s "two chained nibbles," and the suite now cross-checks `word_add`
      bit-for-bit *against* them (two constructions, proven equal — the project's
      recurring theme, and a preview of TODO 4's third, fold-based construction).
- [x] **`sar`** (arithmetic, sign-replicating right shift) + cyclic **`rol`/`ror`**.
- [x] **Width bridges:** `zero_extend`, `sign_extend`, and `trunc_bits` (named
      `trunc_bits`, *not* `truncate`, to avoid shadowing the coreutil of that name).
- [x] Byte conveniences: `int_to_bits N 8` → `bits_to_int` round-trip tested; 8-bit
      demos added to `README.md`/`OVERVIEW.md`. *(Named byte constants: skipped — the
      "consider" was optional and nothing needed them.)*
- [x] **Tests at 8 bits:** ~70 new checks — add/sub/carry/overflow, all `alu8` flags,
      `sar` vs signed division, rotate identities, sign-extension round-trips.
- [x] *(Doc)* `README.md` + `OVERVIEW.md` updated (function index, prose, coverage
      table, examples). The plain-English `TUTORIAL_LAYER1.md` already makes the scaling
      point ("same trick, eight columns"), so no jargon was forced into that voice.

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

**Status — ✅ DONE (2026-05-23).** Landed `combinator-circuits.sh` + the 4a kit
additions. `test-combinator-circuits.sh` (111 passing) proves every `fp_*` equals its
Layer-1 twin bit-for-bit; `test-list-processing-kit.sh` grew 50 → 77. Full writeup in
`COMBINATOR_CIRCUITS.md`.

### 4a. Round out the kit's generic FP combinators (`list-processing-kit.sh`)
- [x] `none`, `count_if pred xs`, `elem`, `find_index`.
- [x] Boolean folds `and_list` / `or_list` over true/false atoms; numeric `lsum` /
      `lproduct` (named `lsum`/`lproduct`, not `sum`/`product`, to avoid shadowing the
      `sum` coreutil — domain-neutral, so the kit stays standalone).
- [x] **Predicate combinators** `complement p`, `conj p q`, `disj p q` — and the
      identity `take_until p == take_while (complement p)` is now a passing test.
- [x] `replicate n x`, `intercalate sep xs`, `zipwith3` (plus `apply3`/`as_fn3` to
      support it). *(`concat` skipped — a space-join already concatenates lists.)*
- [x] Tests added to `test-list-processing-kit.sh` (50 → 77, still standalone & fast).

### 4b. Reconstruct the Layer-1 word ops compositionally (`combinator-circuits.sh`)
- [x] **Bitwise algebra as one-liners:** `fp_word_not = map flip_bit`,
      `fp_word_{and,or,xor} = zipwith bit_{and,or,xor}`, and `fp_{and,or,xor}_all` =
      map-to-bool then fold. (Bit gates bridge `0/1` ↔ the gates' `true/false`.)
- [x] **Half/full adder building on each other:** `fp_full_adder` = two
      `fp_half_adder`s + an OR, all from the bit gates. *(Built straight from the bit
      gates rather than literal `apply`/`compose` — clearer, same composition.)*
- [x] **★ Ripple adder as a fold/scan:** `fp_word_add` is a `foldl` threading the carry
      (accumulator `"carry|bits"`); `fp_carry_chain` is a `scanl` exposing the whole
      carry ripple; and `fp_word_add_scan` rebuilds the adder a *third* way from the
      carry chain + a `zipwith3`. n-bit automatically (width = list length).
- [x] **Arbitrary width + n-ary input:** width = list length (4/8/16-bit all tested);
      n-ary BIT input *is* `fp_{and,or,xor}_all` (an N-input gate = the 2-input gate
      folded over N bits); n-ary WORD reducers `fp_{and,or,xor}_words` / `fp_add_words`
      fold a word op over `"$@"` (words contain spaces, so they fold over the argument
      list, not a kit list — noted in the file).
- [x] **Shifts as pure list surgery:** `fp_shl`/`fp_shr` (+ `fp_rol`/`fp_ror`) from
      `take`/`drop`/`replicate`; cross-checked vs Layer 1 at 4- and 8-bit.
- [x] **★ Equivalence tests** (`test-combinator-circuits.sh`, 111 passing): every
      `fp_*` vs its Layer-1 twin over 4- and 8-bit grids. **The payoff:** `word_add`
      (loop) == `fp_word_add` (foldl) == `fp_word_add_scan` (scanl+zipwith3) ==
      `ripple_add8` (nibbles) — four constructions, one answer.
- [x] *(Doc)* `COMBINATOR_CIRCUITS.md` reference + a README section, **and** the
      plain-English `TUTORIAL_LAYER5_COMBINATORS.md` ("the same machine, built the other
      way" — map/zipwith/fold as a stamping-belt/zipper/receipt, addition as "carry the
      1," four roads to one answer), in the no-math Layer 1–4 tutorial voice.

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
