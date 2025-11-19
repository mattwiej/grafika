package main

import "base:runtime"
import "core:c"
import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

// Dostosuj ścieżkę do folderu, w którym zapisałeś przesłany plik clay.odin
import clay "../clay-odin"

// ==========================================================================================
// 1. RENDERER (Dostosowany do Twojego bindingu)
// ==========================================================================================

// Funkcja konwertująca kolor z Clay ([4]f32) na Raylib (Color)
to_rl_color :: proc(c: clay.Color) -> rl.Color {
	return rl.Color{u8(c[0]), u8(c[1]), u8(c[2]), u8(c[3])}
}

measure_text :: proc "c" (
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	userData: rawptr,
) -> clay.Dimensions {
	context = runtime.default_context()

	// Konwersja StringSlice -> cstring dla Rayliba
	text_slice := slice.from_ptr(text.chars, int(text.length))
	text_str := strings.clone_from_bytes(text_slice, context.temp_allocator)
	text_c := strings.clone_to_cstring(text_str, context.temp_allocator)

	// Mierzenie tekstu (zakładamy domyślny font Rayliba)
	vec := rl.MeasureTextEx(rl.GetFontDefault(), text_c, f32(config.fontSize), 0.0)
	return {vec.x, vec.y}
}

clay_raylib_render :: proc(renderCommands: ^clay.ClayArray(clay.RenderCommand)) {
	for i in 0 ..< int(renderCommands.length) {
		cmd := clay.RenderCommandArray_Get(renderCommands, i32(i))
		bbox := cmd.boundingBox

		switch cmd.commandType {
		case .Rectangle:
			config := cmd.renderData.rectangle
			color := to_rl_color(config.backgroundColor)

			if config.cornerRadius.topLeft > 0 {
				rl.DrawRectangleRounded({bbox.x, bbox.y, bbox.width, bbox.height}, 0.5, 10, color)
			} else {
				rl.DrawRectangle(
					i32(bbox.x),
					i32(bbox.y),
					i32(bbox.width),
					i32(bbox.height),
					color,
				)
			}

		case .Text:
			config := cmd.renderData.text
			// Pobieramy tekst ze StringSlice
			text_slice := slice.from_ptr(
				config.stringContents.chars,
				int(config.stringContents.length),
			)
			text := strings.clone_from_bytes(text_slice, context.temp_allocator)
			text_c := strings.clone_to_cstring(text, context.temp_allocator)

			color := to_rl_color(config.textColor)
			rl.DrawText(text_c, i32(bbox.x), i32(bbox.y), i32(config.fontSize), color)

		case .Border:
			config := cmd.renderData.border
			color := to_rl_color(config.color)
			rl.DrawRectangleLinesEx(
				{bbox.x, bbox.y, bbox.width, bbox.height},
				f32(config.width.top),
				color,
			)

		case .ScissorStart:
			rl.BeginScissorMode(i32(bbox.x), i32(bbox.y), i32(bbox.width), i32(bbox.height))

		case .ScissorEnd:
			rl.EndScissorMode()

		case .Image, .None, .Custom:
		}
	}
}

// ==========================================================================================
// 2. LOGIKA APLIKACJI
// ==========================================================================================

ShapeType :: enum {
	Line,
	Rect,
	Circle,
}
LineData :: struct {
	start, end: [2]f32,
}
RectData :: struct {
	pos, size: [2]f32,
}
CircleData :: struct {
	center: [2]f32,
	radius: f32,
}

Shape :: struct {
	id:      u32,
	color:   [4]u8,
	variant: union {
		LineData,
		RectData,
		CircleData,
	},
}

Tool :: enum {
	Select,
	DrawLine,
	DrawRect,
	DrawCircle,
}

AppState :: struct {
	shapes:              [dynamic]Shape,
	next_id:             u32,
	selected_idx:        int,
	current_tool:        Tool,
	is_dragging:         bool,
	drag_start_mouse:    [2]f32,
	original_shape_data: Shape,
	buf_x:               [64]u8,
	buf_y:               [64]u8,
	buf_w:               [64]u8,
	buf_h:               [64]u8,
}

state: AppState

// --- Helpers Matematyczne ---
point_near_line :: proc(p, a, b: [2]f32, threshold: f32) -> bool {
	ab := b - a
	ap := p - a
	len_sq := linalg.dot(ab, ab)
	if len_sq == 0 do return linalg.length(ap) < threshold
	t := math.clamp(linalg.dot(ap, ab) / len_sq, 0, 1)
	closest := a + ab * t
	return linalg.length(p - closest) < threshold
}

get_hovered_shape :: proc(mouse: [2]f32) -> int {
	for i := len(state.shapes) - 1; i >= 0; i -= 1 {
		s := state.shapes[i]
		hit := false
		switch v in s.variant {
		case LineData:
			hit = point_near_line(mouse, v.start, v.end, 8.0)
		case RectData:
			hit = rl.CheckCollisionPointRec(mouse, {v.pos.x, v.pos.y, v.size.x, v.size.y})
		case CircleData:
			hit = rl.CheckCollisionPointCircle(mouse, v.center, v.radius)
		}
		if hit do return i
	}
	return -1
}

// --- Serializacja ---
save_to_file :: proc(filename: string) {
	data, err := json.marshal(state.shapes, {pretty = true})
	if err == nil {
		os.write_entire_file(filename, data)
		fmt.println("Zapisano do", filename)
	}
}

load_from_file :: proc(filename: string) {
	data, ok := os.read_entire_file(filename)
	if !ok do return
	defer delete(data)
	clear(&state.shapes)
	if json.unmarshal(data, &state.shapes) == nil {
		max_id: u32 = 0
		for s in state.shapes {if s.id > max_id do max_id = s.id}
		state.next_id = max_id + 1
		state.selected_idx = -1
		fmt.println("Wczytano z", filename)
	}
}

// --- Input Handling ---
update_inputs_from_buffer :: proc() {
	if state.selected_idx == -1 do return
	x := strconv.atof(strings.string_from_ptr(&state.buf_x[0], len(state.buf_x)))
	y := strconv.atof(strings.string_from_ptr(&state.buf_y[0], len(state.buf_y)))
	w := strconv.atof(strings.string_from_ptr(&state.buf_w[0], len(state.buf_w)))
	h := strconv.atof(strings.string_from_ptr(&state.buf_h[0], len(state.buf_h)))

	shape := &state.shapes[state.selected_idx]
	switch &v in shape.variant {
	case LineData:
		v.start = {f32(x), f32(y)};v.end = {f32(w), f32(h)}
	case RectData:
		v.pos = {f32(x), f32(y)};v.size = {f32(w), f32(h)}
	case CircleData:
		v.center = {f32(x), f32(y)};v.radius = f32(w)
	}
}

populate_buffers :: proc() {
	if state.selected_idx == -1 do return
	shape := state.shapes[state.selected_idx]
	x, y, w, h: f32
	switch v in shape.variant {
	case LineData:
		x, y, w, h = v.start.x, v.start.y, v.end.x, v.end.y
	case RectData:
		x, y, w, h = v.pos.x, v.pos.y, v.size.x, v.size.y
	case CircleData:
		x, y, w, h = v.center.x, v.center.y, v.radius, 0
	}
	fmt.bprintf(state.buf_x[:], "%f", x)
	fmt.bprintf(state.buf_y[:], "%f", y)
	fmt.bprintf(state.buf_w[:], "%f", w)
	fmt.bprintf(state.buf_h[:], "%f", h)
}

// ==========================================================================================
// 3. LAYOUT (Używając Twojego bindingu)
// ==========================================================================================

// Kolory zdefiniowane w bindingu to [4]c.float
COLOR_BG :: clay.Color{240, 240, 240, 255}
COLOR_BTN :: clay.Color{220, 220, 220, 255}
COLOR_BTN_ACT :: clay.Color{180, 180, 255, 255}
COLOR_BLACK :: clay.Color{0, 0, 0, 255}
COLOR_WHITE :: clay.Color{255, 255, 255, 255}
COLOR_GREEN :: clay.Color{100, 200, 100, 255}

create_layout :: proc() -> clay.ClayArray(clay.RenderCommand) {
	clay.BeginLayout()

	if clay.UI(clay.ID("Main"))(
	{
		layout = {
			sizing = {clay.SizingGrow({}), clay.SizingGrow({})},
			padding = clay.PaddingAll(10),
			childGap = 10,
		},
		backgroundColor = COLOR_BG,
	},
	) {
		// --- SIDEBAR ---
		if clay.UI(clay.ID("Sidebar"))(
		{
			layout = {
				sizing = {width = clay.SizingFixed(250), height = clay.SizingGrow({})},
				layoutDirection = .TopToBottom,
				childGap = 10,
			},
		},
		) {
			// Stały tekst -> używamy clay.Text
			clay.Text("NARZEDZIA", clay.TextConfig({fontSize = 24, textColor = COLOR_BLACK}))

			draw_tool_btn :: proc(label: string, t: Tool, id_idx: u32) {
				col := (state.current_tool == t) ? COLOR_BTN_ACT : COLOR_BTN

				if clay.UI(clay.ID("ToolBtn", id_idx))(
				{
					layout = {padding = {10, 10, 5, 5}},
					backgroundColor = col,
					cornerRadius = clay.CornerRadiusAll(5),
				},
				) {
					// Zmienny tekst -> używamy clay.TextDynamic (To jest klucz z twojego pliku!)
					clay.TextDynamic(
						label,
						clay.TextConfig({fontSize = 20, textColor = COLOR_BLACK}),
					)
				}

				if clay.PointerOver(clay.ID("ToolBtn", id_idx)) && rl.IsMouseButtonPressed(.LEFT) {
					state.current_tool = t
					state.selected_idx = -1
				}
			}

			draw_tool_btn("Wybierz (Select)", .Select, 1)
			draw_tool_btn("Linia", .DrawLine, 2)
			draw_tool_btn("Prostokat", .DrawRect, 3)
			draw_tool_btn("Okrag", .DrawCircle, 4)

			clay.Text("EDYCJA", clay.TextConfig({fontSize = 24, textColor = COLOR_BLACK}))

			if state.selected_idx != -1 {
				draw_input :: proc(lbl: string, buf: []u8, id_idx: u32) {
					clay.TextDynamic(
						lbl,
						clay.TextConfig({fontSize = 16, textColor = {50, 50, 50, 255}}),
					)

					if clay.UI(clay.ID("Input", id_idx))(
					{
						layout = {
							padding = clay.PaddingAll(5),
							sizing = {width = clay.SizingGrow({})},
						},
						backgroundColor = COLOR_WHITE,
						border = {width = clay.BorderOutside(1), color = COLOR_BLACK},
					},
					) {
						txt := strings.string_from_ptr(&buf[0], len(buf))
						// Używamy TextDynamic dla bufora
						clay.TextDynamic(
							strings.trim_right_null(txt),
							clay.TextConfig({fontSize = 20, textColor = COLOR_BLACK}),
						)
					}
				}

				draw_input("X / Start X", state.buf_x[:], 10)
				draw_input("Y / Start Y", state.buf_y[:], 11)
				draw_input("W / End X", state.buf_w[:], 12)
				draw_input("H / End Y", state.buf_h[:], 13)

				if clay.UI(clay.ID("BtnApply"))(
				{
					layout = {padding = clay.PaddingAll(10)},
					backgroundColor = COLOR_GREEN,
					cornerRadius = clay.CornerRadiusAll(5),
				},
				) {
					clay.Text(
						"Zatwierdz",
						clay.TextConfig({fontSize = 16, textColor = COLOR_BLACK}),
					)
				}
				if clay.PointerOver(clay.ID("BtnApply")) && rl.IsMouseButtonPressed(.LEFT) {
					update_inputs_from_buffer()
				}

			} else {
				clay.Text(
					"Brak wyboru",
					clay.TextConfig({fontSize = 16, textColor = {100, 100, 100, 255}}),
				)
			}

			if clay.UI(clay.ID("Spacer"))({layout = {sizing = {height = clay.SizingGrow({})}}}) {}

			if clay.UI(clay.ID("BtnSave"))(
			{
				layout = {padding = {10, 10, 5, 5}},
				backgroundColor = COLOR_BTN,
				cornerRadius = clay.CornerRadiusAll(5),
			},
			) {
				clay.Text(
					"Zapisz (JSON)",
					clay.TextConfig({fontSize = 16, textColor = COLOR_BLACK}),
				)
			}
			if clay.PointerOver(clay.ID("BtnSave")) &&
			   rl.IsMouseButtonPressed(.LEFT) {save_to_file("save.json")}

			if clay.UI(clay.ID("BtnLoad"))(
			{
				layout = {padding = {10, 10, 5, 5}},
				backgroundColor = COLOR_BTN,
				cornerRadius = clay.CornerRadiusAll(5),
			},
			) {
				clay.Text(
					"Wczytaj (JSON)",
					clay.TextConfig({fontSize = 16, textColor = COLOR_BLACK}),
				)
			}
			if clay.PointerOver(clay.ID("BtnLoad")) &&
			   rl.IsMouseButtonPressed(.LEFT) {load_from_file("save.json")}

		} // Koniec Sidebar

		if clay.UI(clay.ID("Canvas"))(
		{
			layout = {sizing = {clay.SizingGrow({}), clay.SizingGrow({})}},
			backgroundColor = COLOR_WHITE,
			border = {width = clay.BorderOutside(2), color = COLOR_BLACK},
		},
		) {}
	}

	return clay.EndLayout()
}

// ==========================================================================================
// 4. MAIN
// ==========================================================================================

main :: proc() {
	rl.InitWindow(1200, 800, "Odin + Clay Editor")
	rl.SetTargetFPS(60)
	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})

	// Inicjalizacja Clay zgodnie z Twoim bindingiem
	minMemorySize := clay.MinMemorySize()
	memory := make([^]u8, minMemorySize)
	arena := clay.CreateArenaWithCapacityAndMemory(cast(c.size_t)minMemorySize, memory)
	clay.Initialize(
		arena,
		{cast(f32)rl.GetScreenWidth(), cast(f32)rl.GetScreenHeight()},
		{handler = nil},
	)
	clay.SetMeasureTextFunction(measure_text, nil)

	state.shapes = make([dynamic]Shape)
	state.selected_idx = -1
	state.next_id = 1

	for !rl.WindowShouldClose() {
		defer free_all(context.temp_allocator)

		clay.SetLayoutDimensions({cast(f32)rl.GetScreenWidth(), cast(f32)rl.GetScreenHeight()})
		clay.SetPointerState(
			transmute(clay.Vector2)rl.GetMousePosition(),
			rl.IsMouseButtonDown(.LEFT),
		)

		mp := rl.GetMousePosition()
		pressed := rl.IsMouseButtonPressed(.LEFT)
		down := rl.IsMouseButtonDown(.LEFT)

		// Pobieranie BBox Canvasa
		canvas_data := clay.GetElementData(clay.ID("Canvas"))
		canvas_rec := rl.Rectangle {
			canvas_data.boundingBox.x,
			canvas_data.boundingBox.y,
			canvas_data.boundingBox.width,
			canvas_data.boundingBox.height,
		}

		mouse_on_canvas := rl.CheckCollisionPointRec(mp, canvas_rec)

		if mouse_on_canvas {
			if state.current_tool == .Select {
				if pressed {
					idx := get_hovered_shape(mp)
					state.selected_idx = idx
					if idx != -1 {
						state.is_dragging = true
						state.drag_start_mouse = mp
						state.original_shape_data = state.shapes[idx]
						populate_buffers()
					}
				}
				if down && state.is_dragging && state.selected_idx != -1 {
					d := mp - state.drag_start_mouse
					s := &state.shapes[state.selected_idx]
					o := state.original_shape_data
					switch &v in s.variant {
					case LineData:
						v.start =
							o.variant.(LineData).start + d;v.end = o.variant.(LineData).end + d
					case RectData:
						v.pos = o.variant.(RectData).pos + d
					case CircleData:
						v.center = o.variant.(CircleData).center + d
					}
					populate_buffers()
				} else {state.is_dragging = false}

				if rl.IsMouseButtonDown(.RIGHT) && state.selected_idx != -1 {
					s := &state.shapes[state.selected_idx]
					switch &v in s.variant {
					case LineData:
						v.end = mp
					case RectData:
						v.size = mp - v.pos
					case CircleData:
						v.radius = linalg.length(mp - v.center)
					}
					populate_buffers()
				}

			} else {
				if pressed {
					state.is_dragging = true
					state.selected_idx = -1
					ns := Shape {
						id    = state.next_id,
						color = {0, 0, 0, 255},
					}
					state.next_id += 1
					switch state.current_tool {
					case .DrawLine:
						ns.variant = LineData{mp, mp}
					case .DrawRect:
						ns.variant = RectData{mp, {0, 0}}
					case .DrawCircle:
						ns.variant = CircleData{mp, 0}
					case .Select:
					}
					append(&state.shapes, ns)
					state.selected_idx = len(state.shapes) - 1
				}

				if down && state.is_dragging && state.selected_idx != -1 {
					s := &state.shapes[len(state.shapes) - 1]
					switch &v in s.variant {
					case LineData:
						v.end = mp
					case RectData:
						v.size = mp - v.pos
					case CircleData:
						v.radius = linalg.length(mp - v.center)
					}
				}

				if rl.IsMouseButtonReleased(.LEFT) {
					state.is_dragging = false
					populate_buffers()
				}
			}
		} else {
			state.is_dragging = false
		}

		rl.BeginDrawing()
		rl.ClearBackground({255, 255, 255, 255})

		cmds := create_layout()
		clay_raylib_render(&cmds)

		rl.BeginScissorMode(
			i32(canvas_rec.x),
			i32(canvas_rec.y),
			i32(canvas_rec.width),
			i32(canvas_rec.height),
		)
		for s, i in state.shapes {
			c := (i == state.selected_idx) ? rl.RED : rl.BLACK
			switch v in s.variant {
			case LineData:
				rl.DrawLineV(v.start, v.end, c)
				if i == state.selected_idx {
					rl.DrawCircleV(v.start, 3, rl.BLUE)
					rl.DrawCircleV(v.end, 3, rl.BLUE)
				}
			case RectData:
				rl.DrawRectangleLinesEx({v.pos.x, v.pos.y, v.size.x, v.size.y}, 2, c)
			case CircleData:
				rl.DrawCircleLines(i32(v.center.x), i32(v.center.y), v.radius, c)
			}
		}
		rl.EndScissorMode()

		rl.EndDrawing()
	}
}
