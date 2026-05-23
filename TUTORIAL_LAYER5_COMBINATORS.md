# Layer 5: The Same Machine, Built the Other Way — A Plain-English Tutorial

*In Layer 1 you built a calculator by **wiring switches together** — placing each
little adder by hand and running a wire to carry the 1 to the next one. This tutorial
builds the **very same calculator a completely different way**: instead of wiring
every step, you write down one short **instruction — a recipe — and hand it to a
helper** that runs it down a whole row for you. Same calculator. Same answers.
Totally different road there. And that last part turns out to be the whole point. No
equations to "solve." If you got through Layer 1, you are ready for this.*

---

## How to follow along

Open a terminal in this folder and load this layer:

```bash
source ./combinator-circuits.sh
```

That one line quietly pulls in **Layer 1** (the switches and gates from the first
tutorial) **and** a little box of **helper-tools** for working on whole rows at once.
So everything from Layer 1 still works, and you get the new helpers too.

Same game as always: when you see a `Try it ▶` box, type it and watch. *Poke it,
watch it, believe it.*

> **Heads-up: a touch slow.** Every helper here still runs the **real switches** from
> Layer 1 underneath — it isn't faking the math. So an answer might take a moment to
> appear. That pause is the sound of actual gates doing the work.

---

## 0. The big idea: build it by hand, or write a recipe

Imagine you need a long brick wall.

- **One way:** lay every brick yourself, by hand, one at a time. (That was Layer 1 —
  you placed each adder and wired each carry personally.)
- **The other way:** hand a helper a single instruction — *"lay a brick every eight
  inches along this line"* — and let them run down the whole wall doing it.

Same wall, either way. The second way is shorter to *say*, because you describe the
**repeating step once** and let the helper handle the "do it all the way down" part.

That's this whole layer. We're going to meet a few helpers like that, and then use
them to **rebuild Layer 1's adder** — not by wiring, but by writing down the recipe.

---

## 1. Helper one: do the same thing to every item

The simplest helper is a little **stamping machine on a conveyor belt**: items roll
by, and it does the *same small thing* to each one.

The helper is called **`map`**. You give it (a) the small thing to do, and (b) a row
of items. It does the thing to every item and hands back the new row.

Layer 1 had a tiny tool, `flip_bit`, that flips one switch (a `1` becomes `0`, a `0`
becomes `1`). Put `flip_bit` on the conveyor belt and you flip a *whole row* of
switches at once:

`Try it ▶`
```bash
map flip_bit "1 0 1 1"     # 0 1 0 0   — every switch flipped
```

That's it. `map` = "do this little thing to each item in the row." The library even
keeps a named shortcut for "flip a whole row" — it's called `fp_word_not` — but it is
*literally just* `map flip_bit` underneath. The recipe **is** the definition.

---

## 2. Helper two: walk two rows side by side

The next helper is a **zipper**. A zipper has two rows of teeth, and it joins them
*one facing pair at a time*. Our helper does the same with two rows of items: it walks
them together and **combines each matching pair**.

It's called **`zipwith`**. You give it (a) how to combine a pair, and (b) two rows.

A natural "combine a pair" question for switches is *"are these two different?"* —
the little tool for that is `bit_xor` ("are these two switches not the same?").
Zipper two rows together asking that at every step, and you get a **"spot the
differences" map** of the two rows:

`Try it ▶`
```bash
zipwith bit_xor "1 1 0 0" "1 0 1 0"     # 0 1 1 0
#                ↑   ↑ differ here ↑      └─ 1 = "different", 0 = "same"
```

Reading along: same, **different**, **different**, same. (The named shortcut for this
one is `fp_word_xor` — again, just `zipwith bit_xor` wearing a nametag.)

> **You've quietly rebuilt a Layer-1 part.** Layer 1 had a "compare two rows of
> switches" operation. Here it fell out of one zipper and one tiny question. Same
> result, built from a recipe.

---

## 3. Helper three: sweep along, keeping a running total

The third helper is the one you use every time you add up a **grocery receipt**: you
go down the list keeping a **running total**, folding each new number into the total
as you pass it. Start at 0; see 2, total is 2; see 5, total is 7; see 1, total is 8;
see 4, total is 12.

That "sweep along, carrying a running total" move is called a **fold**. Here's one
adding up a little list:

`Try it ▶`
```bash
lsum "2 5 1 4"      # 12      (sweep the list, carrying a running total)
```

The total doesn't have to be a *number*. It can be a **yes/no** that you carry along.
Ask *"so far, has every switch been on?"* and sweep a row — that's the Layer-1
question "are **all** these switches on?":

`Try it ▶`
```bash
fp_and_all "1 1 1 1"     # true    — every switch on
fp_and_all "1 1 0 1"     # false   — swept along, hit an off switch, answer's no
fp_or_all  "0 0 0 0"     # false   — "is ANY switch on?"  none are
```

Same helper, different running total: a number for the receipt, a yes/no for the
switches. **Sweep, and carry something along.** Hold onto that — it's about to add
two numbers.

---

## 4. The big one: addition is just "carry the 1"

Remember adding on paper from Layer 1?

```
  add the ones column, write a digit, CARRY the 1 to the next column,
  add the next column PLUS that carried 1, and so on.
```

Look at what you're doing: you **sweep across the columns, carrying a 1 along.**
That's a fold! The "running total" you carry from column to column is *the carry
itself.*

So here is the adder, built as a recipe: *sweep the columns from the small end,
and at each column carry the carry along.* No wiring — one sweep.

`Try it ▶`  *(3 + 5 = 8)*
```bash
fp_word_add "1 1 0 0" "1 0 1 0"
#            └─ 3 ─┘   └─ 5 ─┘
# → 0 0 0 1 0      (read small-end-first: 0+0+0+8 = 8, last digit is the leftover carry)
```

You just added two numbers **without wiring a single thing** — only by describing
"sweep the columns, carry the carry." That recipe *is* the adder.

### The trail of little carried 1s

When you add on paper and carry a 1, you scribble a tiny `1` above the next column.
There's a cousin of the fold that, instead of only handing you the *final* running
total, hands you the **whole trail of running totals along the way**. Point it at the
carry, and it shows you **every little carried 1**, column by column:

`Try it ▶`  *(the carries while adding 3 + 5)*
```bash
fp_carry_chain "1 1 0 0" "1 0 1 0"     # 0 1 1 1 0
```

Read it small-end-first: into the **ones** column you carry nothing (`0`); then a `1`
gets carried into the **twos**, the **fours**, and the **eights** (`1 1 1`); and
nothing spills out the far end (`0`). That little row is the carry **rippling** along
— the exact scribbles you'd pencil in by hand, laid out for you to see.

---

## 5. Same answer, four different roads

Here is the moment this whole layer exists for. We now have **more than one way** to
add 3 and 5: the hand-wired adders from Layer 1, *and* the recipe-adders from this
one. Watch them all give the identical answer:

`Try it ▶`
```bash
ripple_add4 1 1 0 0 1 0 1 0              # 0 0 0 1 0   — Layer 1, four adders wired in a row
word_add    "1 1 0 0" "1 0 1 0"         # 0 0 0 1 0   — Layer 1, same idea, whole rows
fp_word_add "1 1 0 0" "1 0 1 0"         # 0 0 0 1 0   — the recipe: sweep & carry
fp_word_add_scan "1 1 0 0" "1 0 1 0"    # 0 0 0 1 0   — a DIFFERENT recipe (carries first, then fill in)
```

Four machines. Inside, they are genuinely **not the same** — one is wired by hand, one
sweeps with a running carry, one works out the whole trail of carries first and then
fills in the answer digits. You don't have to follow exactly how each one works. The
thing to feel is this: **four different roads, one destination.** Every one says `8`.

> **Why this matters — and why the project keeps doing it.** When you build the same
> thing two different ways and they agree, two good things happen. You **trust** it
> more (a mistake would have to be the *same* mistake in two unrelated places — very
> unlikely). And you **understand** it better, because you've seen the idea from more
> than one side. "Build it twice, check they match" is one of the most honest ways to
> know something is really true — and it's the heartbeat of this whole project.

---

## 6. Two more, quickly

The same helpers rebuild the rest of Layer 1's tricks, too:

- **Sliding a row** (Layer 1's "multiply or divide by 2"). Here it's not even
  arithmetic — you just **slide the row over and pad the gap with a 0**. Pure
  shuffling:
  ```bash
  fp_shl "1 1 0 0"     # 0 1 1 0   slide left  → doubled (3 → 6)
  fp_shr "1 1 0 0"     # 1 0 0 0   slide right → halved  (3 → 1)
  ```
- **Asking a whole row at once.** A yes/no question that compares *two* things (like
  "are both on?") can be swept over a *whole row* to become "are they **all** on?" —
  which is exactly the running-total fold from Section 3. One small question, folded
  down a row, becomes a question about the entire row. That's all `fp_and_all` and
  friends are.

---

## The bridge: so what *is* all this, really?

- **You just met the difference between hardware and software.** Layer 1 was like
  *building a machine by hand* — every part placed, every wire run. This layer is like
  *writing software* — you describe the repeating step once ("do this to each," "sweep
  and carry") and let a helper carry it out. Same result; one is wiring, one is words.
- **These helpers are a real, famous style of programming.** "Do this to every item,"
  "combine two rows," "sweep keeping a running total" — `map`, `zip`, and `fold` — are
  the everyday bread and butter of a whole family of programming languages. (The grand
  name for little pass-around helpers like these is *combinators*; the name doesn't
  matter, the idea does.) You've now used the core of that style to build a calculator.
- **"Build it twice, check they agree" is how real confidence is earned.** Engineers
  and mathematicians do exactly this: compute something two independent ways and see if
  the answers line up. When they do, you can stop worrying. You watched four adders do
  it.
- **Nothing magic got added — again.** Just like Layer 1 was "switches all the way
  down," this layer is "the *same* switches, described from a different angle." The
  recipe-adder still bottoms out in the very same gates from the first tutorial. We
  only changed how we *talk about* wiring them, not what's underneath.

The takeaway: a calculator isn't *one* fixed thing made *one* fixed way. The same
machine can be wired by hand or written as a recipe, and the bits don't care which
story you tell — they add up to 8 either way.

---

## Try it all yourself

```bash
source ./combinator-circuits.sh

# the helpers, one at a time
map flip_bit "1 0 1 1"                  # do-it-to-each: flip a whole row
zipwith bit_xor "1 1 0 0" "1 0 1 0"     # walk two rows, spot the differences
lsum "2 5 1 4"                          # sweep a list, keep a running total

# the payoff: addition as a recipe, and the trail of carried 1s
fp_word_add    "1 1 0 0" "1 0 1 0"      # 3 + 5  → 0 0 0 1 0  (= 8)
fp_carry_chain "1 1 0 0" "1 0 1 0"      # the carries: 0 1 1 1 0

# same answer, different roads — change the numbers and watch them stay in lockstep
word_add    "1 1 0 0" "1 0 1 0"
fp_word_add "1 1 0 0" "1 0 1 0"
fp_word_add_scan "1 1 0 0" "1 0 1 0"
```

Change the numbers. The fun is watching the hand-wired answer and the recipe answer
move together, no matter what you throw at them.

---

## Mini-glossary

| term | plain meaning |
|------|---------------|
| **map** | do the same little thing to every item in a row (a stamping conveyor belt) |
| **zipwith** | walk two rows together and combine each facing pair (a zipper) |
| **fold** | sweep along a row keeping a running total, folding each item in (a receipt) |
| **carry chain** | the trail of little 1s you carry from column to column when adding |
| **recipe** | describing a repeating step once, instead of doing every step by hand |
| **`fp_…`** | the "function-side" rebuilds — Layer 1's parts, written as recipes |
| **combinator** | the fancy name for these pass-around helper-tools (the idea is the point, not the word) |

---

*This is the flip side of **[`TUTORIAL_LAYER1.md`](TUTORIAL_LAYER1.md)**: that one wired
a calculator out of switches by hand; this one rebuilt the same machine out of recipes
and showed the two roads agree. For the precise, function-by-function reference, see
[`COMBINATOR_CIRCUITS.md`](COMBINATOR_CIRCUITS.md). And the other tutorials in the set —
**[`TUTORIAL_LAYER2.md`](TUTORIAL_LAYER2.md)** (one operator rebuilds the keypad),
**[`TUTORIAL_LAYER3.md`](TUTORIAL_LAYER3.md)** (a scientific calculator), and
**[`TUTORIAL_LAYER4_ALT_ARITHMETIC.md`](TUTORIAL_LAYER4_ALT_ARITHMETIC.md)** (stranger ways
to define number) — keep the same promise: a single humble idea, looked at from a new
angle, opens up a whole world.*
