# Sweep: <class name>

Date: <YYYY-MM-DD>
Original bug: <ticket or PR link, one-line symptom>
Root cause: <one sentence>

## Class

<One line naming the mistake, for example "a value read and then written with no lock between">

## Pattern

```
<the exact search command, for example: git grep -nE '<regex>' -- ':!**/vendor/**'>
```

Searched: <this repo's apps and packages, plus each repo from sweep_repos=>
Hits: <n> total, <n> confirmed, <n> suspect, <n> safe

## Hits

| Status | Location | Reason |
|---|---|---|
| confirmed | <path:line> | <one sentence on why this instance has the bug> |
| suspect | <path:line> | <one sentence on what is unclear and how to settle it> |
| safe | <path:line> | <one sentence on why this instance cannot fail> |

## Fixes

- <commit sha>: <path:line fixed, one line>

## Tickets

- <ticket link>: <path:line, impact, why it was ticketed instead of fixed here>

## Guardrail

<commit sha>: <lint rule, guard test or validator, and where it runs>
Proof: fails on the unfixed pattern (<command, exit code>), passes after the fixes (<command, exit code>).

## Why tests and QA missed it

<One paragraph on the gap that let this class through, and what now covers it.>
