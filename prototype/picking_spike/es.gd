class_name Es
extends RefCounted
## Runtime helpers called from compiled sheets.


## expressions.md §6.2: 3.0 -> "3", 2.5 -> "2.5".
## String.num() alone is not enough: it keeps one zero after the period ("3.0").
static func text(value) -> String:
	if value is float:
		if is_finite(value) and value == floorf(value) and absf(value) < 1e15:
			return str(int(value))
		return String.num(value)
	return str(value)
