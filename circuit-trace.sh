#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# CIRCUIT TRACE — a viewer for Layer 1, in the spirit of fsm_trace / tm_trace
#
# Layer 1's adders and ALU give you the *answer* but hide the *journey*: you can't
# see the carry ripple from bit to bit, or watch the status flags get decided. This
# file is a read-only VIEWER over the gates — it changes nothing in the pristine core
# (boolean-funcs-new.sh). Every trace re-runs the SAME primitive `full_adder` the real
# adder uses, one bit at a time, so the picture can never drift from the circuit.
#
#   add_trace  A B [Cin]   -> the ripple-carry adder as a per-bit table  (= word_add)
#   sub_trace  A B         -> subtraction shown as  A + (¬B) + 1         (= word_sub)
#   alu_trace  OP A B      -> the ALU dashboard: result + decoded Z/C/N/V flags
#   bits_show  "BITS"      -> a bit string with its decimal value, e.g. "1 0 1 0  (=5)"
#
# Bit strings are LSB-first, exactly as everywhere else in the project.
# ─────────────────────────────────────────────────────────────────────────────

source "$(dirname "${BASH_SOURCE[0]}")/boolean-funcs-new.sh"   # the gates, adders, ALU

# ── small helpers ─────────────────────────────────────────────────────────────

bits_show () {            # "BITS" -> "1 0 1 0  (=5)"
  printf '%s  (=%s)' "$1" "$(bits_to_int "$1")"
}

_ct_pad () {              # N "BITS" -> the bits, zero-filled (LSB-first) out to N cells
  local -a A; read -ra A <<< "$2"; local i
  for ((i=${#A[@]}; i<$1; i++)); do A[i]=0; done
  printf '%s' "${A[*]}"
}

# ── the ripple-carry table (shared by add_trace and sub_trace) ────────────────

# Prints the table and leaves its results in _CT_SUM / _CT_COUT for the caller to
# interpret (carry-out means different things for add vs sub).
_ct_ripple () {           # TITLE "A" "B" Cin   -> header, per-bit table, summary
  local title="$1" cin="${4:-0}"
  local -a A B; read -ra A <<< "$2"; read -ra B <<< "$3"
  local w=${#A[@]}; [ "${#B[@]}" -gt "$w" ] && w=${#B[@]}
  read -ra A <<< "$(_ct_pad "$w" "$2")"
  read -ra B <<< "$(_ct_pad "$w" "$3")"

  printf '\n  %s — LSB-first\n\n' "$title"
  printf '  A   = %s\n' "$(bits_show "${A[*]}")"
  printf '  B   = %s\n' "$(bits_show "${B[*]}")"
  printf '  Cin = %s\n\n' "$cin"
  printf '  bit │ A  B  Cin → Sum  Cout\n'
  printf '  ────┼─────────────────────\n'

  local i carry="$cin" r sum cout note sumbits=""
  for ((i=0; i<w; i++)); do
    r=$(full_adder "${A[i]}" "${B[i]}" "$carry")
    sum=$(first "$r"); cout=$(second "$r")
    note=""
    if [ "$carry" = 1 ]; then
      if [ "$i" = 0 ]; then note="   ◄ carry in (initial Cin)"
      else                 note="   ◄ carry in from bit $((i-1))"; fi
    fi
    printf '  %2d  │ %s  %s   %s  →  %s     %s%s\n' \
           "$i" "${A[i]}" "${B[i]}" "$carry" "$sum" "$cout" "$note"
    sumbits+="$sum "
    carry="$cout"
  done

  printf '  ────┴─────────────────────\n'
  printf '  Sum = %s   Cout = %s\n' "$(bits_show "${sumbits% }")" "$carry"
  _CT_SUM="${sumbits% }"; _CT_COUT="$carry"
}

add_trace () {            # A B [Cin]  -> the ripple-carry adder, bit by bit
  _ct_ripple "ripple-carry ADD" "$1" "$2" "${3:-0}"
  [ "$_CT_COUT" = 1 ] && printf '  (a carry rippled off the top — overflow beyond the word width)\n'
  return 0
}

sub_trace () {            # A B  ->  A - B, shown as the two's-complement add A + (¬B) + 1
  local w; local -a _a _b; read -ra _a <<< "$1"; read -ra _b <<< "$2"
  w=${#_a[@]}; [ "${#_b[@]}" -gt "$w" ] && w=${#_b[@]}
  local A B nb
  A="$(_ct_pad "$w" "$1")"; B="$(_ct_pad "$w" "$2")"; nb="$(word_not "$B")"
  printf '\n  two'\''s-complement SUBTRACT:  A - B  =  A + (¬B) + 1\n'
  printf '    A  = %s\n' "$(bits_show "$A")"
  printf '    B  = %s\n' "$(bits_show "$B")"
  printf '    ¬B = %s     (flip every bit; then add with Cin = 1)\n' "$(bits_show "$nb")"
  _ct_ripple "the resulting ADD  A + (¬B) + 1" "$A" "$nb" 1
  if [ "$_CT_COUT" = 1 ]; then printf '  Cout = 1  →  no borrow (A ≥ B); the result is A − B.\n'
  else                         printf '  Cout = 0  →  borrow (A < B); the result is the two'\''s complement of (B − A).\n'; fi
  return 0
}

# ── the ALU dashboard ─────────────────────────────────────────────────────────

alu_trace () {            # OP A B  -> result + plain-English Z/C/N/V flags
  local op="$1" A B w out; local -a _a _b
  read -ra _a <<< "$2"; read -ra _b <<< "$3"
  w=${#_a[@]}; [ "${#_b[@]}" -gt "$w" ] && w=${#_b[@]}
  local width=4; [ "$w" -gt 4 ] && width=8
  A="$(_ct_pad "$width" "$2")"; B="$(_ct_pad "$width" "$3")"

  if [ "$width" = 4 ]; then out=$(alu4 "$op" $A $B); else out=$(alu8 "$op" $A $B); fi
  local -a O; read -ra O <<< "$out"
  local result="${O[*]:0:width}" z="${O[width]}" c="${O[width+1]}" n="${O[width+2]}" v="${O[width+3]}"

  printf '\n  ══ ALU (%d-bit)  op = %s ══\n' "$width" "$op"
  printf '    A      = %s\n' "$(bits_show "$A")"
  case "$op" in not) ;; *) printf '    B      = %s\n' "$(bits_show "$B")" ;; esac
  printf '    result = %s\n\n' "$(bits_show "$result")"

  # decode the flags into plain English
  local cmeaning
  case "$op" in
    add) cmeaning=$([ "$c" = 1 ] && echo "carry-out set (unsigned overflow)" || echo "no carry-out") ;;
    sub) cmeaning=$([ "$c" = 1 ] && echo "no borrow (A ≥ B)" || echo "borrow (A < B)") ;;
    shl|shr) cmeaning="the bit shifted out" ;;
    *)   cmeaning="(unused by this op)" ;;
  esac
  printf '    Z = %s  %s\n' "$z" "$([ "$z" = 1 ] && echo "result is zero"      || echo "result is non-zero")"
  printf '    C = %s  %s\n' "$c" "$cmeaning"
  printf '    N = %s  %s\n' "$n" "$([ "$n" = 1 ] && echo "negative (sign bit set)" || echo "non-negative")"
  printf '    V = %s  %s\n' "$v" "$([ "$v" = 1 ] && echo "signed overflow"     || echo "no signed overflow")"

  # for add/sub, also show the carry rippling through the data path
  case "$op" in
    add) add_trace "$A" "$B" ;;
    sub) sub_trace "$A" "$B" ;;
  esac
}

# example use:
#   source ./circuit-trace.sh
#   add_trace "1 0 1 0" "0 1 1 0"        # 5 + 6, watch the carry ripple
#   sub_trace "1 0 1 0" "1 1 0 0"        # 5 - 3, as A + (¬B) + 1
#   alu_trace add "1 0 1 0" "0 1 1 0"    # the full dashboard with decoded flags
#   alu_trace slt "1 0 0 0" "0 1 0 0"    # set-less-than, 1 < 2 -> result 1
