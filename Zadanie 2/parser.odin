package main

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"
import rl "vendor:raylib"
import stbi "vendor:stb/image"


SaveToJpeg :: proc(img: ImageBuffer_models, filepath: string, quality: int) -> bool {
	// quality: 1 (najgorsza) do 100 (najlepsza)

	// Konwersja filepath (Odin string) na C-string (wymagane przez STB)
	c_filepath := strings.clone_to_cstring(filepath)
	defer delete(c_filepath)

	// DANE DO ZAPISU
	// Musimy mieć wskaźnik do danych 8-bitowych (u8)
	data_ptr: ^u8 = nil

	// Tablica tymczasowa, jeśli trzeba będzie konwertować z 16-bit
	temp_data: [dynamic]u8
	defer if len(temp_data) > 0 {delete(temp_data)}

	if img.maxValFlag == 8 {
		// Prosta sprawa - mamy już u8
		pixels := img.maxVal.([dynamic]u8)
		data_ptr = raw_data(pixels)
	} else if img.maxValFlag == 16 {
		fmt.println("Konwersja 16-bit -> 8-bit przed zapisem do JPG...")

		pixels16 := img.maxVal.([dynamic]u16)
		count := len(pixels16)
		temp_data = make([dynamic]u8, count)

		max_val_f: f32 = 65535
		if max_val_f == 0 {max_val_f = 65535.0}

		for i := 0; i < count; i += 1 {
			val := f32(pixels16[i])
			temp_data[i] = u8((val * 255.0) / max_val_f)
		}
		data_ptr = raw_data(temp_data)
	}

	if data_ptr == nil {return false}

	// ZAPIS
	// width, height, comp (3=RGB), data, quality
	result := stbi.write_jpg(c_filepath, img.width, img.height, 3, data_ptr, i32(quality))

	return result != 0 // 0 oznacza błąd
}

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


	if len(data) > 2 && data[0] == 0xFF && data[1] == 0xD8 {
		fmt.println("Wykryto format JPEG")

		width, height, channels: i32

		raw_c_ptr := stbi.load_from_memory(
			raw_data(data),
			i32(len(data)),
			&width,
			&height,
			&channels,
			3,
		)

		if raw_c_ptr == nil {
			fmt.println("Błąd: stb_image nie poradził sobie z plikiem")
			return {}, false
		}
		defer stbi.image_free(raw_c_ptr)

		rawImg := ImageBuffer_models {
			width      = width,
			height     = height,
			maxValFlag = 8,
		}

		data_size := int(width * height * 3)

		pixels := make([dynamic]u8, data_size)

		mem.copy(raw_data(pixels), raw_c_ptr, data_size)

		rawImg.maxVal = pixels

		return rawImg, true
	}


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
		if cursor < len(data) {
			cursor += 1
		}

		if cursor >= len(data) {
			return {}, false
		}

		if fileMaxVal > 255 {
			rawImg.maxValFlag = 16

			bytes_needed := expectedSize * 2

			if cursor + bytes_needed > len(data) {
				fmt.println("Błąd P6: Plik jest za krótki dla trybu 16-bit")
				return {}, false
			}

			pixels := make([dynamic]u16, expectedSize)
			ptr := raw_data(pixels)

			//konwersja z big endian na little endian
			for i := 0; i < expectedSize; i += 1 {
				// cursor + i*2     -> Starszy bajt
				// cursor + i*2 + 1 -> Młodszy bajt

				hi := u16(data[cursor + i * 2])
				lo := u16(data[cursor + i * 2 + 1])

				ptr[i] = (hi << 8) | lo
			}
			rawImg.maxVal = pixels

		} else {
			rawImg.maxValFlag = 8

			if cursor + expectedSize > len(data) {
				fmt.println("Błąd P6: Plik jest za krótki dla trybu 8-bit")
				return {}, false
			}

			pixels := make([dynamic]u8, expectedSize)

			copy(pixels[:], data[cursor:cursor + expectedSize])

			rawImg.maxVal = pixels
		}
	} else {
		return {}, false
	}

	duration_parse := time.since(start_parse)
	fmt.printfln("Parsowanie (zero-copy): %v", duration_parse)

	return rawImg, true
}

PPMHeaderParser_parser :: proc() {


}

PPM3Parser_parser :: proc() {

}

PPM6Parser_parser :: proc() {

}
