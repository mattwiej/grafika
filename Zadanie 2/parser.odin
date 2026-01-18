package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"
import rl "vendor:raylib"


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
