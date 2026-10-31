# three-words

**Rule:** Report implemented, deployed and verified as three separate facts, each with its own evidence.

## Why

"Done" hides three different states. Code can be merged and sit undeployed for days; it can be deployed
and never exercised; it can be exercised in staging and absent from production. Keeping the words apart
lets the human see at a glance which step is missing, and it keeps a ticket from closing on the first of
the three.

## Checks

- **Implemented** names the merge sha.
- **Deployed** names the environment and how you proved the artifact there contains the commit (for
  example `git merge-base --is-ancestor <sha> <deployed-sha>`).
- **Verified** names who checked the behavior, where, and when.
- A missing word is written as "not yet" with the next step, and is never folded into another word.
