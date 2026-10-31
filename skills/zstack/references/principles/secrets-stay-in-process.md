# secrets-stay-in-process

**Rule:** Never read, print or paste a credential file or secret value; let the process that needs a secret read it itself.

## Why

Anything an agent reads can end up in a transcript, a log or a PR. A worker that printed one service key
forced a rotation, and an audit that dumped unrelated credential pairs froze production work while they
were replaced. Secrets read inside the process that uses them never pass through the conversation at
all, so there is nothing to leak.

## Checks

- No step opens, cats, greps or prints a credential file, env file with secrets, or key store.
- Scripts take secrets from the environment or a secret store at run time and never echo them.
- Local runs that boot the app do so with cloud credentials unset or pointed at a sandbox.
- A suspected leak is reported at once, with a recommendation to rotate, and nothing is pasted to prove it.
