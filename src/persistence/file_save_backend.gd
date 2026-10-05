class_name FileSaveBackend
extends SaveBackend
## Device storage under a root directory (default user://save).
##
## Atomic write: write `<file>.tmp`, close it, read it back and compare, then rename over the
## target. rename(2) replaces the destination atomically on Linux/Android, so a process kill at
## any point leaves the previous complete snapshot or the new one. Godot exposes no fsync, so
## durability across sudden power loss is not guaranteed; the checksum + .bak rotation in
## SaveRepository detects and recovers from a torn file in that case.

var root: String

func _init(root_dir := "user://save") -> void:
	root = root_dir
	DirAccess.make_dir_recursive_absolute(root)

func _p(path: String) -> String:
	return root.path_join(path)

func read_text(path: String) -> Variant:
	var full := _p(path)
	if not FileAccess.file_exists(full):
		return null
	var f := FileAccess.open(full, FileAccess.READ)
	if f == null:
		return null
	var txt := f.get_as_text()
	f.close()
	return txt

func write_atomic(path: String, text: String) -> int:
	var full := _p(path)
	var tmp := full + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	f.flush()
	var err := f.get_error()
	f.close()
	if err != OK:
		return err
	var check := FileAccess.get_file_as_string(tmp)
	if check != text:
		return ERR_FILE_CORRUPT
	return DirAccess.rename_absolute(tmp, full)

func exists(path: String) -> bool:
	return FileAccess.file_exists(_p(path))

func copy(from: String, to: String) -> int:
	return DirAccess.copy_absolute(_p(from), _p(to))

func remove(path: String) -> int:
	if not exists(path):
		return OK
	return DirAccess.remove_absolute(_p(path))
