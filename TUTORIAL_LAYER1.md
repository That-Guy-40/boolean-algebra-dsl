# Layer 1, From Scratch — A Plain-English Tutorial

*How a pile of yes/no switches becomes a working calculator — explained for
someone who is not a math person and has never written a logic gate in their
life. No equations you need to "solve." If you can follow a recipe and count on
your fingers, you can follow this.*

---

## How to follow along

Everything below is something you can actually run and watch. Open a terminal in
this folder and load the library once:

```bash
source ./boolean-funcs-new.sh
```

Now every function in the file is a command you can type. Whenever you see a
`Try it ▶` box, type the command and compare. That's the whole game: *poke it,
watch it, believe it.*

---

## 0. The one idea under everything: a computer is a mountain of yes/no

Forget numbers for a second. At the very bottom, a computer doesn't know about 5
or 100 or 3.7. It only knows **on** or **off** — a switch that's either flipped
up or down. We call those two states a lot of names depending on mood:

| up | down |
|----|------|
| on | off |
| yes | no |
| **true** | **false** |
| **1** | **0** |

That's it. That's the whole alphabet. The astonishing thing — and the thing this
project demonstrates by *building it* — is that **you can make everything else
out of nothing but those two states and a few simple rules.** Adding, comparing,
negative numbers, a tiny calculator chip: all of it is just yes/no, stacked very
cleverly.

"Layer 1" is the layer where we do exactly that: start with yes/no, end with a
4-bit calculator.

---

## 1. The one weird thing you must know first: here, **0 means "yes"**

This trips up *everybody*, so let's get it out of the way.

In this code, **success is 0 and failure is 1** — backwards from what you'd
guess. Here's the honest reason: in a terminal, when a program finishes, it
reports "how many problems did I hit?" Zero problems means it worked. Any other
number means something went wrong.

> **Think of it like a golf score, or counting mistakes on a test.** Lowest wins.
> Zero mistakes = perfect = "yes, success." That's why `0` is the *good* answer.

So in this library:

```bash
true   # quietly reports 0  ("zero problems — yes")
false  # quietly reports 1  ("one problem — no")
```

`Try it ▶`
```bash
true;  echo $?    # prints 0
false; echo $?    # prints 1
```
(`$?` means "what did the last command report?")

You don't have to *like* this. You just have to remember: **when the code looks
upside-down, this is why.** (Fun fact: the one real bug this project ever had came
from exactly this mix-up — a part that thought the digit `0` meant "false" when
the rest of the system read it as "yes." We'll wave at it again later.)

Every gate you're about to meet does **two things at once**:
1. it **prints** the word `true` or `false` so *you* can read the answer, and
2. it quietly hands the next command that 0/1 success signal so *machinery* can
   chain together.

You only ever need to watch #1. The plumbing takes care of #2.

---

## 2. Gates: vending machines for yes/no

A **gate** is the simplest possible machine: feed it one or two yes/no values,
and it spits out one yes/no value, *always following the same fixed rule.*

The three you already use in everyday speech:

- **AND** — "are *both* true?" → true only when both inputs are true.
- **OR** — "is *either* one true?" → true when at least one input is true.
- **NOT** — "give me the opposite."

You don't need a formula; you already think this way. *"I'll go for a walk if it's
not raining AND I have time."* That's an AND gate in a sentence.

`Try it ▶`
```bash
and true false     # false   — both? no.
or  true false     # true    — either? yes.
not true           # false   — opposite of true.
```

The full "rulebook" for a gate is called a **truth table** — just a list of every
possible input and what comes out. AND's whole life:

| A | B | A AND B |
|---|---|---------|
| true | true | **true** |
| true | false | false |
| false | true | false |
| false | false | false |

Four rows, because two yes/no inputs only have four combinations. Every gate is
just a four-row (or two-row) rulebook. There's nothing hidden.

The library also ships the "fancier" gates, which are still just rulebooks:

- **XOR** (function name `ne`, "not equal") — "are they *different*?"
- **XNOR** (`eq`, "equal") — "are they the *same*?"
- **NAND**, **NOR** — AND/OR with the answer flipped at the end.
- even **if-then** (`if_then`), the logician's "implies."

---

## 3. The magic Lego brick: you only need **one** gate

Here's a genuinely beautiful fact, and it's why real computer chips are buildable
and cheap: **you don't need all those gates. You need one.** The whole zoo can be
grown from a single gate called **NAND** ("not-and" — true *unless both inputs
are true*).

Watch the library do it. It defines NAND first, then grows everything else:

```bash
not A      =  nand A A          # feed the same thing into both slots
and A B    =  not (nand A B)    # NAND, then un-flip it
or  A B    =  nand (not A) (not B)
```

> **Analogy:** it's like discovering that every Lego sculpture in the world could
> be made from one shape of brick, or that every word is built from the same 26
> letters. NAND is the universal brick. Real silicon chips lean on this hard —
> a factory that can stamp out one kind of gate really well can build *anything.*

`Try it ▶`
```bash
nand true true    # false  (the only time NAND says no)
nand true false   # true
```

You've now seen the entire foundation. **Everything from here up is just gates
wired together.** No new kind of magic — only more wiring.

---

## 4. Making numbers out of switches: binary and "bits"

To do arithmetic we need numbers, and we only have on/off switches. So we count
the way a two-fingered creature would: in **binary**.

Remember grade-school place value? In our normal (decimal) system, `347` means:

```
  3        4        7
hundreds  tens     ones
(×100)   (×10)    (×1)
```

Each box is worth **10×** the box to its right. Binary is the exact same idea,
except each box is worth **2×** the one to its right — and the only digits
allowed are 0 and 1:

```
 ...  8s    4s    2s    1s
       1     0     1     0   =  8 + 0 + 2 + 0  = 10
```

A single 0-or-1 digit is called a **bit**. A row of bits is a number.

### The "backwards" order (LSB-first)

This library writes its bit-rows **smallest box first** — the ones, then the
twos, then the fours. This is called **LSB-first** ("least significant bit
first"). So the number 5 (= 4 + 1) is written:

```
 1   0   1
1s  2s  4s     →  1 + 0 + 4  =  5
```

> **Why backwards?** Same reason some people write the date as day/month/year
> instead of year/month/day. It's the *same information*, just starting from the
> small end. Computers find "small end first" convenient because that's the end
> where addition starts (you add the ones column first — see the next section).

You never have to do this conversion by hand. Two helpers do it:

`Try it ▶`
```bash
int_to_bits 5        # 1 0 1        (5 as bits, small end first)
int_to_bits 5 6      # 1 0 1 0 0 0  (the same 5, padded to 6 boxes)
bits_to_int "1 0 1"  # 5            (and back again)
```

---

## 5. Addition: it's literally the way you add in 2nd grade

Here's the payoff. You already know how to add `27 + 15` on paper:

```
  27
+ 15
----
 add the ones:  7 + 5 = 12  → write 2, CARRY the 1
 add the tens:  2 + 1 + (carried 1) = 4
----
  42
```

Two ideas do all the work: **add one column at a time**, and **carry** the
overflow into the next column. Binary addition is *exactly* this, just with
columns worth 1, 2, 4, 8 instead of 1, 10, 100.

The library builds it in three nesting-doll steps:

**Step 1 — the half adder.** Add two single bits. There are only four cases, and
the interesting one is `1 + 1`: in binary that's "2," which you write as `0`
with a `1` carried — exactly like `7 + 5` giving "2 carry 1."

`Try it ▶`
```bash
half_adder 1 1     # 0 1   →  "result bit 0, carry a 1"
```

(Under the hood: the result bit is "are they different?" = XOR, and the carry is
"are they both 1?" = AND. Two gates from Section 2. That's the whole adder.)

**Step 2 — the full adder.** A half adder can't accept a carry *coming in* from
the column to its right. The full adder can: it adds **three** bits — A, B, and
a carry-in — and reports a result bit plus a carry-out.

`Try it ▶`
```bash
full_adder 1 1 1   # 1 1   →  "1 + 1 + 1 = 3 = result 1, carry 1"
```

**Step 3 — the ripple adder.** Now just line up four full adders, one per column,
and **let each one hand its carry to the next** — the carry "ripples" left, just
like the `1` you carried from the ones to the tens. That's `ripple_add4`.

`Try it ▶`  *(3 + 5 = 8)*
```bash
ripple_add4   1 1 0 0   1 0 1 0
#             └─ 3 ─┘   └─ 5 ─┘
# → 0 0 0 1 0
#   └─ 8 ─┘ ↑
#           └ final carry-out (0 here: 8 fit in 4 boxes)
```

Read the result `0 0 0 1` smallest-box-first: `0 + 0 + 0 + 8 = 8`. **You just
watched addition happen with nothing but yes/no switches.** Stack two of these
and you get `ripple_add8` for bigger numbers — same trick, eight columns.

---

## 6. Negative numbers & subtraction: the odometer trick

How do you store a *negative* number using only 0s and 1s? There's no minus-sign
switch. Computers use a delightfully sneaky trick called **two's complement**.

> **Picture a car's odometer reading `0000`.** Roll it *backward* one click and it
> flips to `9999`. Everyone understands that `9999`, in that moment, "means" −1 —
> it's "one before zero." Computers do the same with bits: the bit pattern that
> sits "one click before zero" is agreed to *mean* −1.

The recipe to negate a number is wonderfully mechanical: **flip every bit, then
add 1.** (`flip_bit` does the flipping; the `+1` reuses the adder you just built.)

And once you can make a negative, **subtraction is free**: `A − B` is just
`A + (−B)`. So `ripple_sub4` does exactly that — flips B's bits, adds 1, and runs
the ordinary adder.

`Try it ▶`  *(5 − 3 = 2)*
```bash
ripple_sub4   1 0 1 0   1 1 0 0
#             └─ 5 ─┘   └─ 3 ─┘
# → 0 1 0 0 1
#   └─ 2 ─┘ ↑
#           └ this trailing 1 means "no borrow needed" (the answer is ≥ 0)
```

Try `3 − 5` and that trailing flag becomes `0` — the machine's way of raising its
hand to say *"heads up, the answer went negative."* Same circuit, no new parts.

---

## 7. Comparing two numbers: read the big digits first

To add, we started from the *small* end. To compare which of two numbers is
bigger, smart money starts from the *big* end.

> **Analogy:** which is more, **\$480** or **\$390**? You don't tally every digit —
> you glance at the hundreds place (4 vs 3) and you're *done.* The first place
> where they differ decides the whole contest.

That's precisely what `bits_gt` does: it scans from the most significant box
downward, and the first box where the two numbers disagree settles it. The
friendly wrapper `compare4` just prints the verdict in English: `lt`, `eq`, `gt`
(less-than, equal, greater-than).

`Try it ▶`
```bash
compare4   1 0 1 0   1 1 0 0     # 5 vs 3  → gt
compare4   1 1 0 0   1 0 1 0     # 3 vs 5  → lt
compare4   0 0 0 1   1 1 1 0     # 8 vs 7  → gt
```

That last one is the sly case. The number 7 has *three* 1-bits and 8 has only
*one* — so a naive "count the on-switches" approach would wrongly call 7 the
winner. But the single 1 in 8 sits in a *more valuable box* (the 8s place), and
"read the big digits first" gets it right every time. Position beats quantity —
just like one \$100 bill beats ninety-nine \$1 bills.

---

## 8. Multiply or divide by 2: just slide the digits

In decimal, multiplying by 10 is lazy: stick a 0 on the end. `12 → 120`. In
binary, the magic number is 2, and "sliding" the digits one box over multiplies
or divides by 2. This is called **shifting**.

`Try it ▶`
```bash
shl "1 1 0 0"     # shift left  → 0 1 1 0   (3 became 6 — doubled)
shr "1 1 0 0"     # shift right → 1 0 0 0   (3 became 1 — halved, remainder dropped)
```

`shl` = shift left = ×2. `shr` = shift right = ÷2. That's the whole story.

---

## 9. A couple of handy helpers

The library has a drawer of small conveniences built from the same parts. A few
worth meeting:

- **`mux`** — a *railroad switch* for bits. You hand it a selector and two
  inputs; the selector decides which input comes out the other end.
  ```bash
  mux 0 1 0    # 1   (selector 0 → pick the first input)
  mux 1 1 0    # 0   (selector 1 → pick the second)
  ```
- **`bits_min` / `bits_max`** — smallest / largest of two numbers, built by
  *combining* the comparator from Section 7 with the railroad switch above:
  compare, then route the winner through.
  ```bash
  bits_min "1 1 0 0" "1 0 1 0"   # 1 1 0 0   (min of 3 and 5 = 3)
  bits_max "1 1 0 0" "1 0 1 0"   # 1 0 1 0   (max = 5)
  ```
- **`inc` / `dec`** — add or subtract 1. **`is_even` / `is_odd`** — odd/even.
  **`parity`** — counts *how many switches are on* and reports whether that count
  is odd. (Careful: that's about the **number of 1-bits**, not whether the value
  is odd. The number 3 = `1 1 0 0` has *two* on-switches, so its parity is `0`
  even though 3 itself is an odd number. Different question!)

---

## 10. The grand finale: a tiny calculator chip (the ALU)

An **ALU** ("arithmetic-logic unit") is the part of a real CPU that actually does
the math. Ours, `alu4`, ties *everything in this tutorial* into one box.

Think of it like a pocket calculator: you punch in **an operation** (`add`,
`sub`, `and`, `or`, `xor`, compare, shift…) and **two 4-bit numbers**, and it
hands back the answer — plus a little row of **warning lights**, just like the
indicator lights on a car dashboard:

| light | name | lights up when… |
|-------|------|-----------------|
| **Z** | Zero | the answer is exactly 0 |
| **C** | Carry | the addition spilled over the top box |
| **N** | Negative | the answer is negative (the odometer trick from §6) |
| **V** | oVerflow | the numbers were too big and the answer "wrapped around" |

`Try it ▶`  *(3 + 5)*
```bash
alu4 add   1 1 0 0   1 0 1 0
# → 0 0 0 1   0 0 1 1
#   └─ 8 ─┘   Z C N V
```

The answer boxes say `0 0 0 1` = 8 — correct! But look at the lights: `N` and `V`
are lit. Why? Because in a *signed* 4-bit world, the boxes can only hold −8…+7,
and 8 doesn't fit. It "wrapped around" past the top and came out looking like a
negative number (`N`), and the chip flagged the overflow (`V`) to warn you. This
is not a bug — it's the chip being honest that 8 won't fit in 4 signed bits, the
same way a cheap calculator shows `E` when a number is too long.

`Try it ▶`  *(5 − 3 = 2, a clean result)*
```bash
alu4 sub   1 0 1 0   1 1 0 0
# → 0 1 0 0   0 1 0 0
#   └─ 2 ─┘   Z C N V   (only C lit: "no borrow," all good)
```

And that's Layer 1: from a single on/off switch, up through one universal gate,
to a chip that adds, subtracts, compares, shifts, and reports its own status.

---

## The bridge: so what *is* all this, really?

If the abstractness still itches, here's how each piece maps onto the real world
and "real" math:

- **A bit is a switch, and a switch is a tiny voltage.** Inside a chip, "on" is a
  bit of electricity present, "off" is none. Billions of microscopic switches
  called **transistors** are the physical thing. Everything here is a paper model
  of that.
- **Gates are real, physical objects.** The AND/OR/NOT/NAND you typed are not
  metaphors — they're actual arrangements of a handful of transistors etched into
  silicon. We just wrote them as shell functions instead of wiring.
- **"NAND builds everything" is why chips are affordable.** A foundry that
  perfects one gate can compose all logic from it. You reproduced that result on
  your keyboard.
- **Binary isn't exotic math — it's counting with two fingers.** The only "math"
  in this entire tutorial is *place value* (which you learned around age 7) and
  *yes/no logic* (which you use every time you say "if it's not raining"). No
  algebra, no formulas to solve.
- **The ripple adder is the 2nd-grade carry algorithm**, frozen into wiring. The
  comparator is "check the big digits first." Two's complement is an odometer.
  The whole subject is ordinary intuition, made mechanical and exact.
- **The ALU is a CPU in miniature.** The chip in your phone has a vastly bigger,
  faster version of `alu4` at its heart, doing the same four-flag dance billions
  of times a second. You now know, concretely, what's happening down there.

The big takeaway: **there is no point in this stack where something mysterious
gets added.** It's switches all the way down, plus the patience to wire them
cleverly. That's the secret of computers — not that they're smart, but that
simple yes/no rules, stacked high enough, *look* like intelligence.

> **A mirror-image world (for later).** Everything here grew from one tiny piece — a
> **switch** — stacked cleverly. Astonishingly, there's a *completely different*
> starting piece that builds all the same things: not a switch, but a tiny
> **function**, a little machine that takes a machine and hands one back. That mirror
> image is the **function-side twin of Layer 1**, with its own plain-English
> walkthrough in **[`TUTORIAL_LAYER6_LAMBDA.md`](TUTORIAL_LAYER6_LAMBDA.md)**: same
> destination (numbers, true/false, arithmetic), opposite starting point. The
> jaw-dropper is that the two turn out to be *exactly as powerful as each other* — one
> of the deepest facts in all of computing.

---

## Try it all yourself

```bash
source ./boolean-funcs-new.sh     # load everything

# walk back up the layers:
not false                          # a gate
half_adder 1 1                     # add two bits
ripple_add4 1 1 0 0  1 0 1 0       # add two numbers   (3 + 5 = 8)
compare4   1 0 1 0   1 1 0 0       # compare           (5 vs 3 → gt)
alu4 add   1 1 0 0   1 0 1 0       # the whole chip
```

Change the numbers. Break them. Try `ripple_add4 1 1 1 1 1 1 1 1` (15 + 15) and
watch the carry-out light up. The fastest way to *believe* this is to keep poking
it until it stops surprising you.

---

## Mini-glossary

| term | plain meaning |
|------|---------------|
| **bit** | a single yes/no (1/0) switch |
| **binary** | counting where each place is worth 2× the last (instead of 10×) |
| **LSB-first** | writing the smallest-value bit first ("ones" before "twos") |
| **gate** | a tiny machine: yes/no in → yes/no out, by a fixed rule |
| **truth table** | the complete rulebook for a gate (every input → its output) |
| **NAND** | the one universal gate; "true unless both inputs are true" |
| **half / full adder** | circuits that add two (or three) bits with a carry |
| **ripple adder** | several adders chained so the carry "ripples" along — addition |
| **two's complement** | the odometer trick for storing negative numbers |
| **comparator** | circuit that says which of two numbers is bigger (big digits first) |
| **shift** | sliding bits to multiply (`shl`) or divide (`shr`) by 2 |
| **mux** | a railroad switch: pick one of two inputs |
| **ALU** | the calculator chip — op + two numbers → answer + status lights |
| **flags (Z C N V)** | dashboard lights: Zero, Carry, Negative, oVerflow |

---

*Next stop, if you're curious: **[`TUTORIAL_LAYER2.md`](TUTORIAL_LAYER2.md)** leaves
yes/no behind and pulls the exact same "build everything from one tiny piece" trick,
but with **continuous** math — real numbers, `exp`, `ln`, sine, square roots — using
a single operator called `eml`. (For the full technical reference across all three
layers, see `OVERVIEW.md`.) The spirit is identical: one humble piece, stacked
cleverly, becomes a whole world.*
