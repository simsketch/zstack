# Edge-case checklist

The classes of defect that most often pass CI and reach users. Workers answer every class in the PR body
under `## Edge cases`; reviewers walk the same list against the diff (`walk-the-edge-classes`). A repo adds
its own classes in `.git/zstack/edge-cases.md`, numbered on from the last class here, and the PR answers
those too.

## How to answer

One line per class, by number:

- `N/A - <why, a few words>` when the change cannot hit the class ("no writes", "no dates").
- `covered - <test file and test name>` when it can, with a test that fails without the change or proves
  the guard.
- `open - <why no test, and the risk>` only when a test is impractical. On money, permissions or personal
  data an `open` line keeps the PR from merging until the human accepts it.

A class you did not think about is not N/A. If you are unsure whether it applies, it applies.

## The classes

1. **Stale or out-of-order state.** An older request, poll, snapshot, webhook or retry lands after a newer
   one and overwrites it. On a client, the response for the previous page, filter, account or tenant lands
   after the user moved on. Ask: is there a version, timestamp or current-context check at the write and
   where the result is applied?
2. **Partial failure mid-operation.** A multi-step change fails after its first step: a claim or status is
   committed and the send fails, a delete runs after a failed remote call, a side effect after commit fails
   silently. Ask: what is left behind if step 2 of 3 throws, and does a retry finish the work or repeat it?
3. **Path skipped when a flag, channel or setting is off.** Email, push or a feature flag is off and the
   code still marks the step done, or skips a check it needed. An error reply counted as success belongs
   here too. Ask: what happens with each flag and channel off, and with an error response?
4. **Masking and personal data gaps.** Redaction misses an encoding, a length, a nesting, or one of several
   copies of the same logic; data reaches logs, errors, analytics, URLs or prompts sent to a model. Ask:
   every shape of the value, and every place the same masking is implemented?
5. **Check outside the lock.** A limit, permission, ownership or uniqueness check runs outside the
   transaction or lock that does the write, or two paths take the same locks in different orders. Ask: what
   if two of these run at once? Money and permission writes need a concurrency test.
6. **Time zone and date boundaries.** The device or server time zone is used where the user's or the
   record's is meant; month ends, leap days, daylight saving, "as of" dates. Ask: which time zone, and what
   happens at 23:59 and on the first of the month?
7. **Money and number math.** Rounding, floating point, signs, partial amounts, currency and locale
   parsing. Ask: are amounts integers in the smallest unit, and are refunds, partials, splits, zero and
   negative values handled?
8. **Access by membership, not role alone.** Access is decided by a role or a default instead of the
   caller's actual membership and the record's own owner (account, tenant, organization); state meant per
   membership is shared across memberships. Ask: whose membership is checked, and who owns this record?
9. **Limits, pages and caps.** A page size, cap or window silently truncates and the code reports success
   or "none". A failure to load is shown as an empty list. Ask: what happens at the limit plus one, and is
   a failure shown as empty?
10. **Other clients and old versions.** The change lands on one client or platform only, or an installed
    older client, cached page or older API version breaks against it. Ask: does every client need the same
    change, and what does an old client send or expect?

11. **Logic that exists elsewhere.** The rule, calculation, mask, date handling, permission check, price
    or copy you changed also lives in another file, port, service or client, and only one copy changed; or
    the change adds a second copy instead of reusing the first. Ask: did you search for the other copies,
    and did you change every one or remove the extras?

## Keeping it current

`bug-class-sweep` adds a class to `.git/zstack/edge-cases.md` when its class is missing from both lists,
with one line on the bug that found it. Classes in this file change only through the zStack repo.
