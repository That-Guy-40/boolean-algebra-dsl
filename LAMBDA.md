# Lambda Calculus — Rudiments via Combinatory Logic (SKI)

`lambda.sh` is the **function side** of the Church–Turing story: the lambda calculus,
the model of computation built entirely from functions. To sidestep the part that is
genuinely painful in bash — variable binding, α-renaming, name capture — it uses
**combinatory logic**: three fixed combinators, **S**, **K**, **I**, out of which
*every closed lambda term* can be built (combinatory completeness). No variables, so
no capture problems.

It holds two views of the same calculus, and `test-lambda.sh` (45 passing) shows they
agree:

- **As real functions** — S, K, I are genuine `apply`-able "fn values" (code strings),
  built on the same substrate as the combinator layer. They *compute*, and Church
  booleans and numerals fall straight out of them — reconnecting to the Church work in
  `alt-arithmetic.sh`.
- **As data you can reduce** — a symbolic reducer rewrites SKI terms written as strings
  (`"S K K x"`), step by step, so you can *watch* a term reduce to normal form.

*New to the idea? [`TUTORIAL_LAYER6_LAMBDA.md`](TUTORIAL_LAYER6_LAMBDA.md) is the
plain-English, no-math walkthrough; this file is the precise reference.*

## Loading

```bash
source ./lambda.sh        # sources list-processing-kit.sh for `apply`
```

## Part 1 — SKI as apply-able functions

| combinator | rule | meaning |
|---|---|---|
| `SKI_I` | `I x = x`             | identity |
| `SKI_K` | `K x y = x`           | const (drop the second arg) |
| `SKI_S` | `S f g x = f x (g x)` | substitute-and-apply |
| `SKI_B` | `B f g x = f (g x)`   | compose |
| `SKI_C` | `C f x y = f y x`     | flip |
| `SKI_W` | `W f x = f x x`       | duplicate |

Each is a **curried** fn value: applying it to one argument hands back the next fn
value (with the captured argument baked in). `applyc` chains the applications
(`applyc F a b = apply (apply F a) b`):

```bash
applyc "$SKI_I" x                       # x
applyc "$SKI_K" keep drop               # keep
applyc "$SKI_S" "$SKI_K" "$SKI_K" q     # q     ← the classic  S K K = I
applyc "$SKI_B" 'printf "%s!" "$1"' 'printf "%s?" "$1"' hi   # hi?!  (compose)
```

The headline identity **`S K K = I`** holds: `S K K x = K x (K x) = x`. B, C, W are the
standard derived combinators (B is exactly the combinator layer's `compose`).

## Part 1b — Church booleans & numerals, from S, K, I alone

A Church **boolean** is a chooser: TRUE keeps the first of two things, FALSE the
second — which is *exactly* K and `K I`:

```bash
applyc "$LAMBDA_TRUE"  a b    # a        (LAMBDA_TRUE  = K)
applyc "$LAMBDA_FALSE" a b    # b        (LAMBDA_FALSE = K I)
```

A Church **numeral** *n* applies a function *n* times. `ZERO = K I` (apply zero times);
the successor `SUCC = S B` tacks on one more application (`SUCC n f x = f (n f x)`). So
every counting number is built from S, K, I — no arithmetic, no loops:

```bash
applyc "$(lambda_church 3)" 'printf "%s*" "$1"' ''    # ***   (apply "add a star" 3 times)
lambda_church_to_int "$(lambda_church 5)"             # 5     (read it back)
```

**Reconnection.** These are the very same Church numerals as in `alt-arithmetic.sh`:
the suite checks `lambda_church n` against `int_to_church n` (and `LAMBDA_TRUE`/`FALSE`
against `CHURCH_TRUE`/`FALSE`) — two independent constructions, the same numbers.

## Part 2 — the symbolic reducer

A term is a space-separated string; application is left-associative; parens group.
`S`/`K`/`I` are combinators, any other token is an opaque variable. Reduction is
**normal order** (leftmost-outermost), by three rules — `I a → a`, `K a b → a`,
`S a b c → a c (b c)`:

```bash
lc_normalize 'S K K x'            # x
lc_normalize 'S (K S) K f g x'    # f (g x)        (that's B, falling out of S and K)
lc_normalize "$(lc_church 3) f x" # f (f (f x))    (the numeral 3 as a reduction)
```

`lc_step` does one step; `lc_trace` prints the whole sequence — e.g. `SUCC ZERO f x`
reducing to `f x`:

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

## The payoff

Two ways to *be* the lambda calculus — functions you run, and symbols you rewrite —
landing on the same answers (`S K K` is identity both ways; numeral *n* applies *f*
exactly *n* times both ways), and all of it reconnecting to the Church numerals already
in the project. The function side of Church–Turing, out of three letters.

## Tests

```bash
bash test-lambda.sh    # 45 passed, 0 failed
```

> *Toward the capstone:* with the **function** side here (lambda / SKI + Church) and the
> **machine** side still to come (a Turing machine, TODO 1), the project can eventually
> compute the same function both ways and show they agree — the Church–Turing thesis in
> action. See `TODO.md`.
