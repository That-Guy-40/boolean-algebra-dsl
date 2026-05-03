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
#
  local A="$1"
  local B="$2"

if is_true "$A"; then A=true; else A=false; fi

if is_true "$B"; then B=true; else B=false; fi

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
