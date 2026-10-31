# data-shape-first

**Rule:** A feature starts by naming its data: the fields, their types, where they are stored and who owns them.

## Why

Most rework in features comes from discovering late that the data lives somewhere else, has a different
shape, or belongs to another service. Settling the shape and the owner first makes the UI and the
endpoints a thin layer over a decision already made, and it surfaces migrations (a solo class) before any
other code depends on them.

## Checks

- The plan lists the new or changed fields, their types and the table, document or store that holds them.
- The owner of each piece of data is named: which service writes it and which only reads it.
- Any migration is identified up front and routed as its own solo-class change.
- Validation rules for the data are written down before the UI is built.
