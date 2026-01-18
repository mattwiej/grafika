package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"
import rl "vendor:raylib"

LoadFile_parser_fast :: proc(path: string, state: ^State_models) -> (ImageBuffer_models, bool) {
	start_total := time.now()

	data, ok := os.read_entire_file(path)
	if !ok {
		state.errorState = .FileNotFound
		return {}, false
	}
	defer delete(data)

	duration_load := time.since(start_total)
	fmt.printfln("Ladowanie pliku z dysku: %v", duration_load)

	cursor := 0

	skip_junk :: proc(data: []u8, cursor: ^int) {
		len_data := len(data)
		for cursor^ < len_data {
			c := data[cursor^]
			switch c {
			case ' ', '\n', '\r', '\t':
				cursor^ += 1
			case '#':
				cursor^ += 1
				for cursor^ < len_data && data[cursor^] != '\n' {
					cursor^ += 1
				}
			case:
				return
			}
		}
	}

	parse_int :: proc(data: []u8, cursor: ^int) -> int {
		val := 0
		len_data := len(data)
		for cursor^ < len_data {
			c := data[cursor^]
			if c >= '0' && c <= '9' {
				val = val * 10 + int(c - '0')
				cursor^ += 1
			} else {
				break
			}
		}
		return val
	}

	// --- GŁÓWNA LOGIKA ---

	start_parse := time.now()

	// 1. Nagłówek Magic Number (P3/P6)
	skip_junk(data, &cursor)
	if cursor + 1 >= len(data) || data[cursor] != 'P' {
		return {}, false
	}

	magic_type := data[cursor + 1] // '3' lub '6'
	fmt.printfln("\n\n\n\n\nmagicType = %v", magic_type - '0')
	if magic_type != '3' && magic_type != '6' {
		state.errorState = .InvalidFormat
		return {}, false
	}
	cursor += 2

	// 2. Wymiary
	skip_junk(data, &cursor)
	width := i32(parse_int(data, &cursor))

	fmt.printfln("\n\n\n\n\nszer = %v", width)

	skip_junk(data, &cursor)
	height := i32(parse_int(data, &cursor))

	fmt.printfln("\n\n\n\n\nwys = %v", height)

	skip_junk(data, &cursor)
	fileMaxVal := parse_int(data, &cursor)
	fmt.printfln("\n\n\n\n\nfileMaxVal = %v", fileMaxVal)

	// Przygotowanie struktury wyjściowej
	rawImg := ImageBuffer_models {
		width  = width,
		height = height,
	}
	expectedSize := int(width * height * 3)

	// 3. Wczytywanie Danych (Pikseli)
	if magic_type == '3' { 	// P3 (Tekstowe)

		if fileMaxVal > 255 {
			// --- TRYB 16 BIT ---
			rawImg.maxValFlag = 16

			// Alokujemy raz, dokładnie tyle ile trzeba
			pixels := make([dynamic]u16, expectedSize)

			// Pobieramy wskaźnik do surowych danych (szybki zapis bez append)
			ptr := raw_data(pixels)

			for i := 0; i < expectedSize; i += 1 {
				skip_junk(data, &cursor)
				ptr[i] = u16(parse_int(data, &cursor))
			}
			rawImg.maxVal = pixels

		} else {
			// --- TRYB 8 BIT (Standard) ---
			rawImg.maxValFlag = 8

			pixels := make([dynamic]u8, expectedSize)
			ptr := raw_data(pixels)

			for i := 0; i < expectedSize; i += 1 {
				skip_junk(data, &cursor)
				ptr[i] = u8(parse_int(data, &cursor))
			}
			rawImg.maxVal = pixels
		}

	} else if magic_type == '6' { 	// P6 (Binarne)
		// Tutaj w przyszłości po prostu zrobisz mem.copy (będzie jeszcze szybciej)
		// Na razie zostawiam puste wg Twojego kodu
	} else {
		return {}, false
	}

	duration_parse := time.since(start_parse)
	fmt.printfln("Parsowanie (zero-copy): %v", duration_parse)

	return rawImg, true
}
LoadFile_parser :: proc(path: string, state: ^State_models) -> (ImageBuffer_models, bool) {

	start := time.now()

	it, ok := os.read_entire_file(path)
	if !ok {
		//state.errorState.FileNotFound
		return {}, false
	}

	duration := time.since(start)
	fmt.printfln("ladowanie pliku: %v", duration)


	defer delete(it)

	contetnt := string(it)

	clean_content := strings.builder_make()
	defer strings.builder_destroy(&clean_content)

	//it := contetnt

	start = time.now()

	for line in strings.split_iterator(&contetnt, "\n") {
		comment_index := strings.index(line, "#")
		if comment_index != -1 {
			strings.write_string(&clean_content, line[:comment_index]) //jak jest komentarz (#) to biore slice od początku do miejsca w kotrym pojawia się komentarz
		} else {
			strings.write_string(&clean_content, line)}

		strings.write_string(&clean_content, " ")
	}

	duration = time.since(start)
	fmt.printfln("dzielenie na wiersze i usuwanie kom: %v", duration)

	clean_text := strings.to_string(clean_content)
	fields := strings.fields(clean_text)
	defer delete(fields)


	if len(fields) < 4 {
		//state.errorState.InvalidFormat
		return {}, false
	}
	magicNumber := fields[0]
	width := i32(strconv.atoi(fields[1]))
	height := i32(strconv.atoi(fields[2]))
	maxVal := i32(strconv.atoi(fields[3]))

	expectedSize := int(width * height * 3)
	rgbTokens := fields[4:]

	if len(rgbTokens) < expectedSize {
		//state.errorState.CorruptData
		return {}, false
	}

	rawImg := ImageBuffer_models {
		width      = width,
		height     = height,
		maxVal     = maxVal > 255 ? make([dynamic]u16, 0, expectedSize) : make([dynamic]u8, 0, expectedSize),
		maxValFlag = maxVal > 255 ? 16 : 8,
	}

	switch magicNumber {
	case "P3":
		if rawImg.maxValFlag == 8 {

			start = time.now()

			for i := 0; i < expectedSize; i += 1 {
				val := u8(strconv.atoi(rgbTokens[i]))
				append(&rawImg.maxVal.([dynamic]u8), val)}

			duration = time.since(start)
			fmt.printfln("zamiana ze stringana liczbe i przypisanie do tablicy: %v", duration)


			return rawImg, true
		} else if rawImg.maxValFlag == 16 {
			for i := 0; i < expectedSize; i += 1 {
				val := u16(strconv.atoi(rgbTokens[i]))
				append(&rawImg.maxVal.([dynamic]u16), val)}
			return rawImg, true
		}
	case "P6":
	}

	return {}, false
}

PPMHeaderParser_parser :: proc() {


}

PPM3Parser_parser :: proc() {

}

PPM6Parser_parser :: proc() {

}
