# numbers-from-tested-queries

**Rule:** A number you hand a human comes from a named, tested query, or it is marked unverified.

## Why

People make decisions on numbers, and a confident wrong number is worse than none. A production count
can read zero because a query joined on the wrong column, and nothing about the output looks wrong. A
named query that was tested against a known case, or a second way of counting that agrees, is what makes
a number safe to act on.

## Checks

- The number cites the query or command that produced it, saved where someone can rerun it.
- The query was checked against at least one case with a known answer, or cross-checked by a second
  method.
- Untested numbers carry the word "unverified" next to them.
- Units, time range and environment are stated with the number.
