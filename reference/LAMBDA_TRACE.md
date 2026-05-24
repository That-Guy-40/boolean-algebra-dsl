# Lambda Trace — the symbolic SKI reducer (watch a term reduce)

`lambda.sh` holds two views of the same calculus. One is **SKI as apply-able functions**
(see [`LAMBDA.md`](LAMBDA.md)). The other — documented here — is **SKI as data you can
rewrite**: a symbolic reducer that takes a combinator term written as a string
(`"S K K x"`) and reduces it step by step, so you can *watch* it reach normal form.

It's the Layer-6 member of the project's trace family (alongside
[`CIRCUIT_TRACE.md`](CIRCUIT_TRACE.md), [`ALT_ARITHMETIC_TRACE.md`](ALT_ARITHMETIC_TRACE.md),
[`COMBINATOR_TRACE.md`](COMBINATOR_TRACE.md), and the machine traces in
[`MACHINES.md`](MACHINES.md)) — but with one difference: the reducer **lives inside
`lambda.sh` itself** (it is Part 2 of the lambda layer), not in a separate `*-trace.sh`
viewer, because rewriting *is* one of the two ways this layer realises the calculus.

## Loading

```bash
source ./lambda.sh        # the reducer ships with the lambda layer
```

## The term language

- A **term** is a space-separated string; **application is left-associative**
  (`S K K x` = `((S K) K) x`); **parens group** (`S (K S) K`).
- `S` / `K` / `I` are the combinators; **any other token is an opaque variable**
  (`x`, `f`, `foo`), left untouched.
- Reduction is **normal order** — leftmost-outermost redex first — by three rules:

  | rule | rewrite |
  |---|---|
  | **I** | `I a       → a` |
  | **K** | `K a b     → a` |
  | **S** | `S a b c   → a c (b c)` |

## The functions

| function | does |
|---|---|
| `lc_step TERM`        | one normal-order step; prints the result (exit 1 if already normal) |
| `lc_normalize TERM [max]` | reduce all the way to normal form; prints it |
| `lc_trace TERM [max]` | print the whole reduction sequence, one `→` line per step |
| `lc_show TERM [max]`  | like `lc_trace`, but **annotates each step** with the rule + schema, and counts steps |
| `lc_church N`         | build the symbolic numeral `N` (a term) from `LC_ZERO` / `LC_SUCC` |
| `_lc_redex_rule TERM` | (internal) name the combinator at the next redex — `S`/`K`/`I`, or empty if normal |

## `lc_step` / `lc_normalize` — reduce

```bash
lc_normalize 'S K K x'            # x
lc_normalize 'S (K S) K f g x'    # f (g x)        (that's B = S(KS)K, falling out of S and K)
lc_normalize "$(lc_church 3) f x" # f (f (f x))    (the numeral 3, as a reduction)
```

`lc_normalize` is step-capped (default 1000) so a non-terminating term can't hang you;
it returns the term as-is if it hits the cap.

## `lc_trace` — the whole sequence

`SUCC ZERO f x` reducing to `f x`:

```bash
lc_trace "$(lc_church 1) f x"
```
```
((S (S (K S) K)) (K I)) f x
  → (S (K S) K) f ((K I) f) x
  → (K S) f (K f) ((K I) f) x
  → S (K f) ((K I) f) x
  → (K f) x (((K I) f) x)
  → f (((K I) f) x)
  → f (I x)
  → f x
```

## `lc_show` — the annotated reduction

`lc_show` is `lc_trace`'s sibling that tells you **why** each line changed: it labels
every step with the combinator rule that fired and its schema, and finishes with the
step count. Under the hood, `_lc_redex_rule` runs the *same* normal-order search as
`lc_step` but reduces nothing — it just names the redex's head — so the label always
matches the rewrite shown.

```bash
lc_show 'S K K x'
```
```
  S K K x
    → K x (K x)              [S:  S x y z → x z (y z)]
    → x                      [K:  K x y → x]
  normal form: x   (2 steps)
```

A longer one — the numeral `1` (`SUCC ZERO`) applied to `f x`, every rewrite named:

```bash
lc_show 'S (S (K S) K) (K I) f x'
#   → … [S: …]  → … [S: …]  → … [K: …]  → … [S: …]  → … [K: …]  → … [K: …]  → f x [I: …]
#   normal form: f x   (7 steps)
```

## Symbolic numerals

The reducer has its own Church numerals as *terms* (distinct from the apply-able
fn-value numerals in [`LAMBDA.md`](LAMBDA.md)): `LC_ZERO = (K I)`, `LC_SUCC = (S (S (K S) K))`,
and `lc_church N` stacks `N` successors. Reduced against `f x`, numeral `N` becomes
`f (f (… x))` with `N` `f`s — verified in the suite:

```bash
lc_normalize "$(lc_church 0) f x"   # x
lc_normalize "$(lc_church 2) f x"   # f (f x)
lc_normalize "$(lc_church 3) f x"   # f (f (f x))
```

## Why it agrees

The annotated view never diverges from the plain one: `lc_show` reaches the **same
normal form**, in the **same number of steps**, as `lc_normalize` / `lc_trace`, and its
rule labels match `lc_step`'s actual rewrites. The suite pins all of that across a sweep
of terms (including the symbolic numerals).

## Tests

```bash
bash tests/test-lambda.sh    # 67 passed, 0 failed
```

The reducer and `lc_show` are covered by `test-lambda.sh` (the same suite as the
function-side combinators) — its **PART 2** sections.

---

*This is the reduction-tracing reference; [`LAMBDA.md`](LAMBDA.md) is the companion for
**SKI as apply-able functions** (the same calculus, run rather than rewritten). The
plain-English build of both is [`../TUTORIAL_LAYER6_LAMBDA.md`](../TUTORIAL_LAYER6_LAMBDA.md).
For every layer at once, see [`OVERVIEW.md`](OVERVIEW.md).*
