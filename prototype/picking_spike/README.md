# Picking spike

Executable check of `docs/design/picking.md`: the `EsSol` runtime (§4.1) and the full
example sheet (§4.3) are extracted **from the doc itself** on every run, then tested against
the behaviour table (§5, T1–T16), the runtime part of `docs/design/expressions.md` (E1–E4)
and the example's expected behaviour (X1–X7).

This is not the stage 2 prototype; it only proves the design rules work in real Godot.

```bash
prototype/picking_spike/run.sh bin/godot.linuxbsd.editor.x86_64
```

Fails on any failed check or any engine/script error in the log.
