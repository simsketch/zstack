# human-busy

**Use when:** the human says they are unavailable for a while ("I'm testing for the next two hours",
"in meetings until three"), or two questions have gone unanswered for 30 minutes. Work continues; questions
wait on one page.

## Inputs

- How long the human expects to be away, if they said.
- The work in flight: playbooks, lanes, open questions.
- `.git/zstack/decisions.md` (created from `<zstack dir>/templates/decision-page.md` if missing) and `notify_cmd=` in
  `.git/zstack/config`.

## Steps

1. Say in one line that human-busy mode is on, and until when if known.
2. Move every open question to `.git/zstack/decisions.md`, one entry each from `<zstack dir>/templates/decision-page.md`:
   question, options, recommendation, what it blocks, the default and the time it applies, status `open`.
3. Sort each question. A question in the protected list (product behavior, scope, money, data deletion,
   security, production, disputes) waits for the human. Any other question with a reversible default goes
   ahead on the recommendation, with status `revisit`.
4. Tell every lane to switch to work that does not depend on an open entry. A lane with nothing left
   that is free of open questions works on its own open PRs (`babysit-pr`) before it goes idle.
5. Move tickets that need hands-on testing to `manual-verify`, and leave them to `manual-test-checklist`
   instead of blocking on them.
6. Send the human one short message when the decision page changes (through `notify_cmd` in
   `.git/zstack/config` when it is set, else through zstack-fleet's `notify.sh` when fleet is installed),
   with the count of open entries and the path. One message per change of the page, never one per question.
7. At each stated default time, apply the default for non-protected entries and mark them `revisit`.
8. When the human answers, apply each answer, reverse any `revisit` default the answer contradicts (as its
   own commit), mark the entry `answered`, and report what changed because of the answers.
9. Leave the mode when the page has no `open` entries or the human says they are back.

## Done when

Every question asked during the mode is on the decision page with a status of `answered`, `revisit` or
`open`; no protected question was decided by default; contradicted defaults are reversed; and the human
has a report of what changed.

## Principles

- [`spend-attention-carefully`](../references/principles/spend-attention-carefully.md): questions batch on
  one page and lanes keep moving.
- [`ask-with-options`](../references/principles/ask-with-options.md): each entry carries options and a
  recommendation; protected topics wait.
- [`smallest-reversible-change`](../references/principles/smallest-reversible-change.md): only reversible
  defaults go ahead, each in a commit that can be reverted.
- [`name-what-changed`](../references/principles/name-what-changed.md): the closing report says which
  answers changed which work.

## Preferred shape

Whatever shape the work in flight already has. Prefer shapes that need no answers soon: one subagent or a
lane on independent tickets, with the session coordinating the decision page.
