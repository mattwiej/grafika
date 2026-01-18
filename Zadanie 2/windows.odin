package main

import "core:strings"
import "core:sys/windows"

open_file_dialog :: proc() -> (string, bool) {
	buf: [260]u16 // MAX_PATH
	ofn: windows.OPENFILENAMEW

	ofn.lStructSize = size_of(ofn)
	ofn.lpstrFile = raw_data(buf[:])
	ofn.nMaxFile = 260
	ofn.lpstrFilter = raw_data(windows.utf8_to_utf16("All Files\x00*.*\x00\x00"))
	ofn.nFilterIndex = 1
	ofn.Flags = windows.OFN_PATHMUSTEXIST | windows.OFN_FILEMUSTEXIST

	if windows.GetOpenFileNameW(&ofn) {
		// Konwersja UTF-16 path na string Odin
		path, _ := windows.utf16_to_utf8(buf[:], context.allocator)
		// Musimy przyciąć nulle na końcu, bo bufor jest duży
		return strings.trim_right_null(path), true
	}
	return "", false
}

save_file_dialog :: proc() -> (string, bool) {
	buf: [260]u16
	ofn: windows.OPENFILENAMEW

	ofn.lStructSize = size_of(ofn)
	ofn.lpstrFile = raw_data(buf[:])
	ofn.nMaxFile = 260
	ofn.lpstrFilter = raw_data(windows.utf8_to_utf16("All Files\x00*.*\x00\x00"))
	ofn.nFilterIndex = 1
	ofn.Flags = windows.OFN_OVERWRITEPROMPT

	if windows.GetSaveFileNameW(&ofn) {
		path, _ := windows.utf16_to_utf8(buf[:], context.allocator)
		pathStr := strings.trim_right_null(path)

		if !strings.has_suffix(pathStr, ".jpg") {
			newPath := strings.concatenate({pathStr, ".jpg"})
			return newPath, true
		}
		return pathStr, true
	}
	return "", false
}
