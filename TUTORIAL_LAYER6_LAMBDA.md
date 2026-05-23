# Layer 6: Three Little Machines That Build Everything — A Plain-English Tutorial

*Layer 1 built a whole calculator out of one humble piece — a single kind of switch.
This layer pulls the **exact same trick on the other side of the world**: it builds
all of computing out of nothing but **little machines that take a machine and hand
back a machine.** That's the famous **lambda calculus**, the "function side" of
computing. It sounds abstract, but it lands on something almost silly: three tiny
machines, and everything else falls out. No equations to "solve." If you got through
Layer 1, you can do this.*

---

## How to follow along

Open a terminal in this folder and load this layer:

```bash
source ./lambda.sh
```

The little machines live in variables with names like `$SKI_I`, `$SKI_K`, `$SKI_S`
(the `$` just means "the machine stored under this name"). To run a machine, we hand
it things with a helper called **`applyc`** — read it as *"feed this machine the
following things, one at a time."*

Same game as ever: when you see a `Try it ▶` box, type it and watch. *Poke it, watch
it, believe it.*

---

## 0. The big idea: everything is a little machine

In Layer 1, the whole world was **switches** — on/off, and nothing else. Here the
whole world is **little machines, each with one slot.** You drop one thing into the
slot, and one thing comes out.

The wild part — the part that makes this a *different universe* from Layer 1 — is
that **the things you drop in, and the things that come out, are also little
machines.** There are no numbers here. No text. No switches. *Only machines, handing
machines to machines.*

And yet — exactly like Layer 1 grew a calculator out of one gate — you can grow
**numbers, true/false, and arithmetic** out of nothing but machines passing each
other around. Layer 1's motto was "switches all the way down." This layer's motto is
**"machines all the way down."**

> **The headline, up front:** Layer 1 needed only **one** kind of gate (NAND) to
> build everything. Over here, you need only a **tiny handful** of machines — really
> just **three**, named **S**, **K**, and **I**. Meet them and you've met the whole
> foundation.

---

## 1. The do-nothing machine: **I**

The simplest machine there could possibly be. You hand it something; it hands the
same thing right back. That's the entire machine.

> **It's the coat-check that loses interest.** You hand over your coat, and it
> immediately hands you your coat back. Useless? Surprisingly not — "do nothing" is a
> real, useful move, the way `0` is a real, useful number.

`Try it ▶`
```bash
applyc "$SKI_I" mug      # mug   — you handed it "mug", you got "mug" back
```

---

## 2. The keepsake machine: **K**

Hand **K** something, and it *pockets it* — and turns into a new machine that ignores
whatever you feed it next and always coughs back up the thing it pocketed.

> **It's a fridge magnet of your first answer.** Tell it "blue." From then on, ask it
> *anything* — "what's for dinner?", "what year is it?" — and it just says "blue."
> It kept the first thing and stopped listening.

Here's a small but important thing about these machines: **each one has only one
slot.** So how does K deal with *two* things — the one to keep and the one to ignore?
You feed them **one at a time.** Drop in the first thing; out pops a machine "primed"
with it; drop the second thing into *that*. (`applyc` just does this feeding for you.)

`Try it ▶`
```bash
applyc "$SKI_K" keep toss     # keep   — kept the first, threw away "toss"
```

---

## 3. The wiring machine: **S** (and a magic trick)

The third machine is the clever one. **S** is a little **switchboard**: hand it two
helper-machines and then one thing, and it *shares* that one thing between both
helpers and wires their results together. It's the glue — and it's the reason just a
*few* machines are enough to build everything.

You don't need to trace exactly how S does its wiring. Watch what it makes *possible*
instead — because here's the magic trick:

> **You don't even need the do-nothing machine.** Wire **S**, then **K**, then **K**
> together, feed it anything… and you get that thing right back. You just *built* the
> do-nothing machine out of the other two.

`Try it ▶`
```bash
applyc "$SKI_S" "$SKI_K" "$SKI_K" anything     # anything   — S K K behaves exactly like I
```

That's the same kind of beautiful surprise as Layer 1, where **NOT** turned out to be
buildable from **NAND**. Here, the do-nothing machine **I** is really just **S K K**
in disguise. The pieces are even fewer than they first looked.

---

## 4. A few more machines you can build

Once you have the three, you can wire up other handy machines. The friendliest is
**"do one thing, then another"** — feed something through one machine, then push the
result through a second:

`Try it ▶`  *(stick a `?` on, then a `!`)*
```bash
applyc "$SKI_B" 'printf "%s!" "$1"' 'printf "%s?" "$1"' hi     # hi?!
```

That "do-this-then-that" machine is `$SKI_B`. (If the second part looks familiar, it
should: it's the very same **"do one thing then another"** idea as `compose` from the
Layer 5 tutorial.) There are a couple more in the box — `$SKI_C` **swaps the order**
of two inputs, and `$SKI_W` **uses one input twice** — built, like everything here,
from S, K, and I.

---

## 5. True and false are **choosers**

In Layer 1, a yes/no was a *switch*. Here there are no switches — so what is "true"?

A wonderful answer: **true and false are machines that pick between two things.**
"True" keeps the **first** of two things you offer it; "false" keeps the **second.**
That's the whole definition. And look closely — *"keep the first of two things"* is
exactly the **keepsake machine** from Section 2!

`Try it ▶`
```bash
applyc "$LAMBDA_TRUE"  yes no     # yes   — true picks the first
applyc "$LAMBDA_FALSE" yes no     # no    — false picks the second
```

So "true" isn't a new idea at all — it's the keepsake machine **K** wearing a
different hat. Yes/no, rebuilt out of pure machinery. (This is the same shape-shift
you saw in Layer 4, where a *number* turned out to "be" a verb. Here a *truth value*
turns out to "be" a chooser.)

---

## 6. A number is "do it that many times"

You met this idea in Layer 4: a number can *be* an instruction — **"do something this
many times."** The lambda calculus builds its numbers exactly that way, out of the
three machines:

- **zero** = "do the action *no* times" (just hand back the starting thing — which,
  amusingly, is the same machine as *false*),
- and a **"+1" machine** that takes a number and tacks on **one more** repeat.

Stack the "+1" machine up and you've built the counting numbers from nothing.

`Try it ▶`  *(give the number 3 the action "stamp a star," starting from nothing)*
```bash
applyc "$(lambda_church 3)" 'printf "%s*" "$1"' ''     # ***   — it stamped exactly three stars
```

`Try it ▶`  *(and we can read a built-up number back as an ordinary count)*
```bash
lambda_church_to_int "$(lambda_church 5)"              # 5
```

> **The same numbers you already met.** These are *literally* the Church numbers from
> the Layer 4 tutorial — built a different way, but the same idea. If you load that
> layer too (`source ./alt-arithmetic.sh`), its `int_to_church 3` stamps the same
> three stars. Two roads, one set of numbers — the project's favorite kind of result.

---

## 7. The other way to watch it: crunching the symbols

So far we've been **running** the machines. There's a second way to see the whole
thing, and it's lovely: write the machines as **plain letters on a line** and *crunch
them down* with a few find-and-replace rules — the way you'd simplify a long sum step
by step, or follow a recipe's instructions in order.

There are just three rules (the same three machines, written as crunching steps):

- **give-back:** an `I` in front of something → just that something.
- **keepsake:** a `K` in front of two things → just the first one.
- **wiring:** an `S` in front of three things → share the third with the other two.

`Try it ▶`  *(`lc_normalize` crunches all the way to the end)*
```bash
lc_normalize 'I thing'            # thing
lc_normalize 'K a b'              # a
lc_normalize 'S K K x'            # x          ← there's our magic trick again: S K K = give-back
lc_normalize 'S (K S) K f g x'    # f (g x)    ← and "do one thing then another" falls out too
```

And you can watch it happen one step at a time. Here is the number **1** (built as
"+1 applied to zero") being handed an action `f` and a starting point `x`, crunching
down to "do `f` once":

`Try it ▶`
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

Eight little find-and-replace steps, and a tangle of S's and K's melts into the
simple answer **`f x`** — "do f once." Nothing was added; the rules just shuffled the
machines around until the meaning was plain.

> **Two views, one answer** (the project's heartbeat, one more time). You can *run*
> the machines (Sections 1–6) or *crunch the symbols* (this section), and they agree:
> `S K K` is the do-nothing machine either way, and the number 3 means "do it three
> times" either way.

---

## The bridge: so what *is* all this, really?

- **This is one of the two great answers to "what can a computer do?"** A
  mathematician named **Alonzo Church** invented the lambda calculus in the 1930s.
  (The "lambda" is a Greek letter, λ, he used for "here comes a function" — we dodged
  the symbol entirely; you didn't miss anything.) At the *very same time*, **Alan
  Turing** invented his machine — a tape and a little rule-follower, the distant
  ancestor of Layer 1's chip. Two completely different pictures of computing.
- **The jaw-dropper:** the two turned out to be **exactly as powerful as each other.**
  Anything one can compute, the other can too. That equivalence is the **Church–Turing
  thesis**, and it's a load-bearing idea in all of computer science. (This project is
  quietly marching toward *showing* it: a Turing machine is the next layer to build,
  and then we can compute the same thing both ways and watch them agree.)
- **It's the root of a whole style of programming.** "Everything is a function you
  pass around" is the soul of languages like Lisp and Haskell — and of the `map` and
  `fold` helpers from the Layer 5 tutorial. You've now seen where they come from.
- **And, as always: no magic got added.** Layer 1 was switches all the way down. This
  is machines handing machines to machines, all the way down. Numbers, truth,
  arithmetic — all of it is just a tiny handful of those machines, stacked cleverly.
  Different world, same secret.

---

## Try it all yourself

```bash
source ./lambda.sh

# the three machines
applyc "$SKI_I" mug                              # do-nothing: mug
applyc "$SKI_K" keep toss                        # keepsake:   keep
applyc "$SKI_S" "$SKI_K" "$SKI_K" anything       # S K K = do-nothing again

# true/false are choosers; numbers are "do it N times"
applyc "$LAMBDA_TRUE"  yes no                     # yes
applyc "$(lambda_church 3)" 'printf "%s*" "$1"' ''   # ***
lambda_church_to_int "$(lambda_church 5)"         # 5

# crunch the symbols instead of running the machines
lc_normalize 'S K K x'                            # x
lc_trace "$(lc_church 2) f x"                     # watch "2" become  f (f x)
```

Change things. Feed the machines different words; build bigger numbers (keep them
smallish). The fastest way to *believe* "everything is just functions" is to keep
poking until it stops feeling impossible.

---

## Mini-glossary

| term | plain meaning |
|------|---------------|
| **little machine / function** | a box with one slot: drop one thing in, one thing comes out |
| **I** | the do-nothing machine — hands back what you gave it |
| **K** | the keepsake machine — keeps the first thing, ignores the rest |
| **S** | the wiring machine — shares one input between two helpers and joins them |
| **one slot at a time** | a machine takes one thing; feed it several by handing them over one by one |
| **S K K = I** | wiring S, K, K together rebuilds the do-nothing machine (you need very few pieces) |
| **chooser (true/false)** | a machine that picks the first (true) or second (false) of two things |
| **Church number** | a number built as "do an action this many times" |
| **crunch / reduce** | simplify a line of machine-letters by find-and-replace rules |
| **lambda calculus** | building all of computing from nothing but functions; λ is Church's symbol |
| **combinator** | the fancy name for these little machines (the idea matters, not the word) |

---

*This is the **function side** of the project's grand idea. **[`TUTORIAL_LAYER1.md`](TUTORIAL_LAYER1.md)**
built the *machine* side out of switches; this layer built an equal-and-opposite world
out of functions, and the punchline still to come is that the two are secretly the
same power. For the precise reference, see [`LAMBDA.md`](LAMBDA.md). The rest of the set:
the core trilogy **[`TUTORIAL_LAYER2.md`](TUTORIAL_LAYER2.md)** and **[`TUTORIAL_LAYER3.md`](TUTORIAL_LAYER3.md)**,
plus the companions **[`TUTORIAL_LAYER4_ALT_ARITHMETIC.md`](TUTORIAL_LAYER4_ALT_ARITHMETIC.md)**
(stranger ways to define number) and **[`TUTORIAL_LAYER5_COMBINATORS.md`](TUTORIAL_LAYER5_COMBINATORS.md)**
(the same calculator, rebuilt from recipes). One idea, told many ways: humble pieces,
stacked cleverly, become a whole world.*
