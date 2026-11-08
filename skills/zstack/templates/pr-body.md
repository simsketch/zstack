## What changed

<One to three sentences on the behavior or structure that changed, and why. Link the ticket.>

## Route

Route: <playbook>[ -> <chained>], shape: <shape>, principles: <p1>, <p2>

## Principles

- <principle-name>: <what it changed in this PR, in one line>
- <principle-name>: <what it changed>

## Evidence

Head: <full head sha>
Class: <docs|tests|small-ui|feature|solo> (from <zstack dir>/scripts/classify.sh)

| Check | Exit | Tests | Clean | Recorded at |
|---|---|---|---|---|
| <name> | 0 | <count or n/a> | yes | <sha> |

Implemented: <no | yes, merge sha <sha>>
Deployed: <no | unknown | <environment>: serving sha <sha>, contains change (merge-base --is-ancestor exit 0)>
Verified: <no | <environment>: <who>, <when>, <what was checked>>

## How to test

Environment: <dev | staging | production | local>
Platform: <web | iOS | Android | API | CLI>
Screen: <screen or page name>
Endpoint: <METHOD /path, when there is no screen; keep only one of Screen or Endpoint>
Steps:
1. <first action>
2. <second action>
3. <third action>
Expected: <what the tester should see when it works>

## Assumptions

- <a product or behavior choice the request left open> - <why you chose it> (or "None.")

## Edge cases

From `<zstack dir>/references/edge-cases.md` (and `.git/zstack/edge-cases.md` when the repo has one), one line per class:

1. Stale or out-of-order state: <N/A - why | covered - test file and name | open - why, risk>
2. Partial failure mid-operation: <...>
3. Path skipped when a flag or channel is off: <...>
4. Masking and personal data: <...>
5. Check outside the lock: <...>
6. Time zone and date boundaries: <...>
7. Money and number math: <...>
8. Access by membership: <...>
9. Limits, pages and caps: <...>
10. Other clients and old versions: <...>
11. Logic that exists elsewhere: <...>

## Reused

- <existing helper, component or module used or extended, with its path> (or "Nothing to reuse." after searching; name any new shared helper and why nothing fit)

## Drive-bys

- <commit sha> drive-by: <one-line description, file> (or "None")

## Follow-ups

- <follow-up | proposed blocker | limitation>: <description, path:line, reproduction or reasoning, ticket if filed> (or "None")
