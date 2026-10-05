class_name SaveBackend
extends RefCounted
## Storage port used by SaveRepository. FileSaveBackend is the device implementation;
## MemorySaveBackend gives tests deterministic fault injection.

func read_text(_path: String) -> Variant:   ## String, or null when missing/unreadable
	return null

## Must leave either the old or the new complete file at `path`, never a partial one.
func write_atomic(_path: String, _text: String) -> int:
	return ERR_UNAVAILABLE

func exists(_path: String) -> bool:
	return false

func copy(_from: String, _to: String) -> int:
	return ERR_UNAVAILABLE

func remove(_path: String) -> int:
	return ERR_UNAVAILABLE
