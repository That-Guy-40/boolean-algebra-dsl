# Alternative Arithmetic, From Scratch — A Plain-English Tutorial

*What **is** a number, really? This is the "bonus level" — a no-math walkthrough of
three completely different answers to that question, each of which can still do
arithmetic. If you enjoyed Tutorials 1–3 (and especially the "everything from one
tiny piece" idea), this is the playground where we ask the same question about
**number itself.** No equations to solve. Just three strange, beautiful ideas.*

---

## How to follow along

Open a terminal in this folder and load the experimental layer:

```bash
source ./alt-arithmetic.sh
```

`Try it ▶` boxes are things to type and watch. Same game as before: *poke it,
watch it, believe it.*

> **Heads-up: this layer is gloriously slow.** It does arithmetic by *counting* —
> and every count ripples down through the actual logic gates from Tutorial 1. A
> single multiplication can take a second or two. **That slowness is the whole
> point.** These aren't meant to be fast; they're meant to make the foundations
> *visible*, so you can watch a number get built from nothing.

---

## 0. The big idea: "number" isn't one thing

We treat numbers like they're obvious — `3` is just `3`. But mathematicians and
computer scientists have discovered that "number" can be *defined* in wildly
different ways, and they all work. This tutorial builds three of them:

| model | a number is… | the everyday picture |
|-------|--------------|----------------------|
| **Peano** | zero, plus "and one more" | a pile of **tally marks** |
| **Church** | an instruction: "do this *n* times" | a **verb**, not a thing |
| **Modular** | a position on a clock | a **clock face** |

The punchline that ties them to the rest of the project: **all three bottom out in
the same logic gates.** Peano's "+1" *is* the ripple-carry adder from Tutorial 1.
A Church number can drive that same adder. And the 4-bit chip you built *is*
clock arithmetic. Different ideas of "number," one set of switches underneath.

---

## 1. Peano — a number is a pile of tally marks

The most childlike definition there is. You need just two things:

- **zero** (an empty pile), and
- **"and one more"** — a function called the **successor** (think: add a tally mark).

That's it. Every number is a tower of "and one more"s on top of zero:

```
0  =  zero
3  =  one-more(one-more(one-more(zero)))     ← three tally marks
```

And every operation is just *counting*:

- **Adding** `a + b` = "start at `a`, then do *one more* exactly `b` times."
- **Multiplying** `a × b` = "add `a` to itself `b` times."

`Try it ▶`  *(numbers go in and out as ordinary decimals via two little converters)*
```bash
peano_to_int "$(peano_add  "$(int_to_peano 2)" "$(int_to_peano 3)")"   # 5
peano_to_int "$(peano_mult "$(int_to_peano 3)" "$(int_to_peano 4)")"   # 12
```

Here's the magic trick that connects this to Tutorial 1: in our version, a Peano
number **is** a row of bits, and "and one more" **is the actual ripple-carry +1
circuit** (`inc`). So when you run `peano_add`, the counting is performed, one
tally at a time, **by the logic gates themselves**. You can watch addition happen
as a cascade of switches. (That's also why it's slow — adding 12 means rippling a
carry through the gates twelve separate times.)

> **The bigger point:** this is *literally* how mathematicians define the counting
> numbers from scratch — "zero, and a successor." You just ran that definition.

---

## 2. Church — a number is "do something *n* times"

This one will bend your brain a little, in a good way. Forget that a number is a
*thing*. What if a number were a **verb** — an instruction that says *"take some
action and repeat it this many times"*?

That's a **Church numeral**. The number `3` *is* "do it three times." It doesn't
care what "it" is — give `3` any action, and it'll do that action three times.

`Try it ▶`  *(give the number 5 a "stick a star on the end" action)*
```bash
apply "$(apply "$(int_to_church 5)" 'printf "%s*" "$1"')" ""   # *****
```

The number 5, handed a star-stamping action, stamped exactly five stars. It's a
number used as **pure repetition.**

So how do you do *arithmetic* with verbs? You compose the repetitions:

- **add** = "do *succ* (one-more) `n` times" — repetition is counting again,
- **multiply** = "do (*add m*) `n` times,"
- **power** = "do (*times b*) `e` times."

To keep the typing readable, give yourself two shorthands first:

`Try it ▶`
```bash
ch () { int_to_church "$1"; }    # make a Church number
n  () { church_to_int  "$1"; }    # read one back as a decimal

n "$(church_plus "$(ch 2)" "$(ch 3)")"   # 5
n "$(church_mult "$(ch 3)" "$(ch 4)")"   # 12
n "$(church_pow  "$(ch 2)" "$(ch 5)")"   # 32
```

### Subtraction is the hard one (and the cleverest)

If a number means "do something *n* times," then *adding* is easy (do it more
times) but *subtracting one* is genuinely tricky — how do you "un-repeat"? The
famous solution uses **pairs**: carry along two numbers, `(behind, current)`, and
at each step shuffle them forward — `(current, current+1)`. After `n` steps the
"behind" slot is sitting one step back. Take it, and you've got `n − 1`.

`Try it ▶`
```bash
n "$(church_pred "$(ch 5)")"               # 4    (one less)
n "$(church_sub  "$(ch 7)" "$(ch 3)")"     # 4    (subtract = un-one-more, repeatedly)
n "$(church_sub  "$(ch 2)" "$(ch 5)")"     # 0    (it floors at zero — no negatives here)
```

Once you can subtract, **comparing and dividing come for free** — because "is `m`
≤ `n`?" is just "does `m − n` hit zero?":

`Try it ▶`
```bash
church_lt "$(ch 2)" "$(ch 5)"              # true
church_eq "$(ch 4)" "$(ch 4)"              # true
n "$(church_div "$(ch 6)" "$(ch 2)")"      # 3
```

And the cross-layer party trick: hand a Church number the **`inc` circuit** from
Tutorial 1, starting from zero bits, and the number builds its own bit-pattern by
repeating the gate that many times:

`Try it ▶`
```bash
bits_to_int "$(church_to_bits 5)"          # 5   (the verb "do it 5×" drove the adder)
```

> **Where you've seen this before:** "a number is a function" is the heart of the
> **lambda calculus**, the idea underneath Lisp, Haskell, and functional
> programming generally. You just did arithmetic in it.

---

## 3. Modular — a number is a position on a clock

The friendliest of the three, because you already use it every day. On a 12-hour
clock, **10 + 5 = 3** — you count past 12 and wrap around. That's *modular
arithmetic*: numbers live on a ring of fixed size, and going past the top loops
back to the bottom.

`Try it ▶`
```bash
mod_add 10 5 12      # 3      (5 hours after 10 o'clock)
mod_sub 2  5 12      # 9      (5 hours before 2 o'clock)
mod_pow 2 10 1000    # 24     (2¹⁰ = 1024, but only the last "3 digits" survive)
```

Now the reveal — and it's the best one in this tutorial: **your computer already
does this, all the time.** A chip can only hold so many bits, so when a number
gets too big it *wraps around* — exactly like the clock. The 4-bit calculator you
built in Tutorial 1 is secretly a **mod-16 clock**: count past 15 and you're back
at 0. We can prove it by running the real ripple adder:

`Try it ▶`
```bash
mod_add_bits4 12 11    # 7    (12 + 11 = 23, but the 4-bit adder wraps: 23 − 16 = 7)
```

That `7` came straight out of the gates. The "overflow" warning light on the ALU?
That was the clock hand sweeping past 12. Modular arithmetic isn't an exotic
add-on — **it's what fixed-size hardware** *is.*

---

## The bridge: so what *is* all this, really?

Three answers to "what is a number," and each lands somewhere real:

- **Peano** is how numbers are *officially defined* in mathematics — start with
  zero and a successor, and build everything by recursion. When a logician says
  "the natural numbers," this pile-of-tally-marks construction is what they mean.
  You ran the definition, with logic gates doing the counting.
- **Church** is the **lambda calculus** — numbers as pure functions, "do it *n*
  times." It's the theoretical bedrock of functional programming. The fact that
  you can build *all* of arithmetic (even division and comparison) out of nothing
  but "repeat an action" is one of the genuinely astonishing results in computer
  science.
- **Modular** is everywhere the moment something has a fixed size: clocks,
  odometers rolling over, every CPU register, and the math behind **cryptography**
  (RSA, the padlock on secure websites, is modular arithmetic on huge numbers).

And the thread through all three — the same thread as the rest of this project —
is that **nothing magic gets added.** A number can be tally marks, or a verb, or a
clock position, and in every case it reduces to the same on/off switches. "Number"
turns out not to be one fixed thing but a *role* that many different ideas can
play. The switches don't care which story you tell; they just count.

---

## Try it all yourself

```bash
source ./alt-arithmetic.sh
ch () { int_to_church "$1"; }; n () { church_to_int "$1"; }

# Peano — counting with tally marks (the +1 is a real gate circuit)
peano_to_int "$(peano_mult "$(int_to_peano 3)" "$(int_to_peano 4)")"   # 12

# Church — a number is "do it n times"
apply "$(apply "$(ch 5)" 'printf "%s*" "$1"')" ""    # *****
n "$(church_pow "$(ch 2)" "$(ch 5)")"                # 32
n "$(church_div "$(ch 13)" "$(ch 4)")"               # 3

# Modular — clock arithmetic, which is what the hardware already does
mod_add 10 5 12        # 3
mod_add_bits4 12 11    # 7   (= 23 on a 16-hour clock)
```

Try changing the numbers. Keep them small (these are slow!), and notice that the
*answers* are ordinary — it's the *route* to them that's strange and wonderful.

---

## Mini-glossary

| term | plain meaning |
|------|---------------|
| **Peano arithmetic** | numbers as "zero + one-more-one-more-…"; the textbook way to define ℕ |
| **successor** | the "and one more" step; here it's the real `+1` gate circuit |
| **Church numeral** | a number as an *instruction*: "repeat an action *n* times" |
| **lambda calculus** | the math of functions-as-values; Church numerals live here |
| **predecessor** | "one less" — surprisingly hard for Church numbers; solved with pairs |
| **monus** | subtraction that floors at 0 (no negatives), like `2 − 5 = 0` here |
| **modular arithmetic** | clock math: count past the top and wrap to 0 (ℤ mod *n*) |
| **wraparound / overflow** | what fixed-size numbers do at the top of the clock |

---

*This is the experimental wing of the project; for the precise, function-by-function
reference (and a fourth round of "future models" to explore), see
[`ALT_ARITHMETIC.md`](ALT_ARITHMETIC.md). And if you wandered in here first, the main
trilogy — [`TUTORIAL_LAYER1.md`](TUTORIAL_LAYER1.md), [`TUTORIAL_LAYER2.md`](TUTORIAL_LAYER2.md),
[`TUTORIAL_LAYER3.md`](TUTORIAL_LAYER3.md) — builds the switches, the math operator, and
the calculator that everything here quietly stands on.*
