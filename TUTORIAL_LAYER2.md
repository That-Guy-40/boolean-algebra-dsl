# Layer 2, From Scratch — A Plain-English Tutorial

*How a single math operation rebuilds the entire calculator keypad — explained
for someone who is not a math person and would rather chew glass than read a
proof. No equations to "solve." If you got through the Layer 1 tutorial, you are
more than ready for this one. (If you didn't, peek at [`TUTORIAL_LAYER1.md`](TUTORIAL_LAYER1.md)
first — this is the sequel, and it leans on the same big idea.)*

---

## How to follow along

Same as before. Open a terminal in this folder and load the library once:

```bash
source ./boolean-funcs-new.sh
```

Now every function is a command you can type. When you see a `Try it ▶` box, run
it and watch. Same game as Layer 1: *poke it, watch it, believe it.*

> **Heads-up about the output.** Layer 1 dealt in tidy 0s and 1s. Layer 2 deals
> in *real numbers* — decimals — so the answers come out with a long tail of
> digits, like `8.00000000000000000099`. **That's not a bug.** The calculator
> engine underneath (a tool called `bc`) shows ~20 digits of its work, and the
> last digit or two is just rounding fuzz that builds up along the way. Read
> `8.00000000000000000099` as "8, and the computer showing off." We'll come back
> to *why* the fuzz appears — it's actually the whole point.

---

## 0. The big idea: it's the Layer 1 plot all over again

Here's the one sentence that makes this whole layer click:

> **Layer 1 showed that one logic gate (NAND) can build all of logic. Layer 2
> shows that one math operation can build all of arithmetic.**

In the first tutorial, the punchline was that you don't need separate AND, OR,
NOT machines — you can grow every one of them from a single universal brick
called NAND. It felt like a magic trick.

Layer 2 pulls the *exact same trick*, but up in the world of real numbers —
decimals, fractions, the stuff on a calculator. You'd assume you need separate
machinery for adding, subtracting, multiplying, dividing, raising to powers, even
sine and cosine. **You don't.** There's a single operation — its name is `eml` —
that, with the help of the humble number `1`, can rebuild *all of it.*

`eml` is, quite literally, **the NAND of continuous math.** Everything below is
just wiring `eml` to itself in clever ways. No new magic — only more wiring. Same
as last time.

---

## 1. Meet the two halves: "grow" and "un-grow"

To understand `eml`, you only need a feel for two famous functions. You do **not**
need to compute them by hand, ever. Just get the *vibe.*

### `exp` — the growth dial

`exp(x)` means "**e** raised to the power x." Don't panic at "e" — it's just a
special number, about `2.718`, that shows up everywhere in nature when things grow
smoothly: money earning interest, populations, a hot coffee cooling. Think of `e`
as "π's cousin, but for growth instead of circles."

What matters is the *shape*: `exp` takes a number and **blows it up**.

```
exp(0) = 1        (no growth yet)
exp(1) = 2.718…   (= e)
exp(2) = 7.389…   (bigger)
exp(5) = 148.4…   (rocketing away)
```

> **Picture inflating a balloon.** Feed in a bigger number, get a much bigger
> balloon. `exp` is the air pump.

### `ln` — the undo button

`ln` (the "natural logarithm") is `exp` **run backwards.** Whatever `exp` blew up,
`ln` brings back down. They're a matched pair of opposites, like a zip/unzip, or
encrypt/decrypt, or inflating vs. deflating that balloon.

```
ln(1)     = 0       (exp(0) was 1, so ln brings it back to 0)
ln(2.718) = 1       (exp(1) was e, so ln of e is 1)
ln(7.389) = 2
```

> **The one thing to remember:** `exp` grows, `ln` un-grows, and doing one then
> the other lands you right back where you started. That's the entire
> relationship. That cancelling-out is the lever this whole layer pulls.

`Try it ▶`
```bash
eml_exp 1     # 2.71828…   (grow: e)
eml_exp 0     # 1
eml_ln  1     # 0.00000…   (un-grow back to nothing)
```

---

## 2. The one operator: `eml`

Now the star of the show. The whole layer is built on this one little machine:

> **`eml(x, y)` = grow the first number, un-grow the second number, then subtract.**
> In symbols (which you may safely ignore): `eml(x, y) = exp(x) − ln(y)`.

That's it. Two inputs, one output. Inflate `x`, deflate `y`, subtract. One puff of
the air pump, one read of the gauge, one takeaway.

`Try it ▶`
```bash
eml 1 1     # 2.71828…   (grow 1 → e;  un-grow 1 → 0;  e − 0 = e)
```

You just computed the special number `e` from scratch. Notice the answer is a long
decimal — that's the "computer showing off" tail from the heads-up box. Squint and
it's `2.718…`, exactly `e`.

By itself, `eml` doesn't look like much. The wonder is what happens when you start
feeding `eml`'s output back into `eml` — and slip in the number `1` at the right
spots. Watch.

---

## 3. The one weird thing you must know: these functions are fussy eaters

Every layer has its "gotcha." In Layer 1 it was *"0 means yes."* In Layer 2 it's
this:

> **`ln` (the un-grow button) flatly refuses negative numbers and zero.**

Why? Un-growing asks "what did I inflate to get here?" There's no amount of
inflating that produces a *negative* balloon — so `ln` of a negative number is a
question with no answer. Because `eml` leans on `ln`, all its derived functions
inherit picky rules about what you're allowed to feed them:

- `eml_add` and `eml_sub` want their **first** number to be positive.
- `eml_mul` wants its **first** number to be bigger than `1`.
- `eml_div` wants a positive number.

Break a rule and the calculator engine underneath (`bc`) throws a small tantrum:

`Try it ▶`  *(this one is supposed to fail)*
```bash
eml_ln -2
# Runtime warning … scale too large …
# Fatal error: Out of memory for malloc …
```

> **Your computer is completely fine.** That avalanche of scary words is just
> `bc`'s overly dramatic way of saying *"you asked me to un-grow a negative number,
> and that's not a thing."* When you see it, you broke a fussy-eater rule — back up
> and feed the function something it likes.

This is the price of admission for the trick. Keep your first arguments positive
(and bigger than 1 for multiply) and `eml` is perfectly happy.

---

## 4. Building the whole keypad out of one operation

Here's the NAND moment — the part that should make you grin. We'll grow the entire
calculator from `eml` plus the number `1`, one floor at a time.

**Floor 0 — get `exp` back for free.** Feed `1` as the second input. Un-growing
`1` gives `0` (remember `ln(1) = 0`), so you subtract nothing, and `eml(x, 1)` is
just plain `exp(x)`:

```bash
eml_exp x   =   eml x 1      # "grow x, subtract nothing"
```

**Floor 1 — subtraction.** With a little wiring (grow one input, un-grow the
other in just the right way), `eml` yields ordinary subtraction:

`Try it ▶`
```bash
eml_sub 7 3     # 4.0000…    (7 − 3)
```

**Floor 2 — addition.** Subtracting a negative is adding. So `add` is built on top
of `sub`:

`Try it ▶`
```bash
eml_add 3 5     # 8.0000…    (3 + 5)
```

**Floor 3 — multiplication.** Built on top of `add` (next section explains the
beautiful reason):

`Try it ▶`
```bash
eml_mul 3 4     # 12.000…    (3 × 4;  remember: first number must be > 1)
```

**Floor 4 — division.** Built from `exp` and a negation:

`Try it ▶`
```bash
eml_div 4       # 0.25       (1 ÷ 4)
```

Stand back and look at what just happened. **Add, subtract, multiply, divide** —
the four faces of every calculator — all came out of *one operation* wired to
itself, exactly the way AND/OR/NOT all came out of NAND. Same plot. Same payoff.

---

## 5. The slide-rule secret: multiplying by adding

Why is multiplication built *on top of* addition? Because of a genuinely lovely
fact that powered engineering for 300 years:

> **Logarithms turn multiplication into addition.**

Here's the intuition without a single formula to solve. "Un-growing" has a magic
property: the un-grow of `3 × 4` equals the un-grow of `3` *plus* the un-grow of
`4`. So to multiply two numbers you can:

1. un-grow both (turn them into their logs),
2. **add** those — easy! — and
3. grow the result back.

Multiplication, smuggled in as an addition. That is *exactly* how a **slide rule**
works: two sliding rulers marked in logarithms, and you multiply big numbers by
physically *adding lengths.* It's how engineers, navigators, and the Apollo
astronauts multiplied before pocket calculators existed.

`eml_mul` does the very same dance internally. You can watch the trick bare-handed:

`Try it ▶`
```bash
eml_mul 3 4              # 12.000…           (the polished version)
echo "e(l(3)+l(4))" | bc -l   # 11.9999…     (un-grow 3 and 4, ADD, grow back → 12)
```

Both land on 12. You just multiplied by adding. (And that tiny `…99988` tail? The
"showing off" fuzz — the cost of taking a round trip up through grow and back down
through un-grow. Harmless, and the test suite simply allows for a hair of it.)

---

## 6. Powers: just multiply over and over

Once you can multiply, raising to a power is no mystery — it's multiplication on
repeat. `3⁴` is just `3 × 3 × 3 × 3`. So `eml_pow_int` ("pow" for power, "int" for
whole-number exponent) loops `eml_mul`:

`Try it ▶`
```bash
eml_pow_int 1.5 3     # 3.375     (1.5 × 1.5 × 1.5)
eml_pow_int 2 5       # 32        (2 to the 5th)
```

Nothing new under the hood — it's Floor 3 in a loop. (Same fussy rule: the base
must be bigger than 1.)

---

## 7. Division without a divide button: guess, check, zoom in

Here's a puzzle. The multiply-layer has no *divide* button — multiplying is the
only tool in the drawer. So how do you compute `1 ÷ x`?

You **play a smart guessing game.** Start with a rough guess for the answer, then
nudge it with a little formula that uses *only multiply and subtract* (tools we
already have). The clever part: each round of nudging roughly **doubles the number
of correct digits**, so after a handful of rounds you've nailed it to the bone.

> **Picture focusing a pair of binoculars,** or the "warmer… warmer… hot!" guessing
> game. You don't compute the answer directly; you circle in on it, fast.

That's `eml_recip` ("reciprocal" = the `1/x` flip):

`Try it ▶`
```bash
eml_recip 1.5     # 0.66666…    (1 ÷ 1.5, found by guessing-and-refining, no division)
```

This is famous enough to have a name — **Newton's method** — but the layman
version is just: *make a guess, let a formula sharpen it, repeat until it stops
moving.*

---

## 8. The cross-layer party trick

The guessing game in Section 7 works best when your *first* guess is already in the
right ballpark. Feed it `1/x` for a big `x` with a lazy guess and it flails.

So there's a deluxe version, `eml_recip_auto`, that picks a smart starting guess
**by phoning downstairs to Layer 1.** It uses the *bit comparator* from the first
tutorial — the "which number is bigger?" circuit — to ask *"roughly how big is this
number?"*, and uses the answer to seed the guess automatically.

`Try it ▶`
```bash
eml_recip_auto 10      # 0.0999…   ≈ 0.1    (no hand-tuning needed)
eml_recip_auto 100     # 0.0099…   ≈ 0.01
```

This is the prettiest moment in the whole project: **the two layers shake hands.**
Layer 1 (pure yes/no bit logic) sizes up the number; Layer 2 (real-number `eml`
math) does the precise work. The on/off switches from the first tutorial are
literally helping the calculator from this one. Different worlds, one machine.

---

## 9. Sine from scratch: adding up a wave

Last stop, and the showiest. **Sine** is the smooth up-and-down wave behind sound,
light, springs, tides, and anything that goes round in circles. It seems like it
should need its own special hardware.

It doesn't. There's a classic recipe (a "Taylor series") that builds sine out of
nothing but powers and divisions — both of which we now have:

> sine of x ≈ x, **minus** a little correction, **plus** a smaller one, **minus** a
> smaller one still…

Each term is tinier than the last, like sanding a curve with finer and finer
sandpaper. Add up a handful and you've got sine to several decimal places — made
entirely of `eml` operations:

`Try it ▶`
```bash
eml_sin_taylor 1.5            # 0.99749…     (our from-scratch sine)
echo "s(1.5)" | bc -l         # 0.99749…     (bc's built-in sine, for comparison)
```

They match to about seven digits. The tiny gap is honest: we only added up a few
terms of the recipe. Add more terms (`eml_sin_taylor 1.5 8`) and the gap shrinks —
more sandpaper, smoother curve.

---

## The bridge: so what *is* all this, really?

If it still feels abstract, here's how each piece lands in the real world:

- **`exp` and `ln` are just "grow" and "un-grow."** Every formula in this tutorial
  is built from that one pair of opposites. You never had to compute either by
  hand, and you still understood the whole thing. That was the point.
- **You re-derived the slide rule.** "Multiply by adding the logs" isn't a cute
  metaphor — it's the literal mechanism of the device engineers used for three
  centuries, and the reason logarithm tables filled the back of every textbook
  before the 1970s. `eml_mul` is that history, in a shell function.
- **`eml` is the NAND of continuous math.** Layer 1's headline was "one gate builds
  all logic." Layer 2's is "one operation builds all arithmetic." Recognizing that
  *the same idea works in both worlds* — a single universal piece, stacked cleverly
  — is the entire spirit of this project. You've now seen it twice.
- **The layers cooperate.** `eml_recip_auto` quietly proves the stack is real: bit
  switches from the bottom layer feed the real-number math of the layer above. It's
  a Lego tower where the top floor leans on the foundation.
- **The fuzzy last digits are the receipt.** That `…0099` tail is the visible cost
  of doing arithmetic the roundabout way — up through grow, back down through
  un-grow. It's the trick *showing its work*, and it's why every numeric test in
  this project checks "close enough" rather than "exactly equal."

And the genuinely surprising part — the same surprise as Layer 1 — is that **at no
point did something mysterious get added.** It's one operation, `eml`, wired to
itself enough times to look like a scientific calculator. Computers aren't smart;
they're simple things stacked breathtakingly high.

> **Where this comes from.** The `eml` operator and the claim that it can express
> every elementary function are from a real research paper: Andrzej Odrzywołek,
> *"A Single Binary Operator for All Elementary Functions,"* arXiv:2603.21852v2
> (2026) — <https://arxiv.org/abs/2603.21852v2>. This tutorial is the no-math
> tour; the paper is the rigorous version.

---

## Try it all yourself

```bash
source ./boolean-funcs-new.sh     # load everything

# walk up the layer, one floor at a time:
eml 1 1               # the operator itself      → e
eml_sub 7 3           # subtraction              → 4
eml_add 3 5           # addition                 → 8
eml_mul 3 4           # multiplication (add logs)→ 12
eml_div 4             # division                 → 0.25
eml_pow_int 2 5       # powers                   → 32
eml_recip 1.5         # division by guessing     → 0.666…
eml_recip_auto 100    # Layer 1 + Layer 2 shake hands → 0.01
eml_sin_taylor 1.5    # sine, from scratch       → 0.997…
```

Change the numbers. Break the fussy-eater rules on purpose (try `eml_mul 0.5 4`)
and watch `bc` throw its tantrum — then fix it (`eml_mul 4 0.5`) and watch it
recover. The fastest way to *believe* this is to keep poking until it stops
surprising you.

---

## Mini-glossary

| term | plain meaning |
|------|---------------|
| **e** | a special number ≈ 2.718 — "π's cousin, but for growth" |
| **`exp` (grow)** | inflate a number; `exp(x)` = e to the power x |
| **`ln` (un-grow)** | the undo button for `exp`; refuses zero and negatives |
| **`eml`** | the one operator: grow the first input, un-grow the second, subtract |
| **functionally complete** | fancy phrase for "this one piece can build everything" |
| **domain** | the inputs a function will accept (here: keep them positive) |
| **reciprocal** | the `1/x` flip — what `eml_recip` finds by guessing |
| **Newton's method** | "guess, let a formula sharpen it, repeat" — fast convergence |
| **Taylor series** | building a function (like sine) by adding ever-smaller correction terms |
| **slide rule** | the old multiply-by-adding-logs device `eml_mul` re-enacts |
| **the fuzzy tail** | rounding specks at the end of a decimal — the round-trip's receipt |

---

*Where to next: **[`TUTORIAL_LAYER3.md`](TUTORIAL_LAYER3.md)** is the friendly,
batteries-included calculator built on top of all this — `sin`, `cos`, `sqrt`,
`sigmoid`, and friends, with the same plain-English treatment. (For the full
technical reference across all three layers, see `OVERVIEW.md`.) And if you skipped
it, [`TUTORIAL_LAYER1.md`](TUTORIAL_LAYER1.md) is the yes/no foundation everything
here quietly stands on. Three layers, one idea: a single humble piece, stacked
cleverly, becomes a whole world.*
