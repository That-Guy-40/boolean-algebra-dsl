# Manual Testing Ideas

A collection of interactive experiments to try at the shell after `source ./boolean-funcs-new.sh`.
These go beyond the automated suite — they're for intuition-building, live exploration, and stress-testing edge cases by hand.

---

## Layer 1 — Boolean DSL

### Gate composition chains

Try building more complex expressions by nesting gates:

```bash
# Majority vote: true when at least 2 of 3 inputs are true
# maj(A,B,C) = (A AND B) OR (B AND C) OR (A AND C)
maj() {
    or "$(or "$(and "$1" "$2")" "$(and "$2" "$3")")" "$(and "$1" "$3")"
}
maj true  true  false   # true  (2/3)
maj false true  false   # false (1/3)
maj true  true  true    # true  (3/3)
```

```bash
# Mux (2-to-1 multiplexer): select A when S=false, B when S=true
# mux(S,A,B) = (NOT S AND A) OR (S AND B)
mux() {
    or "$(and "$(not "$1")" "$2")" "$(and "$1" "$3")"
}
mux false true  false   # true  (selected A=true)
mux true  true  false   # false (selected B=false)
```

### All 16 two-input Boolean functions

There are exactly 16 possible two-input Boolean functions (2^(2^2) = 16).
The library implements the most useful ones. Try mapping all 16 manually:

| Index | Name | T,T | T,F | F,T | F,F |
|---|---|---|---|---|---|
| 0 | FALSE (const) | F | F | F | F |
| 1 | AND | T | F | F | F |
| 2 | A AND NOT B | T | F | F | F |
| 3 | A (buffer) | T | T | F | F |
| 4 | NOT A AND B | T | F | T | F |
| 5 | B (buffer) | T | F | T | F |
| 6 | XOR (ne) | F | T | T | F |
| 7 | OR | T | T | T | F |
| 8 | NOR | F | F | F | T |
| 9 | XNOR (eq) | T | F | F | T |
| 10 | NOT B | F | T | F | T |
| 11 | B → A (then_if) | T | T | F | T |
| 12 | NOT A | F | F | T | T |
| 13 | A → B (if_then) | T | F | T | T |
| 14 | NAND | F | T | T | T |
| 15 | TRUE (const) | T | T | T | T |

Try implementing index 2 (`A AND NOT B`) from just NAND:
```bash
a_and_not_b() { nand "$(nand "$1" "$(nand "$2" "$2")")" "$(nand "$1" "$(nand "$2" "$2")") "; }
```

### De Morgan stress test

Verify De Morgan holds even through deeply nested expressions:

```bash
A=true; B=false; C=true

# not(A or B or C) = not(A) and not(B) and not(C)
lhs=$(not "$(or "$(or "$A" "$B")" "$C")")
rhs=$(and "$(and "$(not "$A")" "$(not "$B")")" "$(not "$C")")
echo "lhs=$lhs rhs=$rhs"  # should match
```

### Exit code vs echoed string

Observe the dual-output nature of the Boolean functions:

```bash
and true true; echo "exit: $?"      # exit: 0
result=$(and true true); echo "$result"  # true

# Use exit code directly in an if-statement
if and true true; then echo "yes"; fi
```

### Check the Boolean-algebra axioms by hand

The suite proves these exhaustively, but they're satisfying to watch hold:

```bash
# Distributivity: A∧(B∨C) = (A∧B)∨(A∧C), over all 8 assignments
for A in true false; do for B in true false; do for C in true false; do
    lhs=$(and "$A" "$(or "$B" "$C")")
    rhs=$(or "$(and "$A" "$B")" "$(and "$A" "$C")")
    echo "A=$A B=$B C=$C: lhs=$lhs rhs=$rhs  $([ "$lhs" = "$rhs" ] && echo ok || echo BAD)"
done; done; done

# Complement and annihilator
for A in true false; do
    echo "A∨¬A = $(or "$A" "$(not "$A")")   A∧¬A = $(and "$A" "$(not "$A")")"
    echo "A∨1  = $(or "$A" true)            A∧0  = $(and "$A" false)"
done
```

### Word-level algebra and reductions

```bash
# Bitwise ops on 4-bit words (LSB-first)
word_and "1 1 0 0" "1 0 1 0"     # 1 0 0 0
word_or  "1 1 0 0" "1 0 1 0"     # 1 1 1 0
word_xor "1 1 0 0" "1 0 1 0"     # 0 1 1 0
word_zip nand "1 1 0 0" "1 0 1 0" # any gate, position-wise

# De Morgan on whole words: ¬(A∧B) must equal ¬A ∨ ¬B
A="1 1 0 0"; B="1 0 1 0"
echo "¬(A∧B) = $(word_not "$(word_and "$A" "$B")")"
echo "¬A∨¬B  = $(word_or "$(word_not "$A")" "$(word_not "$B")")"

# Reductions fold a word to one bit
xor_all "1 1 0 1"   # true  — parity (odd count of 1s)
is_zero "0 0 0 0"   # true  — the ALU zero flag, = ¬or_all
```

---

## Layer 1 — Adders

### 4-bit ripple-carry adder (manual)

Chain four `full_adder` calls by hand, threading carry between stages:

```bash
ripple_add4() {
    local r c
    r=$(full_adder "$1" "$5" "${9:-0}"); s0=$(first "$r"); c=$(second "$r")
    r=$(full_adder "$2" "$6" "$c");     s1=$(first "$r"); c=$(second "$r")
    r=$(full_adder "$3" "$7" "$c");     s2=$(first "$r"); c=$(second "$r")
    r=$(full_adder "$4" "$8" "$c");     s3=$(first "$r"); cout=$(second "$r")
    echo "$s0 $s1 $s2 $s3 $cout"
}

ripple_add4  1 1 0 0  1 0 1 0  0   # 3 + 5 = 8  → 0 0 0 1 0
ripple_add4  1 1 1 1  1 0 0 0  0   # 15 + 1 = 16 → overflow: 0 0 0 0 1
```

Bit order is LSB-first. Convert manually:
- `0 0 0 1 0` = 0·1 + 0·2 + 0·4 + 1·8 = **8** ✓
- `0 0 0 0 1` = all sum bits zero, carry=1 = **16 (overflow)** ✓

### Overflow detection

The carry-out of the last stage flags overflow. Try cases that do and don't overflow:

```bash
# 7 + 7 = 14 (fits in 4 bits, no overflow)
ripple_add4  1 1 1 0  1 1 1 0  0   # → 0 1 1 1 0  (cout=0, no overflow)

# 8 + 8 = 16 (overflow)
ripple_add4  0 0 0 1  0 0 0 1  0   # → 0 0 0 0 1  (cout=1, overflow)
```

### Carry propagation with all-ones

The worst case for carry propagation is all-ones input:

```bash
# 15 + 15 = 30 (in a wider adder, 11110 = 30)
# In 4-bit with carry-out this would be 1111 + 1111 = 11110
ripple_add4  1 1 1 1  1 1 1 1  0   # → 0 1 1 1 1  (cout=1 → 30)
```

---

## Layer 1 — Multi-bit Circuits: 8-bit adder, subtractor, comparator

`ripple_add4`, `ripple_add8`, `ripple_sub4`, `ripple_sub8`, `flip_bit`,
`bit_to_bool`, `bits_eq`, `bits_gt`, `compare4`, and `compare8` are all built-in
functions — just `source ./boolean-funcs-new.sh` and call them. Everything below
is LSB-first (bit 0 first).

### Convenience helpers for interactive play

The test suite defines `dec_to_bits` / `bits_to_dec`, but they aren't in the
library. Paste these tiny equivalents so the snippets below are self-contained:

```bash
source ./boolean-funcs-new.sh

d2b() { local n=$1 w=$2 i out=""; for ((i=0;i<w;i++)); do out+="$(( (n>>i)&1 )) "; done; echo "${out% }"; }
b2d() { local d=0 i=0 b; for b in $1; do d=$((d+(b<<i))); i=$((i+1)); done; echo "$d"; }

d2b 200 8                 # 0 0 0 1 1 0 0 1
b2d "0 0 0 1 1 0 0 1"     # 200   (decoding the whole adder output incl. carry
                          #        gives the exact unsigned value)
```

### 8-bit adder — watch the carry cross the nibble boundary

`ripple_add8` is two `ripple_add4` units stitched together, so the most
interesting cases are exactly the ones where the low nibble (bits 0–3) overflows
and the carry has to cross into the high nibble (bits 4–7):

```bash
b2d "$(ripple_add8 $(d2b 15 8)  $(d2b 1 8))"    # 16   (1111+0001 carries into bit 4)
b2d "$(ripple_add8 $(d2b 240 8) $(d2b 16 8))"   # 256  (high-nibble add, 8-bit overflow)
```

### 8-bit adder — agreement with plain shell arithmetic

Sweep a grid and check every sum against `$((a+b))`:

```bash
for a in 0 37 100 200 255; do for b in 0 1 55 128 255; do
    got=$(b2d "$(ripple_add8 $(d2b $a 8) $(d2b $b 8))")
    printf "%3d + %3d = %3d  %s\n" "$a" "$b" "$got" \
        "$([ "$got" = "$((a+b))" ] && echo ok || echo BAD)"
done; done
```

### 8-bit adder — commutativity and identity

```bash
a=173; b=88
echo "A+B = $(b2d "$(ripple_add8 $(d2b $a 8) $(d2b $b 8))")"   # must equal …
echo "B+A = $(b2d "$(ripple_add8 $(d2b $b 8) $(d2b $a 8))")"   # … this
b2d "$(ripple_add8 $(d2b 99 8) $(d2b 0 8))"                    # 99  (A + 0 = A)
```

### 8-bit adder — maximum carry propagation

The hardest path for a ripple-carry adder is a single carry that has to travel
through every stage. `255 + 1` is the canonical case — a carry born at bit 0
ripples all the way to the carry-out:

```bash
ripple_add8 $(d2b 255 8) $(d2b 1 8)    # 0 0 0 0 0 0 0 0 1   (= 256)
```

### Extend the pattern — a 16-bit adder from two `ripple_add8`

The very trick that builds `ripple_add8` from two `ripple_add4` builds a 16-bit
adder from two `ripple_add8`: thread the low byte's carry-out into the high
byte's carry-in.

```bash
ripple_add16() {
    local -a A B L H
    read -ra A <<< "$1"; read -ra B <<< "$2"        # two 16-bit LSB-first strings
    read -ra L <<< "$(ripple_add8 ${A[*]:0:8}  ${B[*]:0:8})"
    read -ra H <<< "$(ripple_add8 ${A[*]:8:8}  ${B[*]:8:8}  "${L[8]}")"
    echo "${L[*]:0:8} ${H[*]:0:8} ${H[8]}"
}

b2d "$(ripple_add16 "$(d2b 1000 16)" "$(d2b 24 16)")"    # 1024
b2d "$(ripple_add16 "$(d2b 65535 16)" "$(d2b 1 16)")"    # 65536 (16-bit overflow)
```

### Subtractor — the borrow flag tracks A vs B

The trailing carry-out is the borrow flag: `1` = no borrow (`A ≥ B`), `0` =
borrow (`A < B`):

```bash
for pair in "5 3" "3 5" "8 8" "0 1"; do
    set -- $pair
    out=$(ripple_sub4 $(d2b $1 4) $(d2b $2 4))
    echo "$1 - $2 -> $out   borrow=$([ "${out##* }" = 1 ] && echo no || echo YES)"
done
```

### Subtractor — signed results and A − A = 0

A small signed decoder makes the two's-complement output readable:

```bash
sub4dec() { local -a o=($1); local v=$(b2d "${o[*]:0:4}"); [ "${o[4]}" = 0 ] && v=$((v-16)); echo "$v"; }

for pair in "5 3" "3 5" "15 0" "0 15"; do
    set -- $pair
    echo "$1 - $2 = $(sub4dec "$(ripple_sub4 $(d2b $1 4) $(d2b $2 4))")  (want $(($1-$2)))"
done

# A - A is zero for every value (sum bits all 0, carry 1 = no borrow):
for a in 0 1 7 8 15; do echo "$a - $a -> $(ripple_sub4 $(d2b $a 4) $(d2b $a 4))"; done
```

### Subtractor — the borrow chain (0 − 1 = all ones)

The mirror image of the adder's max-carry case: `0 − 1` makes a borrow at bit 0
that ripples through every bit, leaving the all-ones pattern (= −1):

```bash
ripple_sub4 $(d2b 0 4) $(d2b 1 4)   # 1 1 1 1 0   (1111 = -1, borrow)
ripple_sub8 $(d2b 0 8) $(d2b 1 8)   # 1 1 1 1 1 1 1 1 0   (all ones = -1)
```

### Subtractor — round-trip (A − B) + B = A

```bash
a=12; b=7
read -ra D <<< "$(ripple_sub4 $(d2b $a 4) $(d2b $b 4))"   # D[0..3] = A-B sum bits
echo "(12 - 7) + 7 = $(b2d "$(ripple_add4 ${D[*]:0:4} $(d2b $b 4))")  (want 12)"
```

### Comparator — trichotomy (exactly one of lt / eq / gt)

For any pair, exactly one of `bits_eq`, `bits_gt(A,B)`, `bits_gt(B,A)` holds —
the three flags must always sum to 1:

```bash
for pair in "5 3" "3 5" "5 5"; do
    set -- $pair; A=$(d2b $1 4); B=$(d2b $2 4)
    eq=0; gt=0; lt=0
    bits_eq "$A" "$B" >/dev/null && eq=1
    bits_gt "$A" "$B" >/dev/null && gt=1
    bits_gt "$B" "$A" >/dev/null && lt=1
    echo "$1 vs $2: eq=$eq gt=$gt lt=$lt  sum=$((eq+gt+lt))  (must be 1)"
done
```

### Comparator — cascaded priority: the MSB always wins

The cascade is what separates a real comparator from "count the 1s". A single
high bit must outweigh any number of lower bits:

```bash
compare4 $(d2b 8 4)  $(d2b 7 4)    # gt:  1000 > 0111  (8 wins despite 7 having more 1s)
compare4 $(d2b 4 4)  $(d2b 3 4)    # gt:  0100 > 0011
compare4 $(d2b 8 4)  $(d2b 15 4)   # lt:  once a higher bit differs, it decides
```

### Comparator — cross-check against the subtractor

Two independent circuits should agree: `A > B` exactly when `A − B` has no borrow
and a nonzero result. This is one of the strongest manual tests — it validates
the comparator and the subtractor against each other:

```bash
for pair in "5 3" "3 5" "8 8" "12 4" "0 9"; do
    set -- $pair; A=$(d2b $1 4); B=$(d2b $2 4)
    cmp=$(compare4 $A $B)
    out=$(ripple_sub4 $A $B); read -ra D <<< "$out"
    mag=$(b2d "${D[*]:0:4}")
    sub=$([ "${out##* }" = 0 ] && echo lt || { [ "$mag" = 0 ] && echo eq || echo gt; })
    echo "$1 vs $2: compare4=$cmp  subtractor=$sub  $([ "$cmp" = "$sub" ] && echo AGREE || echo DISAGREE)"
done
```

### Comparator — transitivity

```bash
A=$(d2b 12 4); B=$(d2b 7 4); C=$(d2b 3 4)
bits_gt "$A" "$B" >/dev/null && bits_gt "$B" "$C" >/dev/null \
    && bits_gt "$A" "$C" >/dev/null && echo "12 > 7 > 3, and 12 > 3  ✓ transitive"
```

### Comparator — equality breaks on any single bit flip

`bits_eq` should be true only for an exact match. Flip each bit of a value in
turn; every flip must break equality:

```bash
A="1 0 1 1"
for i in 0 1 2 3; do
    B=($A); B[$i]=$(flip_bit "${B[$i]}")
    bits_eq "$A" "${B[*]}" >/dev/null \
        && echo "bit $i: still equal?!" \
        || echo "bit $i flipped -> not equal"
done
```

### Comparator — capstone: sort a list with `compare4`

A small bubble sort driven entirely by the gate-level comparator:

```bash
arr=(9 2 14 5 8 1); n=${#arr[@]}
for ((i=0; i<n; i++)); do for ((j=0; j<n-1-i; j++)); do
    if [ "$(compare4 $(d2b ${arr[j]} 4) $(d2b ${arr[j+1]} 4))" = gt ]; then
        t=${arr[j]}; arr[j]=${arr[j+1]}; arr[j+1]=$t
    fi
done; done
echo "sorted: ${arr[*]}"    # 1 2 5 8 9 14
```

### Shifts — multiply and divide by powers of two

```bash
b2d "$(shl "$(d2b 3 4)")"    # 6   (3 << 1)
b2d "$(shr "$(d2b 12 4)")"   # 6   (12 >> 1)
b2d "$(shl "$(d2b 1 4)" 2)"  # 4   (1 << 2)
shl "$(d2b 12 4)"            # 0 0 0 1  — top bit falls off (12<<1 = 24, mod 16 = 8)
```

### ALU — drive it like a tiny processor

`alu4 OP A B` returns `R0 R1 R2 R3 Z C N V`. A helper to read it back:

```bash
alu_show() {                       # alu_show OP a b  (a,b decimal 0..15)
    local op=$1 a=$2 b=$3 out res flags
    out=$(alu4 $op $(d2b $a 4) $(d2b $b 4))
    res="${out% * * * *}"          # first 4 fields = result bits
    flags="${out#* * * * }"        # last 4 = Z C N V
    printf "%-4s %2d,%2d -> %2d   ZCNV=%s\n" "$op" "$a" "$b" "$(b2d "$res")" "$flags"
}

for op in add sub and or xor slt shl shr; do alu_show $op 6 3; done
alu_show not 6 0
```

### ALU — make each flag fire

```bash
alu_show add 3 5     # V=1, N=1 : 3+5=8 overflows signed 4-bit (-8..7)
alu_show add 8 8     # Z=1 C=1 V=1 : 8+8=16 wraps to 0, unsigned carry + signed overflow
alu_show sub 5 3     # C=1 : no borrow (A>=B)
alu_show sub 3 5     # C=0 N=1 : borrow, result is two's-complement -2
alu_show slt 5 3     # Z=1 : 5<3 is false, result 0
```

### ALU — build a multiplier out of it (shift-and-add)

The ALU plus shifts is enough to multiply, the way a CPU without a hardware
multiplier would — add the multiplicand wherever the multiplier has a 1 bit,
shifting left each step:

```bash
alu_add() {                         # decimal a + b via the ALU (ignores overflow)
    b2d "$(echo "$(alu4 add $(d2b $1 4) $(d2b $2 4))" | cut -d' ' -f1-4)"
}
mul() {                             # a * b by shift-and-add (small values)
    local b=$2 acc=0 shifted=$1     # note: read $1 directly — `shifted=$a` on a
    while [ "$b" -gt 0 ]; do         # `local a=$1 … shifted=$a` line sees the outer a
        [ $((b & 1)) -eq 1 ] && acc=$(alu_add $acc $shifted)
        shifted=$((shifted * 2)); b=$((b >> 1))
    done
    echo "$acc"
}
mul 3 4    # 12
mul 5 3    # 15
```

(Keep products ≤ 15 so they fit the 4-bit ALU; widening to `alu8` would lift that.)

---

## Layer 2 — EML Operator

### Verify the ln derivation step by step

Walk through the 3-node `eml_ln` tree manually:

```bash
x=7

step1=$(eml 1 "$x")                          # e - ln(x)
echo "step1 = $step1"

step2=$(eml "$step1" 1)                      # exp(e - ln(x)) = e^e / x
echo "step2 = $step2"

result=$(eml 1 "$step2")                     # e - ln(e^e / x) = ln(x)
echo "result = $result"

echo "ln(7) via bc = $(echo "l(7)" | bc -l)" # compare
```

### eml_zero sanity check

```bash
# Should be indistinguishable from 0
zero=$(eml_zero)
echo "$zero"
echo "$(echo "$zero == 0" | bc -l)"  # may be 0 due to floating-point residual
echo "$(echo "define abs(x){if(x<0)return-x;return x;} abs($zero) < 1e-10" | bc -l)"  # 1 = true
```

### EML arithmetic chain: build a polynomial

Try `3x² + 2x + 1` at x=4 using only EML operations:

```bash
x=4
x2=$(eml_mul "$x" "$x")                     # x² = 16
term1=$(eml_mul 3 "$x2")                    # 3x² = 48
term2=$(eml_mul 2 "$x")                     # 2x = 8
result=$(eml_add "$(eml_add "$term1" "$term2")" 1)   # 48 + 8 + 1 = 57
echo "$result"   # expect ~57
```

### Domain boundary probing

```bash
# eml_ln requires x > 0
eml_ln 0.001       # large negative number (approaches -inf)
eml_ln 0.0001      # even larger negative

# eml_mul requires first arg > 1 (ln(x) > 0)
eml_mul 0.5 4      # will fail/error: ln(0.5) < 0
eml_mul 1.001 1000 # just inside domain — observe precision
```

### EML application — integer powers (`eml_pow_int`)

`eml_pow_int base n` is just `n` repeated `eml_mul`s. Because `eml_mul` needs its
first argument > 1, the base must be > 1:

```bash
eml_pow_int 1.5 3     # 3.375
eml_pow_int 2 8       # 256
eml_pow_int 0.5 3     # fails — 0.5 is below eml_mul's domain
```

### EML application — reciprocal by Newton's iteration (`eml_recip`)

`eml_recip` computes `1/x` with only `eml_mul` and `eml_sub` — no division at
all. Unroll the loop to watch it converge **quadratically** (the number of
correct digits roughly doubles each step):

```bash
x=1.5; y=0.5                       # y0 = 0.5 is an underestimate of 1/1.5
for i in 1 2 3 4 5 6; do
    t=$(eml_mul "$x" "$y")         # x*y
    c=$(eml_sub 2 "$t")            # 2 - x*y
    y=$(eml_mul "$c" "$y")         # y*(2 - x*y)
    echo "iter $i: y = $y"
done
echo "target eml_div(1.5) = $(eml_div 1.5)"
```

Expected: `y` leaps toward `0.6666…`, locking in digits faster each iteration.

### EML application — the Newton basin needs a small enough seed

Convergence requires `0 < y0 < 1/x`. The default `y0 = 0.5` only sits in the
basin for `1 < x < 2`; for larger `x` you must hand it a smaller underestimate:

```bash
eml_recip 10           # default y0=0.5 is outside the basin -> garbage
eml_recip 10 9 0.05    # y0 = 0.05 < 1/10 -> converges to 0.1
eml_recip 100 12 0.005 # 1/100 = 0.01

# cross-check against the direct reciprocal
for x in 1.2 1.5 1.9; do
    echo "1/$x: newton=$(eml_recip $x)  eml_div=$(eml_div $x)"
done
```

### EML application — automatic seeding (`eml_recip_auto`, comparator-driven)

`eml_recip_auto` removes the hand-tuned seed entirely. It uses the Layer-1 bit
comparator to find which power-of-two bracket `floor(x)` falls in — the smallest
`k` with `2ᵏ > floor(x)` — and seeds Newton with `y0 = 2⁻ᵏ`, which is always a
valid underestimate of `1/x`. One function, spanning both layers:

```bash
for x in 1.5 4 10 63 64 100 1000; do
    echo "1/$x: auto=$(eml_recip_auto $x)  eml_div=$(eml_div $x)"
done
```

Expected: every `auto` value matches `eml_div`, with no seed supplied by hand.
The `63` vs `64` pair is worth eyeballing — they land in adjacent brackets
(`k = 6` then `k = 7`), so the comparator picks seeds `2⁻⁶` and `2⁻⁷`
respectively. Watch the bracket search itself by unrolling it:

```bash
m=100                              # = floor(x) for x in [100, 101)
k=0
while ! bits_gt "$(int_to_bits $((1 << k)) 12)" "$(int_to_bits $m 12)" >/dev/null; do
    echo "  2^$k is not > $m yet"; k=$((k + 1))
done
echo "bracket: k=$k, seed y0 = 2^-$k = $(echo "scale=20; 1/(2^$k)" | bc -l)"
```

### EML application — sin by Taylor series, accuracy vs. term count

`eml_sin_taylor` sums `x - x³/3! + x⁵/5! - …` using `eml_pow_int` for the powers,
`eml_div` for the reciprocal factorials, and `eml_sub`/`eml_add` to accumulate.
More terms tighten the estimate toward the true sine:

```bash
x=1.5
for n in 2 3 4 5 6; do
    printf "%d terms: %s\n" "$n" "$(eml_sin_taylor $x $n)"
done
echo "target bc sin(1.5) = $(echo "s(1.5)" | bc -l)"
```

Expected: each added term roughly an order of magnitude closer to `0.99749…`.

### EML application — the Taylor domain wall

The series needs `x > 1` (so every power stays inside `eml_mul`'s domain) and
`x` not much past `π/2` (so each running partial sum stays positive for
`eml_sub`/`eml_add`, whose first argument must be > 0):

```bash
eml_sin_taylor 1.5     # fine (partial sums stay positive)
eml_sin_taylor 3       # breaks: x - x³/6 = 3 - 4.5 < 0, and the next eml_add
                       # then sees a negative first argument
```

---

## Layer 3 — Math Library

### Pythagorean identity at unusual angles

```bash
for angle in 0.1 0.99 1.5707 2.0 3.14 -1.2 100; do
    result=$(echo "s($angle)^2 + c($angle)^2" | bc -l)
    echo "angle=$angle  sin²+cos²=$result"
done
```

### atan approaches π/2 asymptotically

```bash
PI=$(pi)
for n in 10 100 1000 10000 1000000; do
    a=$(atan $n)
    diff=$(echo "$PI/2 - $a" | bc -l)
    echo "atan($n) = $a  diff from π/2 = $diff"
done
```

### Inverse round-trips at the domain edge

```bash
# asin is only valid on (-π/2, π/2) — what happens near the boundary?
for x in 0.9 0.99 0.999 0.9999; do
    result=$(asin "$(sin "$x")")
    echo "asin(sin($x)) = $result  (want $x)"
done
```

### Compose cross-layer: gate-computed angle into trig

Add two 4-bit numbers at the gate level, then use the result as a trig input:

```bash
source ./boolean-funcs-new.sh

ripple_add4() {
    local r c s0 s1 s2 s3 cout
    r=$(full_adder "$1" "$5" "${9:-0}"); s0=$(first "$r"); c=$(second "$r")
    r=$(full_adder "$2" "$6" "$c");     s1=$(first "$r"); c=$(second "$r")
    r=$(full_adder "$3" "$7" "$c");     s2=$(first "$r"); c=$(second "$r")
    r=$(full_adder "$4" "$8" "$c");     s3=$(first "$r"); cout=$(second "$r")
    echo "$s0 $s1 $s2 $s3 $cout"
}

bits_to_dec() { echo "$1 + 2*$2 + 4*$3 + 8*$4" | bc; }

bits=$(ripple_add4  1 1 0 0  1 0 1 0  0)   # 3 + 5 = 8
dec=$(bits_to_dec $bits)
angle=$(echo "$dec * $(pi) / 16" | bc -l)  # 8π/16 = π/2
echo "sin(8·π/16) = $(sin "$angle")"        # expect ≈ 1
```

### Sigmoid via EML — explore the shape

```bash
sigmoid() {
    local d
    d=$(eml_add 1 "$(eml_exp "$(eml_neg "$1")")")
    eml_div "$d"
}

for x in -5 -3 -2 -1 0 1 2 3 5; do
    printf "sigmoid(%3d) = %s\n" "$x" "$(sigmoid $x)"
done
```

Expected: smooth S-curve from near 0 to near 1, with sigmoid(0) = 0.5 exactly.

### Symmetry check: σ(x) + σ(-x) = 1

```bash
for x in 0.5 1 2 3; do
    pos=$(sigmoid  $x)
    neg=$(sigmoid -$x)
    sum=$(echo "$pos + $neg" | bc -l)
    echo "sigmoid($x) + sigmoid(-$x) = $sum"   # expect 1.0000…
done
```

---

## Implemented Extensions

These started as ideas below and are now built-in library functions. Each has a
dedicated set of manual-testing snippets in
[Layer 1 — Multi-bit Circuits](#layer-1--multi-bit-circuits-8-bit-adder-subtractor-comparator)
above, and automated coverage in `test-boolean-funcs.sh`:

- **8-bit adder** — `ripple_add8` chains two `ripple_add4` units, connecting the
  carry-out of the low nibble to the carry-in of the high nibble.
- **Subtractor** — `ripple_sub4` / `ripple_sub8` XOR the B inputs with `1` (via
  `flip_bit`) and feed `Cin=1` to perform two's-complement subtraction.
- **Comparator** — `bits_eq` (XNOR of all bit-pairs, ANDed) and `bits_gt`
  (cascaded priority from the MSB); `compare4` / `compare8` echo `lt`/`eq`/`gt`.
- **EML reciprocal iteration** — `eml_recip` computes `1/x` by Newton's method
  (`y <- y*(2 - x*y)`) using only `eml_mul` and `eml_sub`; see the EML-application
  snippets under [Layer 2](#layer-2--eml-operator).
- **Taylor series via EML** — `eml_sin_taylor` approximates `sin(x)` from its
  Maclaurin series using `eml_pow_int`, `eml_div`, and `eml_sub`/`eml_add`.
- **Comparator-driven `eml_recip` seeding** — `eml_recip_auto` brackets `x` with
  the bit comparator (`int_to_bits` + `bits_gt`) and seeds Newton with `2⁻ᵏ`
  automatically; no hand-supplied `y0`. Genuinely spans Layer 1 → Layer 2.

## Ideas for Further Extension

- **Hyperbolic / cos Taylor series**: reuse `eml_pow_int` and the accumulation
  pattern for `cos(x)` (even powers) and `sinh`/`cosh`.
- **Adaptive Taylor term count**: keep adding terms until the next one falls
  below a tolerance, instead of a fixed count.
