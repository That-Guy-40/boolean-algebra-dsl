# CLAUDE.md — project ethos & working notes

*Read me first. This is **why** the project exists and **how** to work in it; see
`TODO.md` for the concrete roadmap (and the Church–Turing north star), and
`reference/OVERVIEW.md` / `README.md` for the function-by-function tour.*

## Why this project exists

This project explicitly **celebrates building the same circuit/function multiple
ways and proving they agree.** We build constructs from the **bottom up** *and* the
**top down** — to better understand a given set of ideas and concepts, and how they
relate to each other.

The goal is to create **tools and tutorials that democratize exploration and
learning** — starting with the author.

## How that shapes the work

- **Convergent constructions are a feature, not duplication.** When the same thing
  can be built more than one way, keep each construction and **cross-check them in
  tests** — ideally bit-for-bit. *The equivalence is the insight.* (E.g. the
  imperative `ripple_add8` vs. the width-generic `word_add`, and — planned — the
  same adder as a `foldl`; a Turing machine vs. a lambda/Church term.)
- **Never collapse a pedagogical construction into a terser one "just for DRY."**
  Preserve the explicit/teaching version and add the new one *alongside*, noting how
  they relate. If a shortcut is unavoidable for a first pass, flag it and offer the
  canonical, from-primitives rebuild.
- **Build from primitives, bottom-up**, with no pragmatic stubs left behind.
- **Every layer earns a plain-English `TUTORIAL_*.md`** in the no-math, "poke it,
  watch it, believe it" voice — learnability is the point, not just working code.
- **Each layer lives in its own `.sh` + test file**, wiring down into the layers it
  builds on (the recurring theme: new ideas bottoming out in the same logic gates).

## Conventions worth knowing

- The fast core suite (`test-boolean-funcs.sh`) stays **green and pristine**; slow or
  experimental layers get their own separate test file.
- Bit strings are **LSB-first**; the Boolean gates follow the shell exit-code
  convention (`0` = success = true), the *opposite* of the bit convention
  (`0` = false) — mind the seam.
- End commit messages with:
  `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`
