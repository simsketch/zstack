# count-the-living

**Rule:** A worker counts as working only if it produced output in the last 10 minutes.

## Why

A list of running workers says nothing about whether they are doing anything. In one large run, over half
the listed workers had sat on the same status line for hours while the coordinator believed capacity was
full. Counting by recent output exposes stuck workers so they can be stopped and redone, and it keeps the
coordinator from waiting on a wave that will never finish.

## Checks

- Worker counts in status reports use output written in the last 10 minutes, and say so.
- A worker with no output for 30 minutes or more is stopped and its piece redone or reassigned.
- The coordinator checks liveness on its own schedule instead of waiting for a whole wave to report.
- A worker silent for about 60 minutes loses its claims on tickets and hot files, and they are released
  for another worker.
- Busy is judged from the last few lines of a worker's output, never from anywhere in its history.
