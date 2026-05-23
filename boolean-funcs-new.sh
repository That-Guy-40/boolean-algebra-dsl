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

int_to_bits ()
{
  # Non-negative integer -> LSB-first bit string (the counterpart to the bit
  # decoding the adders/comparators consume). With an optional fixed width it
  # pads (or truncates) to that many bits; otherwise it uses the minimal width.
  #   int_to_bits 5      -> "1 0 1"
  #   int_to_bits 5 6    -> "1 0 1 0 0 0"
  local n="$1" width="${2:-0}" out="" i
  if [ "$width" -gt 0 ]; then
    for ((i=0; i<width; i++)); do out+="$(( (n >> i) & 1 )) "; done
  elif [ "$n" -le 0 ]; then
    echo 0; return
  else
    while [ "$n" -gt 0 ]; do out+="$(( n & 1 )) "; n=$(( n >> 1 )); done
  fi
  echo "${out% }"
}


# WORD-LEVEL BOOLEAN OPERATIONS
# Lift the single-bit gates to whole bit-vectors (LSB-first strings), turning the
# gate layer into a Boolean algebra over words. word_* take/return 0/1 strings;
# the *_all reductions and is_zero return a single Boolean (true/false + exit
# code), like the gates. bit_to_bool / bool_to_bit bridge the 0/1 bit convention
# and the true/false the gates require.

bool_to_bit ()
{
  # Boolean gate output (true/false) -> bit digit (1/0). Inverse of bit_to_bool.
  case "$1" in true|t|T|True|1) echo 1 ;; *) echo 0 ;; esac
}

word_zip ()
{
  # word_zip GATE "A0 A1 .." "B0 B1 .."  ->  bitwise GATE applied position-wise.
  # GATE is any two-input gate (and, or, ne, nand, ...). Widths should match.
  local gate="$1"
  local -a A B
  read -ra A <<< "$2"
  read -ra B <<< "$3"
  local out="" i
  for ((i=0; i<${#A[@]}; i++)); do
    out+="$(bool_to_bit "$("$gate" "$(bit_to_bool "${A[i]}")" "$(bit_to_bool "${B[i]}")")") "
  done
  echo "${out% }"
}

word_not () { local -a A; read -ra A <<< "$1"; local out="" i
              for ((i=0; i<${#A[@]}; i++)); do out+="$(flip_bit "${A[i]}") "; done
              echo "${out% }"; }
word_and () { word_zip and "$1" "$2"; }   # bitwise AND
word_or  () { word_zip or  "$1" "$2"; }   # bitwise OR
word_xor () { word_zip ne  "$1" "$2"; }   # bitwise XOR (ne)

and_all ()
{
  # AND-reduce a word: true iff every bit is 1.
  local -a A; read -ra A <<< "$1"
  local acc=true i
  for ((i=0; i<${#A[@]}; i++)); do acc=$(and "$acc" "$(bit_to_bool "${A[i]}")"); done
  if [ "$acc" = true ]; then echo true; true; else echo false; false; fi
}

or_all ()
{
  # OR-reduce a word: true iff any bit is 1.
  local -a A; read -ra A <<< "$1"
  local acc=false i
  for ((i=0; i<${#A[@]}; i++)); do acc=$(or "$acc" "$(bit_to_bool "${A[i]}")"); done
  if [ "$acc" = true ]; then echo true; true; else echo false; false; fi
}

xor_all ()
{
  # XOR-reduce a word (parity): true iff an odd number of bits are 1.
  local -a A; read -ra A <<< "$1"
  local acc=false i
  for ((i=0; i<${#A[@]}; i++)); do acc=$(ne "$acc" "$(bit_to_bool "${A[i]}")"); done
  if [ "$acc" = true ]; then echo true; true; else echo false; false; fi
}

is_zero ()
{
  # true iff all bits are 0 — the complement of or_all. (ALU zero flag.)
  if or_all "$1" >/dev/null; then echo false; false; else echo true; true; fi
}

# Complement reductions — the negations of the three above.
nand_all () { if and_all "$1" >/dev/null; then echo false; false; else echo true; true; fi; }  # not all set
nor_all  () { if or_all  "$1" >/dev/null; then echo false; false; else echo true; true; fi; }  # no bits set (= is_zero)
xnor_all () { if xor_all "$1" >/dev/null; then echo false; false; else echo true; true; fi; }  # even parity (incl. zero)

# Readable quantifier aliases. (or_all already means "any bit set", so "any" is
# just a friendlier name for it — there is no separate single-word or_any.)
all  () { and_all "$1"; }   # ∀ bits set
any  () { or_all  "$1"; }   # ∃ a set bit
none () { nor_all "$1"; }   # no set bits

# Two-word "any-position" predicates: ∃ a bit position where (A op B) holds.
# Each reduces a position-wise word op with or_all, so widths should match.
and_any () { if or_all "$(word_and "$1" "$2")" >/dev/null; then echo true; true; else echo false; false; fi; }  # masks overlap
or_any  () { if or_all "$(word_or  "$1" "$2")" >/dev/null; then echo true; true; else echo false; false; fi; }  # any bit set in either
xor_any () { if or_all "$(word_xor "$1" "$2")" >/dev/null; then echo true; true; else echo false; false; fi; }  # differ anywhere (= ¬bits_eq)

# word-op testing (LSB-first):
#word_not "1 0 1 1"               # -> 0 1 0 0
#word_and "1 1 0 0" "1 0 1 0"     # -> 1 0 0 0
#word_or  "1 1 0 0" "1 0 1 0"     # -> 1 1 1 0
#word_xor "1 1 0 0" "1 0 1 0"     # -> 0 1 1 0
#and_all  "1 1 1 1"               # -> true
#or_all   "0 0 0 0"               # -> false
#xor_all  "1 1 0 1"               # -> true   (odd parity)
#is_zero  "0 0 0 0"               # -> true
#nand_all "1 1 0 1"               # -> true   (not all set)
#xnor_all "1 1 0 0"               # -> true   (even parity)
#any "0 0 1 0"                    # -> true   (alias for or_all)
#and_any "1 1 0 0" "1 0 1 0"      # -> true   (3 and 5 share bit 0)
#xor_any "1 0 1 0" "1 0 1 0"      # -> false  (5 == 5, differ nowhere)


# WORD HELPERS AND PREDICATES
# Convenience functions over LSB-first bit-vectors. The inc/dec/negate helpers
# return a word of the same width (results wrap, two's-complement style). The
# is_* predicates echo true/false and set the exit code, like the gates, so they
# drop into `if`. parity/popcount/lsb/msb/bits_to_int are plain readouts.

inc ()
{
  # W + 1, width-preserving. Ripples a carry of 1 from the LSB through a chain of
  # half adders: at each bit, (sum, carry) = half_adder(bit, carry_in).
  local -a A; read -ra A <<< "$1"
  local out="" i carry=1 r
  for ((i=0; i<${#A[@]}; i++)); do
    r=$(half_adder "${A[i]}" "$carry")
    out+="$(first "$r") "
    carry=$(second "$r")
  done
  echo "${out% }"
}

dec ()
{
  # W - 1, width-preserving. Ripples a borrow of 1 from the LSB:
  #   diff   = bit XOR borrow
  #   borrow = (NOT bit) AND borrow
  local -a A; read -ra A <<< "$1"
  local out="" i borrow=1 ai bb
  for ((i=0; i<${#A[@]}; i++)); do
    ai=$(bit_to_bool "${A[i]}"); bb=$(bit_to_bool "$borrow")
    out+="$(bool_to_bit "$(ne "$ai" "$bb")") "
    borrow=$(bool_to_bit "$(and "$(not "$ai")" "$bb")")
  done
  echo "${out% }"
}

negate () { inc "$(word_not "$1")"; }   # two's complement:  -W = (¬W) + 1

is_one ()
{
  # true iff the word represents 1 — LSB set, every higher bit clear.
  local -a A; read -ra A <<< "$1"
  if [ "$(bit_to_bool "${A[0]}")" = true ] && is_zero "${A[*]:1}" >/dev/null
  then echo true; true; else echo false; false; fi
}

is_even ()
{
  # true iff the value is even — LSB (bit 0) is 0.
  local -a A; read -ra A <<< "$1"
  if [ "$(bit_to_bool "${A[0]}")" = false ]; then echo true; true; else echo false; false; fi
}

is_odd () { if is_even "$1" >/dev/null; then echo false; false; else echo true; true; fi; }

is_negative ()
{
  # true iff the two's-complement sign bit (the MSB) is set.
  local -a A; read -ra A <<< "$1"
  if [ "$(bit_to_bool "${A[${#A[@]}-1]}")" = true ]; then echo true; true; else echo false; false; fi
}

parity ()
{
  # Parity BIT (0/1) = XOR of all bits — i.e. bool_to_bit(xor_all). 1 = odd count
  # of ones. (xor_all returns the same information as a true/false predicate.)
  bool_to_bit "$(xor_all "$1")"
}

popcount ()
{
  # Number of 1 bits (Hamming weight), as a decimal integer.
  local -a A; read -ra A <<< "$1"
  local n=0 i
  for ((i=0; i<${#A[@]}; i++)); do
    [ "$(bit_to_bool "${A[i]}")" = true ] && n=$((n + 1))
  done
  echo "$n"
}

lsb () { local -a A; read -ra A <<< "$1"; echo "${A[0]}"; }              # least significant bit
msb () { local -a A; read -ra A <<< "$1"; echo "${A[${#A[@]}-1]}"; }      # most significant bit

bits_to_int ()
{
  # Decode an LSB-first bit string to a decimal integer (inverse of int_to_bits).
  local -a A; read -ra A <<< "$1"
  local d=0 i
  for ((i=0; i<${#A[@]}; i++)); do
    [ "$(bit_to_bool "${A[i]}")" = true ] && d=$((d + (1 << i)))
  done
  echo "$d"
}

# word-helper testing (LSB-first):
#inc "1 1 0 0"                    # -> 0 0 1 0   (3 + 1 = 4)
#dec "0 0 1 0"                    # -> 1 1 0 0   (4 - 1 = 3)
#negate "1 1 0 0"                 # -> 1 0 1 1   (-3 = 13 in 4-bit two's complement)
#is_one "1 0 0 0"                 # -> true
#is_even "1 1 0 0"                # -> false  (3 is odd)
#is_negative "0 0 1 1"            # -> true   (MSB set; 12 = -4 signed)
#parity "1 1 1 0"                 # -> 1      (three ones = odd)
#popcount "1 1 1 0"               # -> 3
#bits_to_int "0 0 1 0"            # -> 4


# MULTIPLEXER, MIN, AND MAX
# A 2:1 multiplexer (the canonical "select one of two" circuit) and the
# magnitude min/max built from it: the comparator decides, the mux routes.

mux ()
{
  # 1-bit 2:1 multiplexer:  mux SEL a b  ->  a if SEL is 0/false, b if 1/true.
  # Gate form:  out = (¬SEL ∧ a) ∨ (SEL ∧ b).
  local sel a b
  sel=$(bit_to_bool "$1"); a=$(bit_to_bool "$2"); b=$(bit_to_bool "$3")
  bool_to_bit "$(or "$(and "$(not "$sel")" "$a")" "$(and "$sel" "$b")")"
}

word_mux ()
{
  # word-level 2:1 mux:  word_mux SEL A B  ->  A if SEL 0/false, B if 1/true.
  # Applies the 1-bit mux at every position with the shared select line.
  local sel="$1"
  local -a A B; read -ra A <<< "$2"; read -ra B <<< "$3"
  local out="" i
  for ((i=0; i<${#A[@]}; i++)); do out+="$(mux "$sel" "${A[i]}" "${B[i]}") "; done
  echo "${out% }"
}

bits_min ()
{
  # min(A, B): the comparator picks the select line, word_mux routes the answer.
  # word_mux sel A B yields A when sel=0; we want A exactly when A < B (= bits_gt B A).
  local A="$1" B="$2" sel
  if bits_gt "$B" "$A" >/dev/null; then sel=0; else sel=1; fi   # A < B -> keep A
  word_mux "$sel" "$A" "$B"
}

bits_max ()
{
  # max(A, B): the mirror of bits_min — keep B when A < B, else keep A.
  local A="$1" B="$2" sel
  if bits_gt "$B" "$A" >/dev/null; then sel=1; else sel=0; fi   # A < B -> take B
  word_mux "$sel" "$A" "$B"
}

# mux / min / max testing (LSB-first):
#mux 0 1 0                        # -> 1   (select a)
#mux 1 1 0                        # -> 0   (select b)
#word_mux 0 "1 1 0 0" "1 0 1 0"   # -> 1 1 0 0   (A)
#word_mux 1 "1 1 0 0" "1 0 1 0"   # -> 1 0 1 0   (B)
#bits_min "1 1 0 0" "1 0 1 0"     # -> 1 1 0 0   (min(3,5) = 3)
#bits_max "1 1 0 0" "1 0 1 0"     # -> 1 0 1 0   (max(3,5) = 5)


# SHIFTS AND THE ALU
# Logical shifts (LSB-first, fixed width) and a 4-bit arithmetic-logic unit that
# ties the whole Layer-1 stack together: the ripple adder/subtractor, the
# word-level bitwise ops, the comparator, the shifters, and is_zero for a flag.

shl ()
{
  # Logical shift left by n (default 1), preserving width. LSB-first, so a left
  # shift moves each bit to a higher index (multiply by 2ⁿ); vacated low bits
  # are 0 and bits past the top are dropped.
  local -a A; read -ra A <<< "$1"
  local n="${2:-1}" w=${#A[@]} out="" i src
  for ((i=0; i<w; i++)); do
    src=$((i - n))
    if [ "$src" -ge 0 ]; then out+="${A[src]} "; else out+="0 "; fi
  done
  echo "${out% }"
}

shr ()
{
  # Logical shift right by n (default 1), preserving width (divide by 2ⁿ).
  local -a A; read -ra A <<< "$1"
  local n="${2:-1}" w=${#A[@]} out="" i src
  for ((i=0; i<w; i++)); do
    src=$((i + n))
    if [ "$src" -lt "$w" ]; then out+="${A[src]} "; else out+="0 "; fi
  done
  echo "${out% }"
}

alu4 ()
{
  # 4-bit ALU.  alu4 OP  A0 A1 A2 A3  B0 B1 B2 B3   (LSB-first)
  #   OP ∈ add sub and or xor not slt shl shr
  # Output:  "R0 R1 R2 R3 Z C N V"  — 4 result bits then four status flags:
  #   Z zero (result is all zeros), C carry-out (add/sub) or shifted-out bit,
  #   N negative (result MSB, two's-complement sign), V signed overflow (add/sub).
  # Data path is all circuits: ripple_add4/ripple_sub4, word_*, bits_gt, shl/shr.
  local op="$1"; shift
  local A="$1 $2 $3 $4" B="$5 $6 $7 $8" a3="$4" b3="$8"
  local result c=0 r
  case "$op" in
    add) r=$(ripple_add4 $A $B); result="${r% *}"; c="${r##* }" ;;
    sub) r=$(ripple_sub4 $A $B); result="${r% *}"; c="${r##* }" ;;  # C=1 means no borrow
    and) result=$(word_and "$A" "$B") ;;
    or)  result=$(word_or  "$A" "$B") ;;
    xor) result=$(word_xor "$A" "$B") ;;
    not) result=$(word_not "$A") ;;                                  # unary; B ignored
    slt) if bits_gt "$B" "$A" >/dev/null; then result="1 0 0 0"; else result="0 0 0 0"; fi ;;
    shl) result=$(shl "$A" 1); c="$4" ;;                             # C = bit shifted out (MSB)
    shr) result=$(shr "$A" 1); c="$1" ;;                             # C = bit shifted out (LSB)
    *)   echo "alu4: unknown op '$op'" >&2; return 2 ;;
  esac
  local -a R; read -ra R <<< "$result"
  local n="${R[3]}" z v=0
  if is_zero "$result" >/dev/null; then z=1; else z=0; fi
  # Signed overflow: add when operands share a sign but the result flips it;
  # sub when operands differ in sign and the result's sign differs from A's.
  case "$op" in
    add) [ "$a3" = "$b3" ]  && [ "${R[3]}" != "$a3" ] && v=1 ;;
    sub) [ "$a3" != "$b3" ] && [ "${R[3]}" != "$a3" ] && v=1 ;;
  esac
  echo "$result $z $c $n $v"
}

# shift / ALU testing (LSB-first; ALU output = R0 R1 R2 R3 Z C N V):
#shl "1 1 0 0"                 # -> 0 1 1 0   (3 << 1 = 6)
#shr "1 1 0 0"                 # -> 1 0 0 0   (3 >> 1 = 1)
#alu4 add 1 1 0 0  1 0 1 0     # -> 0 0 0 1 0 0 1 1   (3+5=8: overflow V=1, N=1)
#alu4 sub 1 0 1 0  1 1 0 0     # -> 0 1 0 0 0 1 0 0   (5-3=2: C=1 no borrow)
#alu4 and 1 1 0 0  1 0 1 0     # -> 1 0 0 0 0 0 0 0   (3 & 5 = 1)
#alu4 slt 1 1 0 0  1 0 1 0     # -> 1 0 0 0 0 0 0 0   (3 < 5 -> 1)


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

eml_recip_auto ()
{
  # 1/x with the Newton seed chosen automatically — no hand-supplied y0.
  # Cross-layer demo: the Layer-1 bit comparator brackets x's magnitude, then
  # that bracket seeds the Layer-2 Newton reciprocal.
  #
  # Pick k = bit-length of floor(x): the smallest k with 2^k > floor(x), found
  # by asking the comparator "is 2^k > floor(x)?" for k = 0,1,2,... Because
  # 2^(k-1) <= floor(x) <= x < 2^k, the seed y0 = 2^-k satisfies 0 < y0 < 1/x,
  # which is exactly the underestimate eml_recip needs.
  #   Args:   x  [max_iterations=12]
  #   Domain: 1 < x < 2^W (W=12 here, so x up to ~2047 — floor(x) and 2^k must
  #           fit in W bits for the comparator).
  local x="$1" iters="${2:-12}" W=12
  local m="${x%%.*}"                       # floor(x); x > 1 so m >= 1
  case "$m" in ''|*[!0-9]*) m=1 ;; esac    # guard against a bare ".5" etc.
  local mbits k=0
  mbits=$(int_to_bits "$m" "$W")
  # bits_gt echoes true/false as well as setting the exit code; here we only
  # want the exit code, so discard the echoed string.
  while ! bits_gt "$(int_to_bits $((1 << k)) "$W")" "$mbits" >/dev/null; do
    k=$((k + 1))
  done
  eml_recip "$x" "$iters" "$(echo "scale=40; 1/(2^$k)" | bc -l)"
}

# EML applications testing:
#eml_pow_int 1.5 3             # -> ~3.375
#eml_recip 1.5                 # -> ~0.6667   (1/1.5)
#eml_recip 10 9 0.05           # -> ~0.1      (1/10; smaller y0 for larger x)
#eml_sin_taylor 1.5            # -> ~0.997    (sin 1.5)
#eml_sin_taylor 1.5707963      # -> ~1.0      (sin pi/2)
#eml_recip_auto 10             # -> ~0.1      (seed picked automatically)
#eml_recip_auto 100            # -> ~0.01


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
