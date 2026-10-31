# evidence-before-the-word

**Rule:** "Shipped", "live", "fixed" and "passing" each need machine evidence at a named commit before you write them.

## Why

These words make other people stop checking. When an agent says "fixed" because the code looks right, or
"live" because a merge happened, the human acts on a claim nobody proved, and the gap shows up later as
a support ticket. Tying each word to evidence at a specific commit (a recorded check, an artifact that
contains the sha) makes the claim cheap to verify and expensive to fake.

## Checks

- "Passing" cites a recorded check at the head sha with its test count.
- "Fixed" cites the reproduction passing at that sha.
- "Shipped" or "live" cites the environment and proof that the serving artifact contains the commit.
- Where evidence is missing, the reply uses the weaker word and says what is still unproven.

## Script the check

`scripts/zcheck.sh --verify <sha> <name>...` exits 0 only when each named check was recorded clean, at
that sha, and did not record zero tests.
