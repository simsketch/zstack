# investigate

**Use when:** the goal is a read-only question, such as how X works, why Y exists, where Z is decided, or
what a change would touch. No code changes are expected.

## Inputs

- The question, in the asker's words.
- Any starting point they named: a file, a screen, an endpoint, an error message, a ticket.
- What the answer is for (a decision, a plan, a ticket), so the depth fits the purpose.

## Steps

1. Restate the question in one line and say what a complete answer contains (for example "the call path
   from the button to the database write, with file and line for each hop").
2. List the places the answer could live: code, tests, docs, config, commit history, PR discussion.
3. Search from the most specific clue outward: exact strings and symbols first, then callers and callees,
   then `git log -S <string>` or `git log -L` for why a line exists.
4. Read the code you cite. A search hit you have not opened is a lead, and stays out of the answer.
5. For any number in the answer (counts, sizes, timings), run the query or command that produces it and
   keep the command next to the number; otherwise mark the number unverified.
6. Write the answer: the direct reply first, then the supporting chain with a `path:line` citation for
   every claim, then open questions you could not settle and how to settle them.
7. Leave the working tree as you found it: `git status --porcelain` shows nothing you created.

## Done when

The answer replies to the question as asked, every claim carries a `path:line` or command citation, open
questions are listed separately, and no file in the repo changed.

## Principles

- [`evidence-before-the-word`](../references/principles/evidence-before-the-word.md): claims about how the
  system behaves cite the code or output that shows it.
- [`numbers-from-tested-queries`](../references/principles/numbers-from-tested-queries.md): every number
  comes with the command that produced it, or is marked unverified.
- [`ask-with-options`](../references/principles/ask-with-options.md): when the code cannot settle a point,
  the question goes to the human with the candidate answers and a best guess.
- [`name-what-changed`](../references/principles/name-what-changed.md): the reply names which principles
  shaped it.

## Preferred shape

Inline for a question about one area. One subagent when the search is wide enough to flood the session's
context; spawn a background subagent in its own worktree with a read-only brief and ask for citations back.
