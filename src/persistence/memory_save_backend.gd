class_name MemorySaveBackend
extends SaveBackend
## In-memory backend with fault injection for persistence tests.

var files := {}
var fail_writes := 0          ## number of upcoming writes to the primary snapshot that fail
var fail_path := "save.json"
var write_count := 0

func read_text(path: String) -> Variant:
	return files.get(path)

func write_atomic(path: String, text: String) -> int:
	write_count += 1
	if fail_writes > 0 and path == fail_path:
		fail_writes -= 1
		return ERR_FILE_CANT_WRITE
	files[path] = text
	return OK

func exists(path: String) -> bool:
	return files.has(path)

func copy(from: String, to: String) -> int:
	if not files.has(from):
		return ERR_FILE_NOT_FOUND
	files[to] = files[from]
	return OK

func remove(path: String) -> int:
	files.erase(path)
	return OK
