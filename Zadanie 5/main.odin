package main

import clay "clay-odin"
import "core:c"
import "core:fmt"
import "core:math"
import "core:time"
import rl "vendor:raylib"
//import "vendor:stb"


RecalculateChannelCount :: proc(img: ^ImageBuffer_models) {
	if img.width <= 0 || img.height <= 0 {
		img.channelCount = 0
		return
	}

	pixel_count := int(img.width) * int(img.height)

	switch data in img.maxVal {
	case [dynamic]u8:
		if pixel_count > 0 {
			img.channelCount = i32(len(data) / pixel_count)
		}

	case [dynamic]u16:
		if pixel_count > 0 {
			img.channelCount = i32(len(data) / pixel_count)
		}
	}

}

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

		div: f32 = 65535.0

		for i := 0; i < len(pixels_16); i += 1 {
			val16 := f32(pixels_16[i])
			temp_pixels_8[i] = u8((val16 * 255.0) / div)
		}

		image := rl.Image {
			data    = raw_data(temp_pixels_8),
			width   = img.width,
			height  = img.height,
			mipmaps = 1,
			format  = .UNCOMPRESSED_R8G8B8,
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

		font_size := f32(1)

		text_x := f32(mx)
		text_y := f32(my) - 0.4
		gap: f32 = font_size
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
	image: rl.Image
	my_image := state.currentImage
	camera := rl.Camera2D {
		offset   = rl.Vector2{400, 300},
		target   = rl.Vector2{f32(my_image.width) / 2, f32(my_image.height) / 2},
		rotation = 0,
		zoom     = 1.0,
	}

	for !rl.WindowShouldClose() {


		defer free_all(context.temp_allocator)


		if state.loadNewTexture {
			fmt.println("--- RELOADING TEXTURE ---")

			if state.texture.id != 0 {
				rl.UnloadTexture(state.texture)
				state.texture.id = 0
			}

			img_ptr := &state.currentImage

			if img_ptr.width == 0 || img_ptr.height == 0 || img_ptr.maxVal == nil {
				fmt.println("ERROR: Cannot load texture - empty data")
				state.loadNewTexture = false
			} else {

				pixel_data: rawptr
				pixel_format: rl.PixelFormat

				switch p in img_ptr.maxVal {
				case [dynamic]u8:
					pixel_data = raw_data(p)

					if img_ptr.channelCount == 1 {
						pixel_format = .UNCOMPRESSED_GRAYSCALE
					} else {
						pixel_format = .UNCOMPRESSED_R8G8B8
					}

				case [dynamic]u16:
					pixel_data = raw_data(p)
					pixel_format = .UNCOMPRESSED_R8G8B8
				}

				image = {
					data    = pixel_data,
					width   = img_ptr.width,
					height  = img_ptr.height,
					mipmaps = 1,
					format  = pixel_format,
				}

				state.texture = rl.LoadTextureFromImage(image)

				if state.texture.id == 0 {
					fmt.println("CRITICAL ERROR: Texture failed to load to GPU!")
				} else {
					fmt.printfln(
						"Success! Texture Loaded. ID: %d, Size: %dx%d",
						state.texture.id,
						state.texture.width,
						state.texture.height,
					)
				}

				state.loadNewTexture = false
				loaded = true
			}
		}
		windowWidth = rl.GetScreenWidth()
		windowHeight = rl.GetScreenHeight()

		if (rl.IsKeyPressed(.SPACE)) {

			camera.target = rl.Vector2{f32(my_image.width) / 2, f32(my_image.height) / 2}
			camera.zoom = 50
		}
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
			rl.DrawTexture(state.texture, 0, 0, rl.WHITE)
			draw_pixel_grid(state.currentImage, camera)

			if state.hasPreview && state.selectedMethod != .None {
				//fmt.printfln("testBinaryzacji")
				//rl.DrawRectangle(0, c.int(state.currentImage.height + 10), 200, 200, rl.MAGENTA)
				rl.DrawTexture(
					state.previewTexture,
					0,
					c.int(state.currentImage.height + 10),
					rl.WHITE,
				)
			}

			rl.EndMode2D()
		}
		// UI Info
		rl.DrawText(fmt.ctprintf("Zoom: %.2fx", camera.zoom), 10, 570, 20, rl.LIGHTGRAY)
		clay_raylib_render(&renderCommands)


		if state.showModes {
			img := &state.currentImage

			if img.hist == nil {
				CreateHistogram(&state, img)
			}

			if img.channelCount == 1 {
				if rect, found := GetClayRect("Hist_Gray"); found {
					DrawHistogramChannel(img, 0, rect, rl.GRAY)
				}
			} else if img.channelCount == 3 {
				if rect, found := GetClayRect("Hist_Red"); found {
					DrawHistogramChannel(img, 0, rect, rl.RED)
				}
				if rect, found := GetClayRect("Hist_Green"); found {
					DrawHistogramChannel(img, 1, rect, rl.GREEN)
				}
				if rect, found := GetClayRect("Hist_Blue"); found {
					DrawHistogramChannel(img, 2, rect, rl.BLUE)
				}
			}
		}

		rl.EndDrawing()
	}


}


DrawHistogramChannel :: proc(
	img: ^ImageBuffer_models,
	channelIdx: int,
	rect: rl.Rectangle,
	color: rl.Color,
) {
	if img.hist == nil {return}
	data: ^[256]i64 = nil

	switch img.channelCount {
	case 1:
		h := cast(^HistogramOneChannel_models)img.hist
		if channelIdx == 0 do data = &h.data
	case 3:
		h := cast(^HistogramThreeChannels_models)img.hist
		switch channelIdx {
		case 0:
			data = &h.dataR
		case 1:
			data = &h.dataG
		case 2:
			data = &h.dataB
		}
	}
	if data == nil do return

	use_log := true

	max_val: f32 = 0

	if use_log {
		for v in data {
			log_v := math.log_f32(1.0 + f32(v), 10)
			if log_v > max_val do max_val = log_v
		}
	} else {
		for v in data {
			if f32(v) > max_val do max_val = f32(v)
		}
	}

	if max_val <= 0 {return}

	rl.DrawRectangleRec(rect, {20, 20, 20, 180})
	rl.DrawRectangleLinesEx(rect, 1, {60, 60, 60, 255})


	step_x := rect.width / 256.0

	line_thick := step_x
	if line_thick < 1.0 do line_thick = 1.0

	for i := 0; i < 256; i += 1 {
		val := data[i]
		if val == 0 do continue

		height_factor: f32
		if use_log {
			height_factor = math.log_f32(1.0 + f32(val), 10) / max_val
		} else {
			height_factor = f32(val) / max_val
		}

		barHeight := height_factor * rect.height

		x_pos := rect.x + (f32(i) * step_x) + (step_x / 2)

		start_pos := rl.Vector2{x_pos, rect.y + rect.height}
		end_pos := rl.Vector2{x_pos, rect.y + rect.height - barHeight}

		rl.DrawLineEx(start_pos, end_pos, line_thick, color)
	}
}
