#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# LIST-PROCESSING KIT  (a small Scheme/Lisp-style toolkit over space-separated lists)
#
# A "list" is a space-separated string of atoms (the LSB-first / Scheme
# convention; atoms must not contain spaces). A "fn value" is a string of bash
# code reading its argument(s) from $1 (and $2) and echoing its result; map / fold
# / etc. also accept a bare command NAME, normalised by as_fn / as_fn2 / as_fn3.
#
#   as_fn / as_fn2                          normalise a command name OR a fn value
#   lnull / lhead / ltail / llength         list primitives
#   map / mapcar f xs                       map a unary f over a list (iter / recur)
#   filter pred xs                          keep atoms where pred echoes "true"
#   foldl / foldr f z xs                    left / right fold with a binary f
#   foldl1 f xs                             foldl seeded by the first atom
#   scanl f z xs                            the list of running fold accumulators
#   zipwith f xs ys                         element-wise combine (length = shorter)
#   zip / unzip / flatten                   ':'-joined tuples ↔ flat lists
#   take / drop n xs                        prefix / suffix
#   take_while / drop_while pred xs         …and take_until / drop_until
#   lrange a b / lreverse xs / iterate f x n  generators
#   any / all pred xs                       exists / forall over a predicate
#   none / count_if / elem / find_index     more predicate & search helpers
#   and_list / or_list / lsum / lproduct    reduce true/false- or integer-lists
#   complement / conj / disj p [q]          combine predicates into new predicates
#   replicate n x / intercalate sep xs      builders
#   zipwith3 f xs ys zs                     element-wise combine of three lists
#
# SELF-CONTAINED: the kit bundles the application combinators it relies on
# (`apply`, `apply2`, `apply3`) so it works when sourced on its own — no other file
# needed. `apply`/`apply2` are an exact copy of the combinator core in
# alt-arithmetic.sh; when that file sources this kit the definitions are identical,
# so it is harmless (the extra `apply3`/`as_fn3` simply become available too).
#
# The payoff — these reconstruct the Layer-1 word ops from the other direction:
#   map flip_bit bits      = word_not          zipwith <xor> a b = word_xor
#   foldl and true bools   = and_all            all/any (=1?)     = and_all/or_all
# combinator-circuits.sh turns these into named fp_* functions (and the ripple adder
# into a carry-threading foldl/scanl), cross-checked bit-for-bit against Layer 1.
# ─────────────────────────────────────────────────────────────────────────────

# Application combinators (duplicated from alt-arithmetic.sh's core, so the kit is
# standalone). A "fn value" is bash code reading its argument(s) from $1 (and $2).
apply  () { local __f="$1" __x="$2"; set -- "$__x"; eval "$__f"; }                    # f(x)
apply2 () { local __f="$1" __a="$2" __b="$3"; set -- "$__a" "$__b"; eval "$__f"; }    # f(a, b)
apply3 () { local __f="$1" __a="$2" __b="$3" __c="$4"; set -- "$__a" "$__b" "$__c"; eval "$__f"; }  # f(a, b, c)

# Normalise a function argument: a fn value (mentions $1/$2) is used as-is; a bare
# command name is wrapped so it reads its argument(s) positionally.
as_fn   () { case "$1" in *'$1'*)        printf '%s' "$1" ;; *) printf '%s "$1"' "$1" ;; esac; }
as_fn2  () { case "$1" in *'$1'*|*'$2'*) printf '%s' "$1" ;; *) printf '%s "$1" "$2"' "$1" ;; esac; }
as_fn3  () { case "$1" in *'$1'*|*'$2'*|*'$3'*) printf '%s' "$1" ;; *) printf '%s "$1" "$2" "$3"' "$1" ;; esac; }

# Scheme-style list primitives (space-separated word lists).
lnull   () { set -- $1; [ $# -eq 0 ]; }
lhead   () { set -- $1; printf '%s' "$1"; }
ltail   () { set -- $1; shift; echo "$*"; }
llength () { set -- $1; echo $#; }

map () {                                  # map FN list   (FN unary; command or fn value)
  local f res="" e; f=$(as_fn "$1")
  for e in $2; do res+=" $(apply "$f" "$e")"; done
  echo "${res# }"
}

mapcar () {                               # recursive (Scheme) twin of map
  local f="$1" list="$2" h t
  lnull "$list" && return 0
  h=$(apply "$(as_fn "$f")" "$(lhead "$list")")
  t=$(mapcar "$f" "$(ltail "$list")")
  if [ -z "$t" ]; then printf '%s\n' "$h"; else printf '%s %s\n' "$h" "$t"; fi
}

filter () {                               # filter PRED list  (PRED echoes "true"/"false")
  local p res="" e; p=$(as_fn "$1")
  for e in $2; do [ "$(apply "$p" "$e")" = true ] && res+=" $e"; done
  echo "${res# }"
}

foldl () {                                # foldl F acc list  (F binary; command or fn value)
  local f acc="$2" e; f=$(as_fn2 "$1")
  for e in $3; do acc=$(apply2 "$f" "$acc" "$e"); done
  printf '%s' "$acc"
}

foldr () {                                # foldr F end list  (right fold)
  local f="$1" end="$2" list="$3" cf h rest
  lnull "$list" && { printf '%s' "$end"; return; }
  cf=$(as_fn2 "$f"); h=$(lhead "$list"); rest=$(foldr "$f" "$end" "$(ltail "$list")")
  apply2 "$cf" "$h" "$rest"
}

foldl1 () {                               # foldl with no seed: uses the first atom (list must be non-empty)
  local f="$1" list="$2"
  lnull "$list" && return 1
  foldl "$f" "$(lhead "$list")" "$(ltail "$list")"
}

scanl () {                                # scanl F z xs -> [z, F z x1, F (F z x1) x2, …]  (the running accumulators)
  local f acc="$2" e res; f=$(as_fn2 "$1"); res="$acc"
  for e in $3; do acc=$(apply2 "$f" "$acc" "$e"); res+=" $acc"; done
  echo "$res"
}

zipwith () {                              # zipwith F xs ys  (F binary; element-wise; len = min)
  local f res="" i; f=$(as_fn2 "$1")
  local -a A B; read -ra A <<< "$2"; read -ra B <<< "$3"
  local n=${#A[@]}; [ ${#B[@]} -lt "$n" ] && n=${#B[@]}
  for ((i=0; i<n; i++)); do res+=" $(apply2 "$f" "${A[i]}" "${B[i]}")"; done
  echo "${res# }"
}

# zip / unzip / flatten work over ':'-joined tuples, since a flat space-list can't
# nest. zip pairs two lists into "a:1 b:2 …"; unzip splits back into two lines
# (firsts, then seconds); flatten dissolves the ':' grouping into one flat list.
zip () { zipwith 'printf "%s:%s" "$1" "$2"' "$1" "$2"; }   # ["a","b"] ["1","2"] -> "a:1 b:2"
unzip () {                                # "a:1 b:2 c:3" -> two lines: "a b c" then "1 2 3"
  local fst="" snd="" e
  for e in $1; do fst+=" ${e%%:*}"; snd+=" ${e#*:}"; done
  printf '%s\n%s\n' "${fst# }" "${snd# }"
}
flatten () { local s="${1//:/ }"; echo $s; }              # "1:a 2:b" -> "1 a 2 b" (split atoms on ':')

take () { local n="$1" res="" e i=0; for e in $2; do [ "$i" -ge "$n" ] && break; res+=" $e"; i=$((i+1)); done; echo "${res# }"; }
drop () { local n="$1" res="" e i=0; for e in $2; do [ "$i" -ge "$n" ] && res+=" $e"; i=$((i+1)); done; echo "${res# }"; }

take_while () {                           # longest prefix where PRED echoes true
  local p res="" e; p=$(as_fn "$1")
  for e in $2; do [ "$(apply "$p" "$e")" = true ] || break; res+=" $e"; done
  echo "${res# }"
}
drop_while () {                           # the rest after take_while's prefix
  local p res="" e dropping=1; p=$(as_fn "$1")
  for e in $2; do
    if [ "$dropping" = 1 ] && [ "$(apply "$p" "$e")" = true ]; then continue; fi
    dropping=0; res+=" $e"
  done
  echo "${res# }"
}
take_until () {                           # prefix until PRED first becomes true (= take_while of ¬pred)
  local p res="" e; p=$(as_fn "$1")
  for e in $2; do [ "$(apply "$p" "$e")" = true ] && break; res+=" $e"; done
  echo "${res# }"
}
drop_until () {                           # complement of take_until
  local p res="" e dropping=1; p=$(as_fn "$1")
  for e in $2; do
    if [ "$dropping" = 1 ] && [ "$(apply "$p" "$e")" != true ]; then continue; fi
    dropping=0; res+=" $e"
  done
  echo "${res# }"
}

lrange   () { local a="$1" b="$2" res="" i; for ((i=a; i<=b; i++)); do res+=" $i"; done; echo "${res# }"; }   # inclusive A..B
lreverse () { local res="" e; for e in $1; do res="$e${res:+ }$res"; done; echo "$res"; }
iterate  () {                             # iterate F x N -> N elements [x, f x, f(f x), …]
  local f x="$2" n="$3" res="" i; f=$(as_fn "$1")
  for ((i=0; i<n; i++)); do res+=" $x"; x=$(apply "$f" "$x"); done
  echo "${res# }"
}

any () { local p e; p=$(as_fn "$1"); for e in $2; do [ "$(apply "$p" "$e")" = true ] && { echo true; return; }; done; echo false; }
all () { local p e; p=$(as_fn "$1"); for e in $2; do [ "$(apply "$p" "$e")" = true ] || { echo false; return; }; done; echo true; }

# ── More predicates & search ─────────────────────────────────────────────────
none () { case "$(any "$1" "$2")" in true) echo false ;; *) echo true ;; esac; }   # ¬∃ : no atom satisfies pred

count_if () {                             # how many atoms satisfy PRED
  local p n=0 e; p=$(as_fn "$1")
  for e in $2; do [ "$(apply "$p" "$e")" = true ] && n=$((n+1)); done
  echo "$n"
}
elem () {                                 # elem X xs -> "true" if X is an atom of xs, else "false"
  local x="$1" e
  for e in $2; do [ "$e" = "$x" ] && { echo true; return; }; done
  echo false
}
find_index () {                           # 0-based index of the first atom satisfying PRED, or -1
  local p i=0 e; p=$(as_fn "$1")
  for e in $2; do [ "$(apply "$p" "$e")" = true ] && { echo "$i"; return; }; i=$((i+1)); done
  echo -1
}

# ── Reductions over already-decided values (domain-neutral: no Layer-1 gates) ──
# and_list / or_list reduce a list of the literal atoms "true"/"false"; lsum /
# lproduct reduce a list of integers. These need no gates — they are the kit's
# own folds over decided values, so the kit stays standalone.
and_list () { all 'printf "%s" "$1"' "$1"; }        # "true" iff every atom is literally "true"
or_list  () { any 'printf "%s" "$1"' "$1"; }        # "true" iff some atom is literally "true"
lsum     () { foldl 'echo $(($1 + $2))' 0 "$1"; }   # sum of an integer list
lproduct () { foldl 'echo $(($1 * $2))' 1 "$1"; }   # product of an integer list

# ── Predicate combinators (each returns a NEW predicate as a fn value) ────────
complement () {                           # complement P  -> predicate that negates P
  local p; p=$(as_fn "$1")
  printf 'case "$(apply %q "$1")" in true) printf false ;; *) printf true ;; esac' "$p"
}
conj () {                                 # conj P Q -> predicate "P and Q"
  local p q; p=$(as_fn "$1"); q=$(as_fn "$2")
  printf 'if [ "$(apply %q "$1")" = true ] && [ "$(apply %q "$1")" = true ]; then printf true; else printf false; fi' "$p" "$q"
}
disj () {                                 # disj P Q -> predicate "P or Q"
  local p q; p=$(as_fn "$1"); q=$(as_fn "$2")
  printf 'if [ "$(apply %q "$1")" = true ] || [ "$(apply %q "$1")" = true ]; then printf true; else printf false; fi' "$p" "$q"
}

# ── Builders ─────────────────────────────────────────────────────────────────
replicate () { local n="$1" x="$2" out="" i; for ((i=0; i<n; i++)); do out+=" $x"; done; echo "${out# }"; }   # n copies of x
intercalate () {                          # join the atoms of xs with SEP:  intercalate - '1 2 3' -> 1-2-3
  local sep="$1" out="" e first=1
  for e in $2; do if [ "$first" = 1 ]; then out="$e"; first=0; else out+="$sep$e"; fi; done
  printf '%s' "$out"
}
zipwith3 () {                             # element-wise combine THREE lists with a ternary F (len = shortest)
  local f res="" i cf; f="$1"; cf=$(as_fn3 "$f")
  local -a A B C; read -ra A <<< "$2"; read -ra B <<< "$3"; read -ra C <<< "$4"
  local n=${#A[@]}; [ ${#B[@]} -lt "$n" ] && n=${#B[@]}; [ ${#C[@]} -lt "$n" ] && n=${#C[@]}
  for ((i=0; i<n; i++)); do res+=" $(apply3 "$cf" "${A[i]}" "${B[i]}" "${C[i]}")"; done
  echo "${res# }"
}
