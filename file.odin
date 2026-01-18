package main

import "core:encoding/json"
import "core:fmt"
import "core:io"
import "core:os"

// Struktura pomocnicza, żeby JSON ładnie wyglądał (np. obiekt główny z polem "shapes")
SaveData :: struct {
	shapes: [dynamic]Shape,
	nextId: u32,
}

save_state_to_json :: proc(state: ^State, filepath: string) -> bool {
	// 1. Przygotuj dane
	data := SaveData {
		shapes = state.shapes,
		nextId = state.nextId,
	}

	// 2. Serializacja do JSON (pretty print dla czytelności)
	options := json.Marshal_Options {
		pretty = true,
	}
	json_data, err := json.marshal(data, options)
	if err != nil {
		fmt.println("Błąd serializacji JSON:", err)
		return false
	}
	defer delete(json_data)

	// 3. Zapis do pliku
	if write_err := os.write_entire_file(filepath, json_data); write_err {
		fmt.println("Zapisano pomyślnie do:", filepath)
		return true
	} else {
		fmt.println("Błąd zapisu pliku")
		return false
	}
}

load_state_from_json :: proc(state: ^State, filepath: string) -> bool {
	// 1. Odczyt pliku
	data_bytes, success := os.read_entire_file(filepath)
	if !success {
		fmt.println("Nie udało się otworzyć pliku:", filepath)
		return false
	}
	defer delete(data_bytes)

	// 2. Deserializacja
	temp_data: SaveData
	// Ważne: musimy zaalokować unmarshaler
	err := json.unmarshal(data_bytes, &temp_data)

	if err != nil {
		fmt.println("Błąd parsowania JSON:", err)
		return false
	}

	// 3. Nadpisanie stanu (jeśli się udało)
	// Czyścimy stare kształty
	clear(&state.shapes)
	delete(state.shapes) // zwalniamy pamięć starej tablicy

	state.shapes = temp_data.shapes
	state.nextId = temp_data.nextId
	state.selectedIdx = -1 // Reset selekcji

	fmt.println("Wczytano pomyślnie kształtów:", len(state.shapes))
	return true
}
json_value_to_struct :: proc(val: json.Value, ptr: ^$T) {
	data, err := json.marshal(val)
	if err != nil do return
	defer delete(data)
	json.unmarshal(data, ptr)
}

get_json_int :: proc(val: json.Value) -> int {
	#partial switch v in val {
	case json.Integer:
		return int(v)
	case json.Float:
		return int(v) // Konwersja z f64 na int (np. 1.0 -> 1)
	case:
		return 0
	}
}

load_shapes_detective :: proc(state: ^State, filepath: string) -> bool {
	data, success := os.read_entire_file(filepath)
	if !success {
		fmt.println("Błąd otwarcia pliku:", filepath)
		return false
	}
	defer delete(data)

	root_val, err := json.parse(data)
	if err != nil {
		fmt.println("Błąd JSON:", err)
		return false
	}
	defer json.destroy_value(root_val)

	root_obj := root_val.(json.Object)

	// 1. NextId (używamy nowego helpera)
	if val, ok := root_obj["nextId"]; ok {
		state.nextId = u32(get_json_int(val))
	}

	if shapes_val, ok := root_obj["shapes"]; ok {
		shapes_arr := shapes_val.(json.Array)
		clear(&state.shapes)

		for item in shapes_arr {
			item_obj := item.(json.Object)
			new_shape: Shape

			// 2. ID (używamy helpera)
			if id_val, has_id := item_obj["id"]; has_id {
				new_shape.id = u32(get_json_int(id_val))
			}

			// 3. COLOR (To tutaj najpewniej wywalało błąd)
			if col_val, has_col := item_obj["color"]; has_col {
				if col_arr, is_arr := col_val.(json.Array); is_arr {
					for i in 0 ..< 4 {
						if i < len(col_arr) {
							// Używamy helpera zamiast rzutowania na siłę
							new_shape.color[i] = u8(get_json_int(col_arr[i]))
						}
					}
				}
			}

			// 4. KIND (Detektyw - bez zmian, bo używa json_value_to_struct)
			if kind_val, has_kind := item_obj["kind"]; has_kind {
				kind_obj := kind_val.(json.Object)

				if _, is_circle := kind_obj["radius"]; is_circle {
					circle: CircleData
					json_value_to_struct(kind_val, &circle)
					new_shape.kind = circle

				} else if _, is_rect := kind_obj["size"]; is_rect {
					rect: RectData
					json_value_to_struct(kind_val, &rect)
					new_shape.kind = rect

				} else if _, is_line := kind_obj["end"]; is_line {
					line: LineData
					json_value_to_struct(kind_val, &line)
					new_shape.kind = line
				}
			}

			append(&state.shapes, new_shape)
		}
	}

	fmt.println("Wczytano pomyślnie:", len(state.shapes), "kształtów.")
	return true
}
