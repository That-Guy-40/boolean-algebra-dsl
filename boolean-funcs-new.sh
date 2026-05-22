#!/bin/bash 


# A boolean Algebra DSL in the shell
false () {
  return 1 #contrary to convention returning a nonzero value is false
}

 
true () {
  return 0 #contrary to convention returning a value of zero is true
}

is_true () {
	#unary function that returns true if its argument equals 0, T, t, True, or true 
case "$1" in
  T|t|True|true|0) shift
      return 0 ;; #return true
  
  *) return 1  ;; #return false
esac
}

is_false () {
	#unary function that returns true if its argument equals 1, F, f, False, or false 
case "$1" in
  F|f|False|false|1) shift
      return 0 ;; #return true
  
  *) return 1  ;; #return false
esac
}



eq() { if (( $1 == $2 )); then return 0; else return 1; fi; } #equal to



strlen ()		# echo ${#string} ...
{
    for i in "$@"; do
	echo ${#i}
    done
}

null () 
{ 
    set -- "$1";
    case $# in 
        0)
            shift;
            true
        ;;
        *)
            shift;
            false
        ;;
    esac
}

null_2()
{
	if eq "$(strlen "$1")" 0; then true; else false; fi
}


lhead() {
  eval set -- "$1"
  if [ "$#" = 0 ]; then
    echo 1>&2 lhead: list empty
    return 1
  fi
  echo "$1"
}

ltail () 
{ 
    fieldSeperator=" ";
    list="$@";
    firstelement=$((( $(strlen $(lhead "$list")) + $(strlen "$fieldSeperator") )));
    if null "$2"; then
        false;
    else
        echo "$list" | dd of=/dev/stdout bs=1 skip=$firstelement 2> /dev/null;
        true;
    fi
}


second () {
#(set 'cadr '(lambda (e) (car (cdr e)))) #second in scheme/common lisp
local list1="$1"
 echo $(lhead "$(ltail "$list1")") #second in scheme/common lisp
}

first () {
  lhead "$1"
}



#AND FOLLOWED BY A NOT
nand () 
{
	local A="$1"
	local B="$2"
  if "$A" && "$B"; then echo "false"; false; else echo "true"; true; fi #PORTABLE VERSION OF NAND;WORK IN ALL SHELLS
  #"$A" && "$B" && Echo "false";false || Echo "true"; true #UNTESTED NOT USING IF/lower syntactic burden/higher semantic
  }
#NAND TESTING, NOT+AND, Logical NAND, NAND
#WORKS! 
#nand true true   #return 1/false 
#nand true false  #return 0/true 
#nand false true  #return 0/true
#nand false false #return 0/true

#JOINS THE INPUTS OF A NAND, SINCE A NAND IS EQUIVALENT TO AN AND FOLLOWED BY A NOT, JOINING THE INPUTS 
#LEAVES ONLY THE NOT
not () {
	
local A="$1"
nand "$A" "$A"  
}
#NOT TESTING, Logical Negation, NOT
#WORKS!
#not true  #return 1/false
#not false #return 0/true

#NAND(NOT+AND) FOLLOWED BY A NOT(NEGATION) 
and () {
  local A="$1"
  local B="$2"
  not $(nand "$A" "$B")
}

#Echo "AND TESTING, Logical Conjunction, AND"
#WORKS
#and true true   #return  0/true
#and true false  #return 1/false
#and false true  #return 1/false
#and false false #return 1/false 

#JAVASCRIPT FROM ROSETTACODE.ORG
#http://rosettacode.org/wiki/Four_bit_adder
#function not(a) {
#    if (arePseudoBin(a))
#        return a == 1 ? 0 : 1;
#}
 
#function and(a, b) {
#    if (arePseudoBin(a, b))
#        return a + b < 2 ? 0 : 1;
#}

or () {
	local A="$1"
    local B="$2"
    nand $(not "$A") $(not "$B")    
}
#Echo "OR TESTING, Logical Disjunction, OR"
#WORKS
#or true true   #return 0/true
#or true false  #return 0/true
#or false true  #return 0/true
#or false false #return 1/false

#NOT GATE FOLLOWED BY AN OR/AN OR GATE WITH AN INVERTED(NEGATED) OUTPUT
nor () {
	local A="$1"
    local B="$2"
  not $(or "$A" "$B")
}
#Echo "NOR TESTING, Pierce arrow, Logical NOR, NOR"
#WORKS
#nor true true   #return 1/false
#nor true false  #return 1/false
#nor false true  #return 1/false
#nor false false #return 0/true

eq () {
	local A="$1"
    local B="$2"
  or $(and "$A" "$B") $(nor "$A" "$B")
}
#Echo "EQ TESTING, Logical equality, biconditional, XNOR" 
#WORKS
#eq true true   #return 0/true
#eq true false  #return 1/false
#eq false true  #return 1/false
#eq false false #return 0/true

ne () {
	local A="$1"
    local B="$2"
  nor $(and "$A" "$B") $(nor "$A" "$B")
}
#Echo "NE TESTING, Exclusive Disjunction, XOR"
#WORKS
#ne true true   #return 1/false
#ne true false  #return 0/true
#ne false true  #return 0/true
#ne false false #return 1/false

#IF  X THEN Y
if_then () 
{
  local A="$1"
  local B="$2"
or $(not "$A") "$B"
}
#WORKS
#echo "IF_THEN TESTING, Material Implication, IF THEN"
#if_then true true   #return 0/true
#if_then true false  #return 1/false
#if_then false true  #return 0/true
#if_then false false #return 0/true

#IF  Y THEN X
then_if () 
{
  local A="$1"
  local B="$2"
or  "$A" $(not "$B")
}
#WORKS
#echo "THEN_IF TESTING, Converse Implication, THEN IF"
#then_if true true   #return 0/true
#then_if true false  #return 0/true
#then_if false true  #return 1/false
#then_if false false #return 0/true

if_and_only_if () 
{
  local A="$1"
  local B="$2"
and $( or $(not "$A") "$B") $( or $(not "$B") "$A")
#"(not A or B) and (not B or A),"
}
#WORKS
#echo "if_and_only_if TESTING, Logical Biconditional, Exclusive NOR, XNOR, IFF"
#if_and_only_if true true   #return 0/true
#if_and_only_if true false  #return 1/false
#if_and_only_if false true  #return 1/false
#if_and_only_if false false #return 0/true


or_nand () 
{
#OR DEFINED IN TERMS OF NAND 
  local A="$1"
  local B="$2"
nand $(nand "$A" "$A") $(nand "$B" "$B")
}
#WORKS
#echo "IF_THEN TESTING, Material Implication, IF THEN"
#if_then true true   #return 0/true
#if_then true false  #return 1/false
#if_then false true  #return 0/true
#if_then false false #return 0/true


half_adder ()
{
  local A="$1"
  local B="$2"

  # Accept 1/0 bits or true/false strings (same pattern as full_adder).
  # is_true cannot be used here: it follows the shell exit-code convention
  # where "0" = success = true, which is opposite to the bit convention.
  case "$A" in 1|t|T|true|True) A=true ;; *) A=false ;; esac
  case "$B" in 1|t|T|true|True) B=true ;; *) B=false ;; esac

local sum="$(ne "$A" "$B")"
local carry="$(and "$A" "$B")"

if is_true "$sum"; then sum=1; else sum=0; fi

if is_true "$carry"; then carry=1; else carry=0; fi

 

echo "$sum $carry"
}

full_adder ()
{
  local A="$1"
  local B="$2"
  local Carry0="$3"

  # Accept 1/0 bits or true/false strings
  case "$A"      in 1|t|T|true|True) A=true      ;; *) A=false      ;; esac
  case "$B"      in 1|t|T|true|True) B=true      ;; *) B=false      ;; esac
  case "$Carry0" in 1|t|T|true|True) Carry0=true ;; *) Carry0=false ;; esac

  # First half adder: A XOR Carry0
  local ha1
  ha1=$(half_adder "$A" "$Carry0")
  local sum1 carry1
  sum1=$(first "$ha1")
  carry1=$(second "$ha1")
  # half_adder outputs 0/1 digits; convert back to function names for the next stage
  case "$sum1"   in 1) sum1=true   ;; *) sum1=false   ;; esac
  case "$carry1" in 1) carry1=true ;; *) carry1=false ;; esac

  # Second half adder: sum1 XOR B
  local ha2
  ha2=$(half_adder "$sum1" "$B")
  local sum2 carry2
  sum2=$(first "$ha2")   # already a 0/1 digit — final sum bit
  carry2=$(second "$ha2")
  case "$carry2" in 1) carry2=true ;; *) carry2=false ;; esac

  # Final carry = carry1 OR carry2
  local carry
  carry=$(or "$carry1" "$carry2")
  local carry_bit
  if [ "$carry" = "true" ]; then carry_bit=1; else carry_bit=0; fi

  echo "$sum2 $carry_bit"
}

# full_adder testing (A B Cin -> Sum Carry):
#full_adder 0 0 0  # -> 0 0
#full_adder 0 1 0  # -> 1 0
#full_adder 1 1 0  # -> 0 1
#full_adder 1 1 1  # -> 1 1


# MULTI-BIT RIPPLE-CARRY ADDERS AND SUBTRACTORS
# Built by chaining full_adder stages. Every bit string is LSB-first:
# the first argument/output field is bit 0 (the least significant bit).
# Inputs accept 0/1 digits or true/false strings (full_adder normalises them).

ripple_add4 ()
{
  # A0 A1 A2 A3  B0 B1 B2 B3  [Cin]   ->   S0 S1 S2 S3 Cout
  # Threads the carry-out of each full_adder stage into the next stage's carry-in.
  local r c s0 s1 s2 s3 cout
  r=$(full_adder "$1" "$5" "${9:-0}"); s0=$(first "$r"); c=$(second "$r")
  r=$(full_adder "$2" "$6" "$c");      s1=$(first "$r"); c=$(second "$r")
  r=$(full_adder "$3" "$7" "$c");      s2=$(first "$r"); c=$(second "$r")
  r=$(full_adder "$4" "$8" "$c");      s3=$(first "$r"); cout=$(second "$r")
  echo "$s0 $s1 $s2 $s3 $cout"
}

ripple_add8 ()
{
  # A0..A7  B0..B7  [Cin]   ->   S0..S7 Cout
  # Chains two ripple_add4 units: the carry-out of the low nibble (bits 0-3)
  # becomes the carry-in of the high nibble (bits 4-7).
  local cin="${17:-0}"
  local lo hi s0 s1 s2 s3 cmid s4 s5 s6 s7 cout
  lo=$(ripple_add4 "$1" "$2" "$3" "$4"  "$9"  "${10}" "${11}" "${12}" "$cin")
  read -r s0 s1 s2 s3 cmid <<< "$lo"
  hi=$(ripple_add4 "$5" "$6" "$7" "$8"  "${13}" "${14}" "${15}" "${16}" "$cmid")
  read -r s4 s5 s6 s7 cout <<< "$hi"
  echo "$s0 $s1 $s2 $s3 $s4 $s5 $s6 $s7 $cout"
}

flip_bit ()
{
  # Bitwise NOT of a single bit (XOR with 1). Accepts 0/1 or true/false; emits 0/1.
  case "$1" in 1|t|T|true|True) echo 0 ;; *) echo 1 ;; esac
}

ripple_sub4 ()
{
  # A0..A3  B0..B3   ->   D0 D1 D2 D3 Cout      where D = A - B
  # Two's-complement subtraction: A - B = A + (~B) + 1.
  # Flip every B bit and force carry-in = 1.
  # Trailing Cout is the adder carry-out: 1 = no borrow (A >= B);
  # 0 = borrow (A < B), in which case D is the two's-complement of (B - A).
  local fb0 fb1 fb2 fb3
  fb0=$(flip_bit "$5"); fb1=$(flip_bit "$6"); fb2=$(flip_bit "$7"); fb3=$(flip_bit "$8")
  ripple_add4 "$1" "$2" "$3" "$4" "$fb0" "$fb1" "$fb2" "$fb3" 1
}

ripple_sub8 ()
{
  # A0..A7  B0..B7   ->   D0..D7 Cout           where D = A - B
  # Same two's-complement method as ripple_sub4, over 8 bits via ripple_add8.
  local i fb=()
  for i in 9 10 11 12 13 14 15 16; do fb+=("$(flip_bit "${!i}")"); done
  ripple_add8 "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" \
              "${fb[0]}" "${fb[1]}" "${fb[2]}" "${fb[3]}" \
              "${fb[4]}" "${fb[5]}" "${fb[6]}" "${fb[7]}" 1
}

# ripple-carry testing (LSB first):
#ripple_add4 1 1 0 0  1 0 1 0      # 3 + 5  -> 0 0 0 1 0   (= 8)
#ripple_add4 1 1 1 1  1 0 0 0      # 15 + 1 -> 0 0 0 0 1   (= 16, carry-out set)
#ripple_add8 0 0 0 0 0 0 0 1  0 0 0 0 0 0 0 1   # 128+128 -> ...1 (=256)
#ripple_sub4 1 0 1 0  1 1 0 0      # 5 - 3  -> 0 1 0 0 1   (D=2, no borrow)
#ripple_sub4 1 1 0 0  1 0 1 0      # 3 - 5  -> 0 1 1 1 0   (D=14=-2, borrow)


# MAGNITUDE COMPARATORS
# Compare two LSB-first bit strings. Inputs accept 0/1 digits or true/false
# strings. bits_eq and bits_gt are width-generic predicates that echo
# "true"/"false" and set the exit code (Boolean-gate convention), so they
# compose with `if`. compare4/compare8 are positional convenience wrappers
# (matching the ripple_* calling style) that echo "lt" / "eq" / "gt".

bit_to_bool ()
{
  # Normalise a single bit (0/1 or true/false) to the function name true/false,
  # which the Boolean gates require. Companion to flip_bit.
  case "$1" in 1|t|T|true|True) echo true ;; *) echo false ;; esac
}

bits_eq ()
{
  # bits_eq "A0 A1 .. An" "B0 B1 .. Bn"  ->  A == B
  # XNOR (eq) every bit pair, then AND all the results together: equal iff every
  # pair matches.
  local -a A B
  read -ra A <<< "$1"
  read -ra B <<< "$2"
  local acc=true i
  for ((i=0; i<${#A[@]}; i++)); do
    acc=$(and "$acc" "$(eq "$(bit_to_bool "${A[i]}")" "$(bit_to_bool "${B[i]}")")")
  done
  if [ "$acc" = true ]; then echo true; true; else echo false; false; fi
}

bits_gt ()
{
  # bits_gt "A0 A1 .. An" "B0 B1 .. Bn"  ->  A > B
  # Cascaded priority comparison, scanning from the most significant bit down:
  # A > B at the first bit where the two differ and A holds the 1. A running
  # "all higher bits equal" flag gates each lower bit's contribution.
  #   greater      |= higher_equal AND (Ai AND NOT Bi)
  #   higher_equal &= eq(Ai, Bi)
  local -a A B
  read -ra A <<< "$1"
  read -ra B <<< "$2"
  local greater=false higher_equal=true i ai bi mi
  for ((i=${#A[@]}-1; i>=0; i--)); do
    ai=$(bit_to_bool "${A[i]}"); bi=$(bit_to_bool "${B[i]}")
    mi=$(and "$ai" "$(not "$bi")")
    greater=$(or "$greater" "$(and "$higher_equal" "$mi")")
    higher_equal=$(and "$higher_equal" "$(eq "$ai" "$bi")")
  done
  if [ "$greater" = true ]; then echo true; true; else echo false; false; fi
}

# Less-than needs no separate function: A < B is just bits_gt "$B" "$A".

compare4 ()
{
  # A0..A3 B0..B3   ->   echoes "lt" | "eq" | "gt"
  local a="$1 $2 $3 $4" b="$5 $6 $7 $8"
  if   bits_eq "$a" "$b" >/dev/null; then echo eq
  elif bits_gt "$a" "$b" >/dev/null; then echo gt
  else echo lt; fi
}

compare8 ()
{
  # A0..A7 B0..B7   ->   echoes "lt" | "eq" | "gt"
  local a="$1 $2 $3 $4 $5 $6 $7 $8"
  local b="$9 ${10} ${11} ${12} ${13} ${14} ${15} ${16}"
  if   bits_eq "$a" "$b" >/dev/null; then echo eq
  elif bits_gt "$a" "$b" >/dev/null; then echo gt
  else echo lt; fi
}

# comparator testing (LSB first):
#compare4 1 0 1 0  1 1 0 0      # 5 vs 3 -> gt
#compare4 1 1 0 0  1 0 1 0      # 3 vs 5 -> lt
#compare4 1 0 1 0  1 0 1 0      # 5 vs 5 -> eq
#compare4 0 0 0 1  1 1 1 0      # 8 vs 7 -> gt   (decided at the MSB)
#bits_gt  "1 0 1 0" "1 1 0 0"   # true  (5 > 3)
#bits_eq  "1 0 1 0" "1 0 1 0"   # true  (5 == 5)


# EML OPERATOR
# eml(x, y) = exp(x) - ln(y)
# Introduced by Odrzywołek (2026). Functionally complete in continuous mathematics:
# combined with the constant 1 it can express all standard calculator functions.
# Analogous to NAND in Boolean algebra — a single binary operator that generates everything.

eml ()
{
  local x="$1"
  local y="$2"
  echo "e($x) - l($y)" | bc -l
}

# Derived functions expressed as eml trees over the constant 1:

eml_exp ()
{
  # exp(x) = eml(x, 1)
  eml "$1" 1
}

eml_e ()
{
  # e = eml(1, 1) = exp(1) - ln(1) = e - 0
  eml 1 1
}

eml_ln ()
{
  # ln(x) = eml(1, eml(eml(1, x), 1))
  # Derivation:
  #   eml(1, x)          = e - ln(x)
  #   eml(e - ln(x), 1)  = exp(e - ln(x)) = e^e / x
  #   eml(1, e^e / x)    = e - ln(e^e / x) = e - (e - ln(x)) = ln(x)
  local inner mid
  inner=$(eml 1 "$1")
  mid=$(eml "$inner" 1)
  eml 1 "$mid"
}

eml_zero ()
{
  # 0 = eml(1, eml(eml(1,1), 1))
  # Derivation: eml(e, 1) = exp(e); eml(1, exp(e)) = e - ln(exp(e)) = e - e = 0
  eml 1 "$(eml "$(eml 1 1)" 1)"
}

eml_sub ()
{
  # x - y = eml(ln(x), exp(y))
  # Derivation: exp(ln(x)) - ln(exp(y)) = x - y
  # Domain: x > 0
  eml "$(eml_ln "$1")" "$(eml_exp "$2")"
}

eml_neg ()
{
  # -z = log(1) - z = 0 - z
  # Article: "negation: -z <- (log 1) - z"
  # The pure eml form would be eml(ln(0), exp(z)) but ln(0) = -inf;
  # bc handles this limiting case directly.
  echo "0 - ($1)" | bc -l
}

eml_add ()
{
  # x + y = x - (-y) = eml(ln(x), exp(-y))
  # Derivation: exp(ln(x)) - ln(exp(-y)) = x - (-y) = x + y
  # Domain: x > 0
  eml "$(eml_ln "$1")" "$(eml_exp "$(eml_neg "$2")")"
}

eml_mul ()
{
  # x*y = exp(ln(x) + ln(y)) = eml_exp(eml_add(ln(x), ln(y)))
  # Domain: x > 1  (so that ln(x) > 0, satisfying eml_add's requirement)
  eml_exp "$(eml_add "$(eml_ln "$1")" "$(eml_ln "$2")")"
}

eml_div ()
{
  # 1/z = exp(-ln(z)) = eml_exp(eml_neg(ln(z)))
  # Derivation: exp(-ln(z)) = exp(ln(z^-1)) = z^-1 = 1/z
  # Domain: z > 0
  eml_exp "$(eml_neg "$(eml_ln "$1")")"
}

# eml testing:
#eml 1 1                       # -> e (~2.718281828)
#eml_exp 1                     # -> e
#eml_exp 0                     # -> 1
#eml_ln 1                      # -> 0
#eml_ln 2.718281828459045       # -> ~1
#eml_zero                      # -> ~0
#eml_sub 7 3                   # -> ~4
#eml_neg 3                     # -> -3
#eml_add 3 5                   # -> ~8
#eml_mul 3 4                   # -> ~12  (first arg must be > 1)
#eml_div 4                     # -> ~0.25


# EML APPLICATIONS
# Iterative numerical algorithms built on top of the EML arithmetic layer, using
# only eml_mul / eml_sub / eml_add / eml_div in the algorithm itself. They
# inherit the EML domain restrictions — most importantly that eml_mul needs its
# first argument > 1 — which is why these operate on x > 1.

eml_pow_int ()
{
  # base^n for integer n >= 1, via repeated eml_mul. Domain: base > 1.
  local base="$1" n="$2" result="$1" i
  for ((i=1; i<n; i++)); do result=$(eml_mul "$result" "$base"); done
  echo "$result"
}

eml_recip ()
{
  # Reciprocal 1/x by Newton's iteration  y <- y*(2 - x*y), which finds the root
  # of f(y) = 1/y - x using only eml_mul and eml_sub — no division. Converges
  # quadratically. (eml_div computes 1/x directly; this shows the same value
  # falls out of the multiplicative layer alone.)
  #   Args:   x  [max_iterations=8]  [y0=0.5]
  #   Domain: x > 1, and 0 < y0 < 1/x (an underestimate, so the correction
  #           factor c = 2 - x*y stays > 1 for eml_mul). The default y0=0.5 suits
  #           1 < x < 2; for larger x supply a smaller y0 (e.g. x=10 -> y0=0.05).
  # The loop stops as soon as x*y reaches 1 — y has then converged to 1/x, and
  # iterating further would round c just below 1, outside eml_mul's domain.
  local x="$1" iters="${2:-8}" y="${3:-0.5}" i t c
  for ((i=0; i<iters; i++)); do
    t=$(eml_mul "$x" "$y")                        # x*y   (x > 1, so it goes first)
    [ "$(echo "$t >= 1" | bc -l)" = 1 ] && break  # converged: stop before c <= 1
    c=$(eml_sub 2 "$t")                           # 2 - x*y   (> 1)
    y=$(eml_mul "$c" "$y")                         # y*(2 - x*y)
  done
  echo "$y"
}

eml_sin_taylor ()
{
  # sin(x) via its Maclaurin series  x - x^3/3! + x^5/5! - x^7/7! + ...
  # Powers come from eml_pow_int, reciprocal factorials from eml_div, and the
  # alternating accumulation from eml_sub / eml_add.
  #   Args:   x  [terms=6]
  #   Domain: 1 < x <~ pi/2. x > 1 keeps every power inside eml_mul's domain;
  #           the upper bound keeps each partial sum positive for eml_sub/eml_add
  #           (whose first argument must be > 0).
  # Note: acc must be assigned on its own line. In a single `local x=… acc="$x"`
  # statement the RHS "$x" can resolve against an outer x, not the new local.
  local x="$1" terms="${2:-6}" k exp fact recip power term
  local acc="$x"
  for ((k=1; k<terms; k++)); do
    exp=$((2*k + 1))
    power=$(eml_pow_int "$x" "$exp")
    fact=$(echo "f=1; for (i=2; i<=$exp; i++) f*=i; f" | bc)   # (2k+1)! integer
    recip=$(eml_div "$fact")
    term=$(eml_mul "$power" "$recip")        # x^(2k+1) / (2k+1)!  (power > 1 first)
    if (( k % 2 == 1 )); then
      acc=$(eml_sub "$acc" "$term")          # odd k: subtract
    else
      acc=$(eml_add "$acc" "$term")          # even k: add
    fi
  done
  echo "$acc"
}

# EML applications testing:
#eml_pow_int 1.5 3             # -> ~3.375
#eml_recip 1.5                 # -> ~0.6667   (1/1.5)
#eml_recip 10 9 0.05           # -> ~0.1      (1/10; smaller y0 for larger x)
#eml_sin_taylor 1.5            # -> ~0.997    (sin 1.5)
#eml_sin_taylor 1.5707963      # -> ~1.0      (sin pi/2)


# BOOTSTRAPPED MATH LIBRARY
# All functions use bc -l on the backend.
# Reference: https://www.johndcook.com/blog/2021/01/05/bootstrapping-math-library/
# bc primitives: s() sin, c() cos, a() atan, l() ln, e() exp, sqrt()

pi ()     { echo "4*a(1)" | bc -l; }
sqrt ()   { echo "sqrt($1)" | bc -l; }
pow ()    { echo "e($2*l($1))" | bc -l; }        # x^y; domain: x > 0
log_base (){ echo "l($2)/l($1)" | bc -l; }       # log_b(z) = ln(z)/ln(b)

# Trigonometric (arguments in radians)
sin () { echo "s($1)" | bc -l; }
cos () { echo "c($1)" | bc -l; }
tan () { echo "s($1)/c($1)" | bc -l; }
sec () { echo "1/c($1)" | bc -l; }
csc () { echo "1/s($1)" | bc -l; }
cot () { echo "c($1)/s($1)" | bc -l; }

# Inverse trigonometric (results in radians)
# acos and asec use pi/2 - atan(...) to get the correct quadrant for negative x;
# the simpler atan(sqrt(1-x^2)/x) from the article gives wrong sign for x < 0.
atan ()  { echo "a($1)" | bc -l; }
asin ()  { echo "a($1/sqrt(1-($1)*($1)))" | bc -l; }            # domain: |x| < 1
acos ()  { echo "2*a(1)-a($1/sqrt(1-($1)*($1)))" | bc -l; }    # domain: |x| < 1
acot ()  { echo "2*a(1)-a($1)" | bc -l; }                       # pi/2 - atan(x)
asec ()  { echo "2*a(1)-a(($1/sqrt(($1)*($1)))/sqrt(($1)*($1)-1))" | bc -l; }  # domain: |x| > 1
acsc ()  { echo "a(($1/sqrt(($1)*($1)))/sqrt(($1)*($1)-1))" | bc -l; }         # domain: |x| > 1

# Hyperbolic
sinh ()  { echo "(e($1)-e(-($1)))/2" | bc -l; }
cosh ()  { echo "(e($1)+e(-($1)))/2" | bc -l; }
tanh ()  { echo "(e($1)-e(-($1)))/(e($1)+e(-($1)))" | bc -l; }

# Inverse hyperbolic
asinh () { echo "l($1+sqrt(1+($1)*($1)))" | bc -l; }                            # domain: all reals
acosh () { echo "2*l(sqrt(($1+1)/2)+sqrt(($1-1)/2))" | bc -l; }                # domain: x >= 1
atanh () { echo "l((1+($1))/sqrt(1-($1)*($1)))" | bc -l; }                     # domain: |x| < 1

# math library testing:
#pi                    # -> 3.14159265358979323844
#sqrt 9                # -> 3
#pow 2 10              # -> ~1024
#log_base 10 100       # -> 2
#sin 0                 # -> 0
#cos 0                 # -> 1
#tan 0                 # -> 0
#asin 1                # -> pi/2 (domain edge — divide by zero)
#acos 0                # -> pi/2
#acos -0.5             # -> 2*pi/3
#acot 1                # -> pi/4
#asec 2                # -> pi/3
#asec -2               # -> 2*pi/3
#sinh 0                # -> 0
#cosh 0                # -> 1
#tanh 0                # -> 0
#asinh 0               # -> 0
#acosh 1               # -> 0
#atanh 0               # -> 0
