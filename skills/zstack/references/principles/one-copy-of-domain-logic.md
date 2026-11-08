# one-copy-of-domain-logic

**Rule:** Domain logic lives in exactly one place. Search for an existing helper before writing one, list what you reused under `## Reused`, change every copy when logic already lives in several places, and treat a new second copy as a blocking review finding.

## Why

Domain logic is the code whose rules the business owns: business rules, money math, dates and time zones,
permissions, masking and redaction, pricing, and copy shared across clients. When it exists twice, the two
copies drift, and a bug fixed in one stays live in the other. A single masking bug ported to three
languages needs three finds and three fixes, and the third is usually found by a user. Agents make this
worse because writing a new helper is faster than finding the old one. Incidental duplication is
different: repeated test setup or a few lines of UI glue cost little, and abstracting them early adds
indirection for no gain.

## Checks

- Before adding a helper, component, constant or copy string, the author searched for one (`git grep`,
  shared packages, the other clients) and the PR's `## Reused` section names what was used or extended, or
  says why nothing fit.
- A change to logic that also lives elsewhere changes every copy, or removes the extras; edge-case class
  11 is answered.
- A reviewer reports a new second copy of domain logic as a blocker and names the existing copy.
- Incidental duplication (test setup, fixtures, UI glue) is left alone until its third repeat, which is
  abstracted.
