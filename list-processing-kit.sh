#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# LIST-PROCESSING KIT  (a small Scheme/Lisp-style toolkit over space-separated lists)
#
# A "list" is a space-separated string of atoms (the LSB-first / Scheme
# convention; atoms must not contain spaces). A "fn value" is a string of bash
# code reading its argument(s) from $1 (and $2) and echoing its result; map / fold
# / etc. also accept a bare command NAME, normalised by as_fn / as_fn2.
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
#
# DEPENDENCY: the application combinators `apply` and `apply2` (a fn value applied
# to one / two arguments). Those live in the combinator core of alt-arithmetic.sh,
# which sources this file — so the kit is available alongside the arithmetic models.
# (Sourced on its own, define apply/apply2 first.)
#
# The payoff — these reconstruct the Layer-1 word ops from the other direction:
#   map flip_bit bits      = word_not          zipwith <xor> a b = word_xor
#   foldl and true bools   = and_all            all/any (=1?)     = and_all/or_all
# ─────────────────────────────────────────────────────────────────────────────

# Normalise a function argument: a fn value (mentions $1/$2) is used as-is; a bare
# command name is wrapped so it reads its argument(s) positionally.
as_fn   () { case "$1" in *'$1'*)        printf '%s' "$1" ;; *) printf '%s "$1"' "$1" ;; esac; }
as_fn2  () { case "$1" in *'$1'*|*'$2'*) printf '%s' "$1" ;; *) printf '%s "$1" "$2"' "$1" ;; esac; }

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
