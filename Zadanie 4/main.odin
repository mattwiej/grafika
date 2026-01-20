package main

import clay "clay-odin"
import "core:c"
import "core:fmt"
import "core:math"
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


draw_pixel_grid :: proc(img: ImageBuffer_models, camera: rl.Camera2D) {
	if camera.zoom < 5.0 {return}

	screen_w := f32(rl.GetScreenWidth())
	screen_h := f32(rl.GetScreenHeight())

	top_left := rl.GetScreenToWorld2D({0, 0}, camera)
	bottom_right := rl.GetScreenToWorld2D({screen_w, screen_h}, camera)

	start_x := int(max(0, top_left.x))
	start_y := int(max(0, top_left.y))
	end_x := int(min(f32(img.width), bottom_right.x + 1))
	end_y := int(min(f32(img.height), bottom_right.y + 1))

	for y := start_y; y < end_y; y += 1 {
		for x := start_x; x < end_x; x += 1 {
			rl.DrawRectangleLinesEx(
				{f32(x), f32(y), 1.0, 1.0},
				1.0 / camera.zoom,
				rl.Color{100, 100, 100, 100},
			)
		}
	}

	mouse_world := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
	mx := int(mouse_world.x)
	my := int(mouse_world.y)

	if mx >= 0 && mx < int(img.width) && my >= 0 && my < int(img.height) {

		rl.DrawRectangleLinesEx({f32(mx), f32(my), 1.0, 1.0}, 2.0 / camera.zoom, rl.YELLOW)

		r, g, b: int
		idx := (my * int(img.width) + mx) * 3

		is_16bit := (img.maxValFlag == 16)

		if is_16bit {
			pixels := img.maxVal.([dynamic]u16)
			if idx + 2 < len(pixels) {
				r = int(pixels[idx])
				g = int(pixels[idx + 1])
				b = int(pixels[idx + 2])
			}
		} else {
			pixels := img.maxVal.([dynamic]u8)
			if idx + 2 < len(pixels) {
				r = int(pixels[idx])
				g = int(pixels[idx + 1])
				b = int(pixels[idx + 2])
			}
		}

		text := fmt.ctprintf("R:%d G:%d B:%d", r, g, b)

		// Rozmiar czcionki niezależny od zooma (zawsze czytelny na ekranie)
		// Musimy na chwilę wyjść z "Matrixa" kamery lub przeskalować tekst
		// Opcja A: Tekst skalowany w świecie (będzie malutki przy oddaleniu, ale przyczepiony do piksela)
		font_size := f32(1) // Wielkość dopasowana do 1 piksela

		// Tło pod tekst (żeby był czytelny) - czarny prostokąt
		// Pozycja: trochę nad pikselem
		text_x := f32(mx)
		text_y := f32(my) - 0.4
		gap: f32 = font_size
		// Rysujemy wartości kolorami
		rl.DrawTextEx(
			rl.GetFontDefault(),
			fmt.ctprintf("%d", r),
			{f32(mx) + gap, f32(my) + 0.1},
			font_size,
			0.05,
			rl.RED,
		)
		rl.DrawTextEx(
			rl.GetFontDefault(),
			fmt.ctprintf("%d", g),
			{f32(mx) + gap, f32(my) + font_size},
			font_size,
			0.05,
			rl.GREEN,
		)
		rl.DrawTextEx(
			rl.GetFontDefault(),
			fmt.ctprintf("%d", b),
			{f32(mx) + gap, f32(my) + 2 * font_size},
			font_size,
			0.05,
			rl.BLUE,
		)
	}
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
	rl.SetExitKey(.KEY_NULL)

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
	state.compressionQuality = 100

	defer rl.CloseWindow()

	rl.SetTargetFPS(60)


	loaded: bool
	texture: rl.Texture2D
	my_image := state.currentImage
	camera := rl.Camera2D {
		offset   = rl.Vector2{400, 300}, // Środek ekranu (punkt skupienia)
		target   = rl.Vector2{f32(my_image.width) / 2, f32(my_image.height) / 2}, // Środek obrazka
		rotation = 0,
		zoom     = 1.0,
	}

	for !rl.WindowShouldClose() {


		defer free_all(context.temp_allocator)


		if state.loadNewTexture {
			img_ptr := state.currentImage
			if state.showGrayscale {
				// SCIEŻKA 1: Wyświetlamy bufor szarości
				fmt.println("Renderer: Loading Grayscale Mode")

				pixel_data: rawptr
				format: rl.PixelFormat

				// Sprawdzamy czy mamy dane u8 czy u16
				switch _ in img_ptr.maxVal {
				case [dynamic]u8:
					pixel_data = raw_data(state.grayScale8)
					format = .UNCOMPRESSED_GRAYSCALE
				case [dynamic]u16:
					pixel_data = raw_data(state.grayScale16)
					format = .UNCOMPRESSED_GRAYSCALE
				}

				image := rl.Image {
					data    = pixel_data,
					width   = img_ptr.width,
					height  = img_ptr.height,
					mipmaps = 1,
					format  = format,
				}
				state.showGrayscale = false
				texture = rl.LoadTextureFromImage(image)

			} else {
				texture = create_texture_from_model(state.currentImage)
			}
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
			delta = rl.Vector2Scale(delta, -1.0 / camera.zoom)
			camera.target = rl.Vector2Add(camera.target, delta)
		}

		wheel := rl.GetMouseWheelMove()
		if wheel != 0 {
			mouse_world_pos := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)

			camera.offset = rl.GetMousePosition()
			camera.target = mouse_world_pos

			scale_factor := 1.0 + (0.1 * abs(wheel))
			if wheel < 0 {scale_factor = 1.0 / scale_factor}

			camera.zoom = rl.Clamp(camera.zoom * scale_factor, 0.1, 50.0)
		}
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)

		if loaded {
			rl.BeginMode2D(camera)
			rl.DrawTexture(texture, 0, 0, rl.WHITE)
			draw_pixel_grid(state.currentImage, camera)
			rl.EndMode2D()
		}
		// UI Info
		rl.DrawText(fmt.ctprintf("Zoom: %.2fx", camera.zoom), 10, 570, 20, rl.LIGHTGRAY)
		rl.DrawText("PPM Drag: Pan | Scroll: Zoom", 10, 10, 20, rl.RAYWHITE)
		clay_raylib_render(&renderCommands)
		rl.EndDrawing()
	}


}
