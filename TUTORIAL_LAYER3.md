# Layer 3, From Scratch — A Plain-English Tutorial

*How six humble buttons become a full scientific calculator — and then the
function behind modern AI — explained for someone who is not a math person and
broke into a sweat the last time they saw the word "cosine." No equations to
"solve." This is the third and final tutorial; if you've done
[`TUTORIAL_LAYER1.md`](TUTORIAL_LAYER1.md) and [`TUTORIAL_LAYER2.md`](TUTORIAL_LAYER2.md)
you'll feel right at home, but this one stands fine on its own too.*

---

## How to follow along

Same drill. Open a terminal in this folder and load the library once:

```bash
source ./boolean-funcs-new.sh
```

Every function becomes a command you can type. When you see a `Try it ▶` box, run
it and watch. The motto hasn't changed: *poke it, watch it, believe it.*

> **The long-decimal tail is back.** Like Layer 2, this layer works in real
> numbers, so answers arrive with ~20 digits and a speck of rounding fuzz on the
> end (`1023.99999…` is just the computer's long-winded way of writing `1024`).
> Read past the tail; it's the calculator showing its work, not a mistake.

---

## 0. The big idea: the friendly top floor

The first two tutorials were about *proving a point*: that one logic gate (NAND)
can build all of logic, and one math operator (`eml`) can build all of
arithmetic. They were beautiful, but a little stubborn — everything from one piece,
on principle.

**Layer 3 has a different personality. It's the practical, batteries-included
calculator** — the one you'd actually reach for. Its job isn't to prove a
philosophical point; it's to *be useful*: hand you `sin`, `cos`, `sqrt`,
logarithms, the whole scientific-calculator keypad, ready to go.

But it still has a trick worth admiring, and it's the *same family* of trick:

> **The underlying engine (`bc`, the Unix calculator) gives you only SIX raw
> buttons. Layer 3 builds the entire scientific keypad — twenty-odd functions —
> out of just those six.**

"Many from few," for the third and final time. Let's meet the six.

---

## 1. The six buttons you actually start with

Strip a scientific calculator down to the studs and this is all the engine
provides. In plain terms:

| button | what it does | everyday picture |
|--------|--------------|------------------|
| **sine** | the up-and-down wave | height of a point going around a wheel |
| **cosine** | the same wave, shifted | side-to-side position on that wheel |
| **arctangent** | "what angle has this slope?" | reading an angle off a ramp's steepness |
| **log** (un-grow) | the undo button for growth | *(you met this in Layer 2)* |
| **exp** (grow) | the growth dial | *(also from Layer 2)* |
| **square root** | "what number, times itself, gives this?" | side length of a square of known area |

That's the whole starter kit. Notice two old friends: **grow** (`exp`) and
**un-grow** (`log`) are right back, doing the heavy lifting again. Everything else
in this tutorial is these six, combined.

---

## 2. The easy wins: filling in the rest of the keypad

A surprising amount of the keypad is *free* once you have sine and cosine.

**The other trig buttons are just simple combinations.** Tangent is sine divided
by cosine. The leftover three (`sec`, `csc`, `cot`) are just flips (one-over) of
the first three. No new machinery — a bit of dividing:

`Try it ▶`
```bash
sin 0          # 0
cos 0          # 1.0000…
tan 0          # 0          (= sin 0 ÷ cos 0)
```

**And here's a charming one — you can conjure π out of the arctangent button:**

`Try it ▶`
```bash
pi             # 3.14159…   (built as 4 × arctangent(1) — a tidy mathematical accident)
```

You don't need to know *why* `4 × arctan(1)` lands on π. The point is that the
library doesn't have π hardcoded — it *manufactures* it from one of the six
buttons. Few from fewer.

---

## 3. Square roots, powers, and any logarithm

**Square root** is one of the six raw buttons:

`Try it ▶`
```bash
sqrt 9         # 3.0000…
sqrt 2         # 1.41421…   (the famous one)
```

**Powers** (`x` to the `y`) are built straight from grow and un-grow — the Layer 2
move. To raise `x` to a power, un-grow it, scale, and grow it back:

`Try it ▶`
```bash
pow 2 10       # 1023.99…   ≈ 1024   (2 to the 10th)
pow 9 0.5      # 2.9999…    ≈ 3
```

That second line is a little revelation worth pausing on: **raising to the power
one-half is the same as taking a square root.** `pow 9 0.5` and `sqrt 9` both give
3 — they're the same question asked two ways. (The fuzzy tail is the only thing
that tells you which route the calculator took.)

**Any logarithm at all** comes from the single natural-log button by a trick
called "change of base" — really just dividing one log by another:

`Try it ▶`
```bash
log_base 10 100   # 2     (log base 10 of 100: "10 to the what gives 100?" → 2)
log_base 2 8      # 3     (log base 2 of 8:  "2 to the what gives 8?"   → 3)
```

One log button, every base you'll ever want.

---

## 4. The trig family, and what it's actually for

Quick, fear-free orientation. **Sine and cosine describe anything that goes round
and round, or up and down smoothly** — a wheel turning, a sound wave, a swing, the
tides, alternating current. Sine is the height; cosine is the sideways position.
That's the whole intuition you need.

> **One note on angles:** these functions measure angles in **radians**, not
> degrees. Don't convert anything by hand — just keep two landmarks in mind: a
> half-turn (180°) is π ≈ 3.14 radians, and a quarter-turn (90°) is π/2 ≈ 1.57.

There's a built-in honesty check you can run yourself. For *any* angle, sine
squared plus cosine squared always equals exactly 1 (it's the Pythagorean theorem
hiding on a circle). So:

`Try it ▶`
```bash
cos 0                              # 1.0000…
echo "s(1.2)^2 + c(1.2)^2" | bc -l # 0.9999…  ≈ 1   (true for ANY number you pick)
```

If that ever came out as something other than ~1, you'd know the sine or cosine
button was broken. It always comes out ~1. The keypad is sound.

---

## 5. Going backwards: the "arc" functions

Regular sine takes an angle and gives a ratio. The **inverse** ("arc") functions
run that backwards: give them the ratio, they tell you the **angle**. It's a
reverse phone-book lookup — "I have the number, who does it belong to?"

`Try it ▶`
```bash
asin 0.5       # 0.5236…   (what angle has sine 0.5? → π/6, i.e. 30°)
acos 0.5       # 1.0472…   (→ π/3, i.e. 60°)
atan 1         # 0.7854…   (→ π/4, i.e. 45°)
```

**The Layer 3 "fussy eater" rule lives here.** Sine and cosine never produce a
value outside −1 to 1 (a wheel is only so tall). So asking `asin` or `acos` for
the angle of a ratio *bigger* than 1 is a question with no answer — and the engine
says so:

`Try it ▶`  *(supposed to fail)*
```bash
asin 2
# Runtime error … Square root of a negative number
```

> Same spirit as Layer 2's gotcha: that error isn't your computer breaking, it's
> the math politely refusing an impossible request. Keep `asin`/`acos` inputs
> between −1 and 1 and all is well.

---

## 6. The hyperbolic cousins

There's a parallel family — `sinh`, `cosh`, `tanh` (say "sinch, cosh, tanch") —
that *looks* like trig but is built purely from **grow** (`exp`). Where sine and
cosine trace a circle, these trace a different curve and describe different things:
the shape of a **hanging chain or cable**, the speeds in Einstein's relativity, and
— most usefully for us — a smooth S-shaped squashing curve.

`Try it ▶`
```bash
sinh 1         # 1.1752…
cosh 1         # 1.5430…
tanh 1         # 0.7616…
```

You don't need their life story. The one to remember is **`tanh`**, because its
graph is a gentle **S-curve** that flattens out near −1 and +1 — and that
S-shape is exactly what the grand finale needs.

---

## 7. The payoff: composing your own function — meet the sigmoid

Here's why having a calculator *layer* matters: you can snap its pieces together
into whatever **you** need. The headline example is the **sigmoid** — the single
most famous function in machine learning, the "neuron" in a neural network.

What does it do? **It squashes any number — huge, tiny, negative — into the range
0 to 1.** A giant positive number becomes ~1, a giant negative becomes ~0, and zero
lands smack in the middle at 0.5. It's a **soft yes/no**: instead of a hard
on/off switch, a smooth dial of "how yes is this?"

And you build it by chaining four operations you already met in Layer 2 — grow,
negate, add, divide:

```bash
sigmoid() {
    local denom
    denom=$(eml_add 1 "$(eml_exp "$(eml_neg "$1")")")
    eml_div "$denom"
}
#  x  →[neg]→ −x  →[grow]→ e⁻ˣ  →[add 1]→ 1+e⁻ˣ  →[divide]→ sigmoid(x)
```

`Try it ▶`  *(paste the function above first, then:)*
```bash
sigmoid 0      # 0.5000…    (dead center)
sigmoid 2      # 0.8808…    (leaning toward "yes")
sigmoid -2     # 0.1192…    (leaning toward "no")
```

Sit with that for a second, because it quietly closes the whole story:

> **Layer 1 began with a *hard* yes/no — a switch that is strictly 0 or 1.
> Layer 3 ends with a *soft* yes/no — the sigmoid, a smooth dial gliding from 0 to
> 1.** The on/off switch grew up into the function that powers modern AI, and it
> did so using nothing but pieces from the layers below.

That's the trilogy in one breath: hard yes/no → arithmetic → soft yes/no.

---

## The bridge: so what *is* all this, really?

- **You "bootstrapped" a math library.** That's a real engineering term: start
  with a tiny set of primitives and build everything else on top. Six buttons
  became a full scientific calculator. (This layer follows a known recipe — see
  John D. Cook's ["Bootstrapping a math library"](https://www.johndcook.com/blog/2021/01/05/bootstrapping-math-library/).)
- **This is what's actually inside your tools.** The `sin` on your phone, the
  `sqrt` in a spreadsheet, the math behind NumPy or a game engine — under the hood
  they're doing this same thing: a few hardware primitives, composed into the rest.
  You just watched the magician's hands.
- **Grow and un-grow never left.** `exp` and `log` from Layer 2 did the heavy
  lifting again here — powers, logarithms, the hyperbolics, the sigmoid. One pair
  of opposites, echoing all the way up the stack.
- **The fuzzy tail is the receipt, again.** `1023.99999…` instead of `1024` is the
  honest cost of computing the roundabout way. It's why every numeric test in this
  project checks "close enough," not "exactly equal."
- **The soft yes/no is the punchline of the whole project.** A neural network is,
  at heart, a vast pile of sigmoids — soft switches — tuned until the pile does
  something clever. Layer 1's rigid `0`/`1` and Layer 3's smooth `0…1` are the two
  ends of the same idea, and you built both.

The moral is the one from all three tutorials: **nothing mysterious was ever
added.** A handful of simple primitives, stacked high enough and combined cleverly,
becomes a scientific calculator — and then becomes the building block of "AI."
Computers aren't smart. They're simple things, stacked breathtakingly high.

---

## Try it all yourself

```bash
source ./boolean-funcs-new.sh     # load everything

# the bootstrapped keypad:
pi                 # π from arctangent       → 3.14159…
sqrt 2             # a raw button            → 1.41421…
pow 9 0.5          # power ½ = square root   → 3
log_base 2 8       # any base from one log   → 3
tan 0              # sine ÷ cosine           → 0
asin 0.5           # backwards: angle of 0.5 → 0.5236… (30°)
tanh 1             # the S-curve cousin      → 0.7616…

# compose your own — the function behind neural networks:
sigmoid() { local d; d=$(eml_add 1 "$(eml_exp "$(eml_neg "$1")")"); eml_div "$d"; }
sigmoid 0          # soft yes/no, dead center → 0.5
sigmoid 3          # leaning "yes"            → 0.953…
sigmoid -3         # leaning "no"             → 0.047…
```

(This hand-built sigmoid rides on the EML layer, so it keeps EML's "fussy eater"
manners — feed it modest numbers, roughly −3 to 3. Push much past that and
`eml_exp` grows so fast it overwhelms the chain. Layer 3's *own* `sin`/`cos`/etc.
have no such limit; the cap is the price of building sigmoid from EML pieces.)

Break the rules on purpose (`asin 2`, `sqrt -1`) to see the engine refuse, then
feed it something legal and watch it recover. Keep poking until it stops
surprising you — that's when you'll know you've got it.

---

## Mini-glossary

| term | plain meaning |
|------|---------------|
| **primitive** | a raw built-in button (here: sine, cosine, arctangent, log, exp, sqrt) |
| **bootstrapping** | building a big toolkit from a tiny starter set of primitives |
| **sine / cosine** | the up-down / side-side of anything going round a circle |
| **radian** | the angle unit used here; π ≈ 3.14 is a half-turn (180°) |
| **arc-functions** | the backwards lookups: give a ratio, get the angle (`asin`, `acos`, `atan`) |
| **square root** | "what number times itself gives this?"; also `pow x 0.5` |
| **log_base** | a logarithm in any base, made from the one natural-log button |
| **hyperbolic (sinh/cosh/tanh)** | trig's cousins, built from grow; `tanh` is an S-curve |
| **sigmoid** | squashes any number into 0…1 — a *soft* yes/no; the neural-network function |
| **the fuzzy tail** | rounding specks at the end of a decimal — the round-trip's receipt |

---

*That's the whole stack. **[`TUTORIAL_LAYER1.md`](TUTORIAL_LAYER1.md)** built a
hard yes/no calculator out of switches; **[`TUTORIAL_LAYER2.md`](TUTORIAL_LAYER2.md)**
rebuilt arithmetic from one operator; and this layer turned six primitives into a
scientific calculator that ends, fittingly, on a soft yes/no. For the rigorous,
all-in-one reference — every function, every test, every derivation — see
`reference/OVERVIEW.md`. One idea, three times over: a single humble piece, stacked cleverly,
becomes a whole world.*
