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

These started as ideas below and are now built-in library functions (see the
adder/subtractor tests in `test-boolean-funcs.sh`):

- **8-bit adder** — `ripple_add8` chains two `ripple_add4` units, connecting the
  carry-out of the low nibble to the carry-in of the high nibble.
- **Subtractor** — `ripple_sub4` / `ripple_sub8` XOR the B inputs with `1` (via
  `flip_bit`) and feed `Cin=1` to perform two's-complement subtraction.

```bash
# 8-bit add with a carry that crosses the nibble boundary
ripple_add8 $(dec_to_bits 200 8) $(dec_to_bits 100 8)   # = 300

# subtraction, with the carry-out acting as the borrow flag
ripple_sub4 1 0 1 0  1 1 0 0     # 5 - 3 = "0 1 0 0 1"  (D=2, no borrow)
ripple_sub4 1 1 0 0  1 0 1 0     # 3 - 5 = "0 1 1 1 0"  (D=-2, borrow)
```

(`dec_to_bits N WIDTH` is a convenience helper defined in the test suite.)

## Ideas for Further Extension

- **Comparator**: `A = B` iff `XNOR` of all bit-pairs; `A > B` via cascaded priority logic.
- **EML reciprocal iteration**: Newton's method for `1/x` using only EML operations.
- **Taylor series via EML**: approximate `sin(x) ≈ x - x³/6 + x⁵/120` using `eml_mul` for powers and `eml_sub`/`eml_add` for accumulation.
