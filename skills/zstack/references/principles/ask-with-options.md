# ask-with-options

**Rule:** Product, scope, money, data deletion, security, production and disputes go to the human with options and a recommendation; answer everything else yourself from code, docs or the human's earlier words, and cite the source.

## Why

The human's attention is the scarcest thing in the loop. Questions the code or docs can answer waste it,
and open-ended questions make the human do the thinking twice. A short list of options with a
recommendation lets them decide in seconds, and the protected list keeps the decisions that carry real
risk where they belong.

## Checks

- Each question to the human is on the protected list, and the reply says which item.
- Each question carries two to four options, a recommendation, and what is blocked until it is answered.
- Anything answered without asking cites where the answer came from (file:line, doc, or quoted message).
- Production actions, deletes and spending wait for an explicit answer, even in human-busy mode.
