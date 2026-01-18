package main

import clay "clay-odin"
import "core:c"
import "core:fmt"
import "core:time"
import rl "vendor:raylib"
//import "vendor:stb"


create_texture_from_model :: proc(img: ImageBuffer_models) -> rl.Texture2D {

	if img.maxValFlag == 8 {
		pixels := img.maxVal.([dynamic]u8)

		image := rl.Image {
			data    = raw_data(pixels),
			width   = img.width,
			height  = img.height,
			mipmaps = 1,
			format  = .UNCOMPRESSED_R8G8B8,
		}
		return rl.LoadTextureFromImage(image)
	} else if img.maxValFlag == 16 {
		pixels_16 := img.maxVal.([dynamic]u16)

		temp_pixels_8 := make([dynamic]u8, len(pixels_16))
		defer delete(temp_pixels_8)

		// Przeliczamy 0..65535 na 0..255
		// Wzór: (wartość * 255) / maxVal

		div: f32 = 65535.0

		for i := 0; i < len(pixels_16); i += 1 {
			val16 := f32(pixels_16[i])
			// Skalowanie liniowe do 8 bitów
			temp_pixels_8[i] = u8((val16 * 255.0) / div)
		}

		image := rl.Image {
			data    = raw_data(temp_pixels_8),
			width   = img.width,
			height  = img.height,
			mipmaps = 1,
			format  = .UNCOMPRESSED_R8G8B8, // Teraz to bezpieczny format!
		}

		return rl.LoadTextureFromImage(image)
	}

	return {}
}


windowWidth: i32 = 1024
windowHeight: i32 = 768
FONT_ID_BODY_16 :: 0
FONT_ID_TITLE_56 :: 9
FONT_ID_TITLE_52 :: 1
FONT_ID_TITLE_48 :: 2
FONT_ID_TITLE_36 :: 3
FONT_ID_TITLE_32 :: 4
FONT_ID_BODY_36 :: 5
FONT_ID_BODY_30 :: 6
FONT_ID_BODY_28 :: 7
FONT_ID_BODY_24 :: 8

errorHandler :: proc "c" (errorData: clay.ErrorData) {
	if (errorData.errorType == clay.ErrorType.DuplicateId) {
		// etc
	}
}

loadFont :: proc(fontId: u16, fontSize: u16, path: cstring) {
	assign_at(
		&raylib_fonts,
		fontId,
		Raylib_Font {
			font = rl.LoadFontEx(path, cast(i32)fontSize * 2, nil, 0),
			fontId = cast(u16)fontId,
		},
	)
	rl.SetTextureFilter(raylib_fonts[fontId].font.texture, rl.TextureFilter.TRILINEAR)
}


main :: proc() {

	minMemorySize: c.size_t = cast(c.size_t)clay.MinMemorySize()
	memory := make([^]u8, minMemorySize)
	arena: clay.Arena = clay.CreateArenaWithCapacityAndMemory(minMemorySize, memory)
	clay.Initialize(
		arena,
		{cast(f32)rl.GetScreenWidth(), cast(f32)rl.GetScreenHeight()},
		{handler = errorHandler},
	)
	clay.SetMeasureTextFunction(measure_text, nil)

	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE, .MSAA_4X_HINT})
	rl.InitWindow(windowWidth, windowHeight, "Grafika_1")
	rl.SetTargetFPS(rl.GetMonitorRefreshRate(0))


	loadFont(FONT_ID_TITLE_56, 56, "resources/Calistoga-Regular.ttf")
	loadFont(FONT_ID_TITLE_52, 52, "resources/Calistoga-Regular.ttf")
	loadFont(FONT_ID_TITLE_48, 48, "resources/Calistoga-Regular.ttf")
	loadFont(FONT_ID_TITLE_36, 36, "resources/Calistoga-Regular.ttf")
	loadFont(FONT_ID_TITLE_32, 32, "resources/Calistoga-Regular.ttf")
	loadFont(FONT_ID_BODY_36, 36, "resources/Quicksand-Semibold.ttf")
	loadFont(FONT_ID_BODY_30, 30, "resources/Quicksand-Semibold.ttf")
	loadFont(FONT_ID_BODY_28, 28, "resources/Quicksand-Semibold.ttf")
	loadFont(FONT_ID_BODY_24, 24, "resources/Quicksand-Semibold.ttf")
	loadFont(FONT_ID_BODY_16, 16, "resources/Quicksand-Semibold.ttf")


	debugModeEnabled: bool = false
	state: State_models

	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	// 1. Wczytaj obraz do RAM
	//my_image, loaded := LoadFile_parser_fast("img/ppm-test-07-p3-big.ppm", &state)
	//my_image, loaded := LoadFile_parser_fast("img/ppm-test-02-p3-comments.ppm", &state)
	//my_image, loaded := LoadFile_parser_fast("img/ppm-test-04-p3-16bit.ppm", &state) //sciezka do pliku byla zla debilu
	//my_image, loaded := LoadFile_parser_fast("img/ppm-test-01-p3.ppm", &state)

	loaded: bool
	texture: rl.Texture2D
	my_image := state.currentImage
	camera := rl.Camera2D {
		offset   = rl.Vector2{400, 300}, // Środek ekranu (punkt skupienia)
		target   = rl.Vector2{f32(my_image.width) / 2, f32(my_image.height) / 2}, // Środek obrazka
		rotation = 0,
		zoom     = 1.0,
	}

	// Główna pętla renderowania
	for !rl.WindowShouldClose() {


		defer free_all(context.temp_allocator)


		if state.loadNewTexture {
			texture = create_texture_from_model(state.currentImage)
			state.loadNewTexture = false
			camera.target = rl.Vector2{f32(my_image.width) / 2, f32(my_image.height) / 2}
			camera.zoom = 50
			loaded = true
		}

		windowWidth = rl.GetScreenWidth()
		windowHeight = rl.GetScreenHeight()
		if (rl.IsKeyPressed(.D)) {
			debugModeEnabled = !debugModeEnabled
			clay.SetDebugModeEnabled(debugModeEnabled)
		}
		if (rl.IsKeyPressed(.I)) {
			state.showModes = !state.showModes
		}
		clay.SetPointerState(
			transmute(clay.Vector2)rl.GetMousePosition(),
			rl.IsMouseButtonDown(rl.MouseButton.LEFT),
		)
		clay.UpdateScrollContainers(
			false,
			transmute(clay.Vector2)rl.GetMouseWheelMoveV(),
			rl.GetFrameTime(),
		)
		clay.SetLayoutDimensions({cast(f32)rl.GetScreenWidth(), cast(f32)rl.GetScreenHeight()})
		renderCommands: clay.ClayArray(clay.RenderCommand) = createLayout(&state)
		if rl.IsMouseButtonDown(.RIGHT) {
			delta := rl.GetMouseDelta()
			delta = rl.Vector2Scale(delta, -1.0 / camera.zoom) // Skalujemy ruch odwrotnie do zoomu
			camera.target = rl.Vector2Add(camera.target, delta)
		}

		// 2. Przybliżanie (Zoom) - Kółko Myszy
		wheel := rl.GetMouseWheelMove()
		if wheel != 0 {
			// Magia zoomowania w stronę kursora:
			mouse_world_pos := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)

			camera.offset = rl.GetMousePosition()
			camera.target = mouse_world_pos

			scale_factor := 1.0 + (0.1 * abs(wheel))
			if wheel < 0 {scale_factor = 1.0 / scale_factor}

			camera.zoom = rl.Clamp(camera.zoom * scale_factor, 0.1, 50.0) // Limit zoomu 0.1x - 50x
		}
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)

		if loaded {
			rl.BeginMode2D(camera)
			rl.DrawTexture(texture, 0, 0, rl.WHITE)
			rl.EndMode2D()
		}
		// UI Info
		rl.DrawText(fmt.ctprintf("Zoom: %.2fx", camera.zoom), 10, 570, 20, rl.LIGHTGRAY)
		rl.DrawText("PPM Drag: Pan | Scroll: Zoom", 10, 10, 20, rl.RAYWHITE)
		clay_raylib_render(&renderCommands)
		rl.EndDrawing()
	}

	// Sprzątanie
	if loaded {
		rl.UnloadTexture(texture)
		delete(my_image.maxVal.([dynamic]u8))
	}

}
