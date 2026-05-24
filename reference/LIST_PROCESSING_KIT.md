# List-Processing Kit — a standalone Scheme/Lisp-style toolkit

A small, **self-contained** toolkit of higher-order functions over lists — `map`,
`filter`, `foldl`/`foldr`, `scanl`, `zipwith`, slicing, generators, predicate
combinators. It is **domain-neutral**: no Boolean gates, no arithmetic models, nothing
project-specific — so it stands completely on its own, and it is the substrate the
combinator (`combinator-circuits.sh`), lambda (`lambda.sh`), and machine
(`state-machine.sh`) layers all build on. Lives in `list-processing-kit.sh`.

## The model — two ideas

- **A list is a space-separated string of atoms** (the Scheme/LSB-first convention).
  Atoms must not contain spaces: `"3 1 4 1"` is a 4-element list.
- **A "fn value" is a string of bash code** that reads its argument(s) from `$1`
  (and `$2`, `$3`) and echoes a result — e.g. `'echo $(($1 * $1))'`. Every
  higher-order function *also* accepts a bare **command name**; `as_fn` / `as_fn2` /
  `as_fn3` normalise the two (they detect a literal `$1`/`$2`/`$3` to decide whether to
  wrap). So `map dbl xs` and `map 'echo $(($1*2))' xs` are interchangeable.

**Self-contained:** the kit bundles the only machinery it relies on — `apply`,
`apply2`, `apply3` — so `source ./list-processing-kit.sh` and nothing else is needed.
(Those three are an exact copy of `alt-arithmetic.sh`'s combinator core, so sourcing
both is harmless.)

## Loading

```bash
source ./list-processing-kit.sh
```

## Application core

| function | applies a fn value to… |
|---|---|
| `apply  F x` | one argument — `F(x)` |
| `apply2 F a b` | two — `F(a, b)` |
| `apply3 F a b c` | three — `F(a, b, c)` |
| `as_fn` / `as_fn2` / `as_fn3` | normalise a command name *or* a fn value |

```bash
apply  'echo $(($1 + 1))' 5      # 6
apply2 'echo $(($1 * $2))' 6 7   # 42
```

## List primitives

| function | result |
|---|---|
| `lnull xs` | true (exit 0) iff `xs` is empty |
| `lhead xs` | first atom |
| `ltail xs` | all but the first |
| `llength xs` | element count |

## Map & filter

`map` (iterative) and `mapcar` (its recursive Scheme twin) apply a unary function to
every atom; `filter` keeps the atoms for which a predicate echoes `"true"`.

```bash
map 'echo $(($1 * $1))' '1 2 3 4'                         # 1 4 9 16
filter 'if (($1%2==0)); then echo true; else echo false; fi' '1 2 3 4 5 6'   # 2 4 6
```

## Folds & scans

`foldl` / `foldr` collapse a list with a binary function (left- vs right-associating);
`foldl1` seeds from the first atom; `scanl` keeps **every running accumulator**, not
just the last.

```bash
foldl  'echo $(($1+$2))' 0 '1 2 3 4 5'    # 15
foldr  'echo $(($1-$2))' 0 '1 2 3'        # 2      (vs foldl's -6 — associativity differs)
foldl1 'echo $(($1+$2))' '1 2 3 4'        # 10     (no seed)
scanl  'echo $(($1+$2))' 0 '1 2 3 4'      # 0 1 3 6 10   (the running sums)
```

## Zips & tuples

`zipwith` / `zipwith3` combine two / three lists element-wise (length = the shortest).
Because a flat space-list can't nest, **tuples are `:`-joined**: `zip` pairs two lists
into `"a:1 b:2 …"`, `unzip` splits a tuple-list back into two lines, and `flatten`
dissolves the `:` grouping into one flat list.

```bash
zipwith  'echo $(($1+$2))' '1 2 3' '10 20 30'              # 11 22 33
zipwith3 'echo $(($1+$2+$3))' '1 2 3' '10 20 30' '100 200 300'   # 111 222 333
zip 'a b c' '1 2 3'                                        # a:1 b:2 c:3
flatten 'a:1 b:2 c:3'                                      # a 1 b 2 c 3
```

## Slicing

```bash
take 2 'a b c d'                # a b        drop 2 'a b c d'              # c d
take_while "$LT4" '1 2 5 3'     # 1 2        drop_while "$LT4" '1 2 5 3'   # 5 3
```

`take_until` / `drop_until` are the mirror image — they act *until* the predicate first
holds, so `take_until p` ≡ `take_while (complement p)`.

## Generators & builders

| function | result |
|---|---|
| `lrange a b` | inclusive `a..b` |
| `lreverse xs` | reversed list |
| `iterate F x n` | `n` elements `[x, F x, F(F x), …]` |
| `replicate n x` | `n` copies of `x` |
| `intercalate sep xs` | join atoms with `sep` |

```bash
lrange 3 7                      # 3 4 5 6 7
iterate 'echo $(($1*2))' 1 5    # 1 2 4 8 16
intercalate - '1 2 3'           # 1-2-3
```

## Predicates & search

```bash
any "$EVEN" '1 3 4'    # true      all "$EVEN" '2 4 6'   # true      none "$EVEN" '1 3 5'   # true
count_if "$EVEN" '1 2 3 4'   # 2    elem 4 '3 4 5'  # true    find_index "$EVEN" '1 3 6 7'   # 2 (0-based; -1 if none)
```

## Reductions over already-decided values

These fold a list of *already-decided* values, so they need no gates — keeping the kit
standalone: `and_list` / `or_list` reduce a list of the literal atoms `"true"`/`"false"`;
`lsum` / `lproduct` reduce a list of integers.

```bash
and_list 'true true false'   # false      or_list 'false true false'   # true
lsum '1 2 3 4 5'             # 15         lproduct '1 2 3 4'           # 24
```

## Predicate combinators

`complement` / `conj` / `disj` take predicates and return a **new predicate** (a fresh
fn value), so predicate logic composes:

```bash
EVEN='if (($1%2==0)); then echo true; else echo false; fi'
map "$(complement "$EVEN")" '1 2 3 4'   # true false true false
map "$(conj "$EVEN" "$LT4")" '1 2 3 4 5 6'   # false true false false false false  (even AND <4)
```

## Composition — and the payoff

The functions chain, Scheme-style — e.g. the sum of the squares of the even numbers in
1..6:

```bash
foldl 'echo $(($1+$2))' 0 \
  "$(map 'echo $(($1*$1))' \
      "$(filter "$EVEN" "$(lrange 1 6)")")"      # 56  (4 + 16 + 36)
```

And because the kit is generic, it becomes the **function-side substrate** for the rest
of the project: `combinator-circuits.sh` rebuilds Layer-1's word ops from it
(`map flip_bit` = `word_not`, the ripple adder as a carry-threading `foldl`/`scanl`);
`lambda.sh` builds the SKI combinators on `apply`; and an FSM run *is* `foldl` of the
transition over the input. The design rule that makes all that possible: the kit stays
**domain-neutral** — it never reaches into a lower layer.

## Box-and-pointer diagrams

`box_diagram xs` draws a list the way the Lisp/Scheme texts do (SICP
[§2.2](https://sarabander.github.io/sicp/html/2_002e2.xhtml)): a horizontal spine of
**cons cells**, each *car* (left box) pointing **down** to its datum and each *cdr*
(right box) pointing **right** to the next cell, the final cdr a slash `/` — the empty
list. ASCII art, so the columns line up anywhere; self-contained, like the rest of the
kit.

```bash
box_diagram "3 1 4 1"
```
```
+---+---+  +---+---+  +---+---+  +---+---+
| * | *-+->| * | *-+->| * | *-+->| * | / |
+-+-+---+  +-+-+---+  +-+-+---+  +-+-+---+
  |          |          |          |
  v          v          v          v
  3          1          4          1
```

A `:`-tuple is itself a pair, so a `zip` result is drawn as a **list of pairs** — each
spine car points down to a nested sub-cell (the textbook nested diagram):

```bash
box_diagram "$(zip 'a b c' '1 2 3')"     # a:1 b:2 c:3
```
```
+---+---+  +---+---+  +---+---+
| * | *-+->| * | *-+->| * | / |
+-+-+---+  +-+-+---+  +-+-+---+
  |          |          |
  v          v          v
  +---+---+  +---+---+  +---+---+
  | * | * |  | * | * |  | * | * |
  +-+-+-+-+  +-+-+-+-+  +-+-+-+-+
    |   |      |   |      |   |
    a   1      b   2      c   3
```

The empty list prints as the lone slash (`box_diagram ''` → `/   (the empty list)`).

## Tests

```bash
bash tests/test-list-processing-kit.sh    # 95 passed, 0 failed
```

The suite sources **only** the kit — no Layer-1 gates, no arithmetic models — which is
the proof that it stands alone.

---

*This kit is the toolbox; [`COMBINATOR_CIRCUITS.md`](COMBINATOR_CIRCUITS.md) is the payoff
(Layer 1 rebuilt with it), and its plain-English walkthrough is
[`../TUTORIAL_LAYER5_COMBINATORS.md`](../TUTORIAL_LAYER5_COMBINATORS.md). For every layer
at once, see [`OVERVIEW.md`](OVERVIEW.md).*
