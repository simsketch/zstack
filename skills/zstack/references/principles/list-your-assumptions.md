# list-your-assumptions

**Rule:** Every product or behavior choice the request left open and you made yourself goes in the PR body under `## Assumptions`, with the choice and why; when there were none, write `None.`

## Why

An agent fed an underspecified ticket does not stop; it fills each gap with a confident guess. Each guess
is small and plausible, which is why nobody notices it until the feature ships and turns out to be the
wrong thing. A written list turns the invisible guesses into a short page a reviewer or the person who
owns the product can check in a minute, and it is the cheapest point to catch "built the wrong thing",
long before a user does.

## Checks

- The PR body has `## Assumptions`: one line per open choice as `<the choice> - <why>`, or `None.`
- Only choices the ticket, its spec or the repo's docs did not settle are listed. Technical choices with
  one right answer are left out.
- An assumption that is a product call (behavior, copy, a default, a flow, where something lives) opens the
  PR with `hold` and a question on the decision page, with the choice as the recommendation.
- A reviewer who finds a guess in the diff that the list does not name reports it as a finding.
