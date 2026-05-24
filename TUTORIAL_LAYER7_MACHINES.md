# Layer 7: A Rule-Follower and a Roll of Tape — A Plain-English Tutorial

*The lambda layer built computing out of **functions** — the "function side" of the
world. This layer builds it out of the opposite stuff: a stubborn little
**rule-follower** that reads symbols one at a time and changes its mood. Give that
rule-follower a notepad it can scribble on, and — this is the punchline — it becomes
the most powerful kind of computer there is. No equations. We'll build a turnstile,
then a parity counter, then hand the thing a strip of tape and watch it do the exact
same arithmetic the gates from Layer 1 do. If you've ever flipped a light switch and
watched a hallway change, you already understand the whole first half.*

---

## The big idea: a machine that's always "in a mood"

Picture a device that is **always in exactly one state** — call it its *mood*. It
reads its input one symbol at a time, and **each symbol can change its mood**,
according to a fixed little rulebook. That's the entire concept of a **Finite State
Machine** (FSM). No memory beyond "which mood am I in right now." No scratch paper.
Just: *what mood am I in, what did I just read, what mood does that put me in.*

The rulebook is a list of rules shaped like `mood,symbol->newmood`. Load the layer:

```bash
source ./state-machine.sh
```

## The friendliest example: a turnstile

The subway turnstile is the textbook FSM, because you've used one. It has two moods —
`locked` and `unlocked` — and two things can happen to it: someone drops a `coin`, or
someone gives it a `push`. The rulebook reads exactly how you'd expect:

- `locked` + `coin` → `unlocked` (you paid; it lets you through next push)
- `locked` + `push` → `locked` (you didn't pay; it won't budge)
- `unlocked` + `coin` → `unlocked` (you overpaid; oh well)
- `unlocked` + `push` → `locked` (you walk through; it re-locks behind you)

That rulebook is already built in as `FSM_TURNSTILE`. Feed it a sequence of events and
ask where it ends up:

```bash
fsm_run "$FSM_TURNSTILE" locked 'coin push'        # locked    (paid, walked through)
fsm_run "$FSM_TURNSTILE" locked 'coin coin push'   # locked    (overpaid, still just one walk-through)
```

The first argument is the rulebook, the second is the mood it **starts** in, the third
is the sequence of events. `fsm_run` hands you back the **final mood**.

> **A small heads-up about output.** These functions print their answer with *no
> trailing newline* — that's on purpose, so the result drops cleanly inside `$(...)`
> for the cross-checks later. The cost is that, run bare, the answer can look glued to
> your next shell prompt (`locked` jammed against `you@box:~$`). It's there — wrap it
> in `echo "$(fsm_run ...)"` to see it on its own line.

## Watching the mood change: parity

Here's a machine that actually *computes* something. `FSM_PARITY` counts whether it
has seen an **odd or even number of `1`s**. Two moods: `e` (even-so-far) and `o`
(odd-so-far). Every `1` flips the mood; every `0` leaves it alone. Start in `e`:

```bash
fsm_run   "$FSM_PARITY" e '1 1 0 1'    # o     (three 1s = odd)
```

Want to see it *think*, not just its final answer? `fsm_trace` gives you the mood
after **every** symbol — the running history:

```bash
fsm_trace "$FSM_PARITY" e '1 1 0 1'    # e o e e o
```

Read that left to right: it starts `e`, the first `1` flips it to `o`, the second `1`
flips back to `e`, the `0` leaves it at `e`, the last `1` flips to `o`. The final mood
is the same `o` that `fsm_run` reported. **`fsm_run` is the last frame of the movie;
`fsm_trace` is the whole movie.**

(If "odd/even count of 1-bits" rings a bell, it should — that's exactly what Layer 1's
`xor_all` computes. Same idea, built a completely different way. The whole project is
this trick, over and over.)

## Accept or reject: a machine that judges

Often you don't care about the *final mood* by name — you care whether it's a "good"
one. Mark some moods as **accepting**, and the machine becomes a **judge** that says
`accept` or `reject`. `fsm_accepts` takes one extra argument: the list of accepting
moods.

`FSM_DIV3` reads a binary number (most-significant bit first) and accepts exactly when
the number is **divisible by 3**. Its moods are the running remainder, `r0`/`r1`/`r2`;
it accepts in `r0` (remainder zero):

```bash
fsm_accepts "$FSM_DIV3" r0 r0 '1 1 0'    # accept    (110 = 6, divisible by 3)
fsm_accepts "$FSM_DIV3" r0 r0 '1 1 1'    # reject    (111 = 7, not divisible by 3)
```

`FSM_SEQ101` is a **pattern spotter** — it accepts if the sequence `1 0 1` appears
*anywhere* in the input. Once it has seen the pattern it parks in an accepting mood and
never leaves:

```bash
fsm_accepts "$FSM_SEQ101" q0 q3 '0 1 0 1 0'    # accept   (a 1 0 1 lives inside it)
```

## The lovely secret: running an FSM is just a running tally

Here's the bit that ties this layer back to the rest of the project. Think about what
`fsm_run` actually *does*: it starts with a value (the start mood), and walks the input
left to right, replacing that value with a new one at each step. That's a **left
fold** — `foldl` from the [list-processing kit](reference/LIST_PROCESSING_KIT.md), the
same "running tally" pattern you'd use to add up a list. The "tally" just happens to be
the machine's mood, and the "+" just happens to be "look up the next mood in the
rulebook."

That's not an analogy — it's literally how `fsm_run` is written:

```bash
fsm_run () { foldl "fsm_step ... " "$2" "$3"; }      # the mood is the accumulator
```

And `fsm_trace`? That's `scanl` — the fold that keeps **every** running value instead
of just the last one. The machine and the list-tool are the same shape.

---

## Part two: hand it a notepad, get a Turing machine

A finite state machine has one limitation, and it's a big one: it has **no memory** but
its current mood. It can't jot something down to come back to. So we give it the one
missing thing — **a strip of tape it can read, write on, and step along in either
direction.**

That single addition — *writing*, and *moving both ways* — is the entire leap from a
humble FSM to a **Turing machine**: the mathematical model of *everything a computer
can possibly do*. It sounds like it should take more. It doesn't.

```bash
source ./turing-machine.sh        # this pulls in state-machine.sh (the FSM idea) too
```

The rulebook grows by two columns. An FSM rule was `mood,symbol->newmood`. A Turing
rule is `mood,symbol->newmood,whattowrite,whichway`, where "which way" is `L` (left),
`R` (right), or `S` (stay put). So every step the machine: reads the cell under its
head, and based on its mood, **writes** a symbol, **moves**, and **changes mood**.

## A first tape machine: add one stroke

The simplest possible thing: a number written as a row of strokes (`1 1 1` is "three"),
and a machine that **appends one more stroke**. `TM_UNARY_INC` walks right across the
strokes until it falls off the end, then writes a fresh `1`:

```bash
tm_run "$TM_UNARY_INC" h s '1 1 1'    # 1 1 1 1     (three strokes became four)
```

`tm_run` hands back the **final tape** (with trailing blanks tidied away). The
arguments are: the rulebook, the **halt** mood(s) (where it stops), the start mood, and
the input tape.

Want to watch the head crawl? `tm_trace` prints one snapshot per step. Each snapshot is
`mood|head-position|tape`:

```bash
tm_trace "$TM_UNARY_INC" h s '1 1 1'
# s|0|1 1 1 _ _ …      (in mood s, head on cell 0, reading the first stroke)
# s|1|1 1 1 _ _ …      (stepped right)
# s|2|1 1 1 _ _ …
# s|3|1 1 1 _ _ …      (head now over the first blank)
# h|3|1 1 1 1 _ …      (wrote a stroke, halted in mood h)
```

And `tm_steps` just counts how many steps that took:

```bash
tm_steps "$TM_UNARY_INC" h s '1 1 1'    # 4
```

A slightly fancier one: **unary addition.** Write `a + b` as strokes with a literal `+`
between them, and `TM_UNARY_ADD` turns the `+` into a stroke and erases one from the
end — leaving `a + b` strokes:

```bash
tm_run "$TM_UNARY_ADD" h a '1 1 1 + 1 1'    # 1 1 1 1 1    (3 + 2 = 5)
```

## The punchline: a tape machine *is* a Layer 1 gate circuit

Now the wire-back that makes this layer part of the same story as everything else.

`TM_FLIP` flips every bit on the tape — and that is **exactly** what Layer 1's
`word_not` does with gates:

```bash
tm_run "$TM_FLIP" h s '1 0 1 1'    # 0 1 0 0     (= word_not)
```

`TM_BINARY_INC` is even better. It adds 1 to a binary number (least-significant bit
first) by **rippling a carry rightward along the tape** — which is, bit for bit, the
carry ripple inside Layer 1's `inc` adder. The gate circuit and the tape machine are
computing the identical function:

```bash
source ./boolean-funcs-new.sh      # Layer 1, for inc / int_to_bits / bits_to_int

bits_to_int "$(tm_run "$TM_BINARY_INC" h c "$(int_to_bits 200 8)")"    # 201
bits_to_int "$(inc                    "$(int_to_bits 200 8)")"         # 201   (the same)
```

A paper-tape rule-follower and a circuit of NAND gates, handed 200, both answer 201.
*That* is the theme of the whole repo, showing up one more time.

## An FSM is just a Turing machine with its hands tied

Remember how we said an FSM is the "restricted" version? Here's that made literal.
`TM_PARITY` is a Turing machine that **only ever moves right** and **never changes a
cell** — it just walks the tape updating its mood. A TM that can't write and only goes
one way *is* a finite state machine. It halts in mood `he` (even) or `ho` (odd) —
exactly matching `FSM_PARITY`'s `e`/`o` verdict from the first half of this tutorial.
The restriction is the relationship, and now you can run both sides and check.

## Busy beavers: tiny machines, astonishing patience

One last toy, because it's delightful. A **busy beaver** is a tiny Turing machine (just
a handful of rules) that starts on a blank tape and tries to write as many `1`s as it
can *before halting*. The catch: it does halt — but only after a startling amount of
work, given how small it is.

Run them with a blank symbol of `0` and the head parked in the **middle** of the tape
(so there's room to move left):

```bash
TM_BLANK=0
tm_run   "$TM_BB3" H A '' 100 $((TM_TAPE/2))    # …1 1 1 1 1 1     (six 1s)
tm_steps "$TM_BB3" H A '' 100 $((TM_TAPE/2))    # 14
```

Three moods. Fourteen steps. Six ones — from nothing. The two-mood `TM_BB2` writes four
ones in six steps. These little machines are the friendly face of one of the deepest
facts in computing: there is no general way to know in advance whether a given machine
will *ever* stop. The busy beavers stop — but you'd never have guessed when just by
glancing at six tiny rules.

## Check the work

Both machines come with their own test suites, and the tests do the cross-checks this
tutorial described — the FSM verdicts against independent ground truth (popcount, value
mod 3, substring search), and the Turing machines against their Layer 1 twins:

```bash
bash tests/test-state-machine.sh    # 37 passed, 0 failed
bash tests/test-turing-machine.sh   # 40 passed, 0 failed
```

---

*This is the **machine side** of the project's grand idea — the equal-and-opposite of
the lambda layer's function side. **[`TUTORIAL_LAYER6_LAMBDA.md`](TUTORIAL_LAYER6_LAMBDA.md)**
built all of computing out of three tiny functions; this layer built it out of a
rule-follower and a roll of tape. They look like utterly different universes — and the
**[finale, `TUTORIAL_LAYER8_CHURCH_TURING.md`](TUTORIAL_LAYER8_CHURCH_TURING.md)**, is
where they (and the gates, and the arithmetic) all add the same numbers and land on the
same answer. For the precise reference, see [`reference/MACHINES.md`](reference/MACHINES.md);
for the whole set from the beginning, start at
**[`TUTORIAL_LAYER1.md`](TUTORIAL_LAYER1.md)**.*
