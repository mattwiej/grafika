#+feature dynamic-literals
package main
import "core:fmt"
import "core:math"
import "core:slice"

FilterType :: enum {
	Average, // Wygładzanie
	Sharpen, // Wyostrzanie
	Sobel, // Wykrywanie krawędzi
	Median, // Odszumianie
	Gaussian, // Rozmycie
	Custom,
}
Kernel :: struct {
	weights: [dynamic]f32,
	size:    int, // Np. 3 dla 3x3, 5 dla 5x5
}

ApplyFilter :: proc(
	img: ^ImageBuffer_models,
	type: FilterType,
	sigma: f32 = 1.0, // Tylko dla Gaussa
	custom_kernel: Kernel = {}, // Tylko dla Custom
) {
	// Rozpakowanie unii (u8 vs u16)
	switch data in &img.maxVal {

	// --- Wersja dla u8 ---
	case [dynamic]u8:
		process_filter_u8(img, data, type, sigma, custom_kernel)

	// --- Wersja dla u16 (można analogicznie skopiować logikę) ---
	case [dynamic]u16:
		// process_filter_u16(...) - analogicznie, pomijam dla czytelności
		fmt.println("Obsługa u16 wymaga analogicznej funkcji jak u8")
	}
}

process_filter_u8 :: proc(
	img: ^ImageBuffer_models,
	data: [dynamic]u8,
	type: FilterType,
	sigma: f32,
	user_kernel: Kernel,
) {
	w := int(img.width)
	h := int(img.height)

	// Autodetekcja kanałów (1 = Gray, 3 = RGB, 4 = RGBA)
	channels := len(data) / (w * h)

	switch type {

	// --- GRUPA 1: Standardowe Sploty ---
	case .Average:
		k := generate_box_blur(3)
		defer delete(k.weights)
		apply_convolution_generic(w, h, channels, data, k)

	case .Sharpen:
		// Klasyczny kernel wyostrzający
		weights := [dynamic]f32{0, -1, 0, -1, 5, -1, 0, -1, 0}
		k := Kernel {
			weights = weights,
			size    = 3,
		}
		defer delete(weights) // Odin wymaga zwolnienia dynamic array
		apply_convolution_generic(w, h, channels, data, k)

	case .Custom:
		// Splot maski dowolnego rozmiaru (Twoje wymaganie nr 6)
		apply_convolution_generic(w, h, channels, data, user_kernel)

	case .Gaussian:
		// Generowanie maski na podstawie Sigmy
		k := generate_gaussian_kernel(sigma)
		defer delete(k.weights)
		apply_convolution_generic(w, h, channels, data, k)

	// --- GRUPA 2: Medianowy ---
	case .Median:
		apply_median_filter(w, h, channels, data)

	// --- GRUPA 3: Sobel ---
	case .Sobel:
		apply_sobel_filter(w, h, channels, data)
	}
}


apply_convolution_generic :: proc(w, h, channels: int, data: [dynamic]u8, k: Kernel) {
	output := make([]u8, len(data))
	defer delete(output)
	copy(output[:], data[:]) // Kopiujemy tło (ważne dla brzegów)

	radius := k.size / 2

	// Pętla po pikselach (z pominięciem marginesów)
	for y := radius; y < h - radius; y += 1 {
		for x := radius; x < w - radius; x += 1 {

			// Dla każdego kanału osobno (R, G, B)
			for c := 0; c < channels; c += 1 {
				sum: f32 = 0

				// Pętla po masce
				for ky := 0; ky < k.size; ky += 1 {
					for kx := 0; kx < k.size; kx += 1 {

						img_y := y + (ky - radius)
						img_x := x + (kx - radius)

						// Obliczenie indeksu z uwzględnieniem kanałów
						idx := (img_y * w + img_x) * channels + c

						weight := k.weights[ky * k.size + kx]
						sum += f32(data[idx]) * weight
					}
				}

				target_idx := (y * w + x) * channels + c
				output[target_idx] = u8(clamp(sum, 0, 255))
			}
		}
	}
	copy(data[:], output[:])
}


apply_median_filter :: proc(w, h, channels: int, data: [dynamic]u8) {
	output := make([]u8, len(data))
	defer delete(output)
	copy(output[:], data[:])

	window_size :: 9 // 3x3
	window: [window_size]u8 // Statyczny bufor na oknie, żeby nie alokować

	for y := 1; y < h - 1; y += 1 {
		for x := 1; x < w - 1; x += 1 {
			for c := 0; c < channels; c += 1 {

				// Zbieranie sąsiadów
				idx_w := 0
				for ky := -1; ky <= 1; ky += 1 {
					for kx := -1; kx <= 1; kx += 1 {
						src_idx := ((y + ky) * w + (x + kx)) * channels + c
						window[idx_w] = data[src_idx]
						idx_w += 1
					}
				}

				// Sortowanie
				slice.sort(window[:])

				// Wybieramy środek
				target_idx := (y * w + x) * channels + c
				output[target_idx] = window[4] // 4 to środek dla 9 elementów
			}
		}
	}
	copy(data[:], output[:])
}


apply_sobel_filter :: proc(w, h, channels: int, data: [dynamic]u8) {
	output := make([]u8, len(data))
	defer delete(output)
	// Sobel zwykle zeruje brzegi, więc można wypełnić zerami, nie kopią

	// Maski Sobela
	Gx := [9]f32{-1, 0, 1, -2, 0, 2, -1, 0, 1}
	Gy := [9]f32{-1, -2, -1, 0, 0, 0, 1, 2, 1}

	for y := 1; y < h - 1; y += 1 {
		for x := 1; x < w - 1; x += 1 {
			for c := 0; c < channels; c += 1 {

				val_x: f32 = 0
				val_y: f32 = 0

				k_idx := 0
				for ky := -1; ky <= 1; ky += 1 {
					for kx := -1; kx <= 1; kx += 1 {
						src_idx := ((y + ky) * w + (x + kx)) * channels + c
						pixel := f32(data[src_idx])

						val_x += pixel * Gx[k_idx]
						val_y += pixel * Gy[k_idx]
						k_idx += 1
					}
				}

				// Magnituda gradientu
				mag := math.sqrt(val_x * val_x + val_y * val_y)

				target_idx := (y * w + x) * channels + c
				output[target_idx] = u8(clamp(mag, 0, 255))
			}
		}
	}
	copy(data[:], output[:])
}

generate_gaussian_kernel :: proc(sigma: f32) -> Kernel {
	radius := int(math.ceil(3.0 * sigma))
	size := 2 * radius + 1
	weights := make([dynamic]f32, size * size)

	sum: f32 = 0
	two_sigma_sq := 2.0 * sigma * sigma

	for y := -radius; y <= radius; y += 1 {
		for x := -radius; x <= radius; x += 1 {
			exponent := -(f32(x * x + y * y) / two_sigma_sq)
			val := math.exp(exponent)

			idx := (y + radius) * size + (x + radius)
			weights[idx] = val
			sum += val
		}
	}

	// Normalizacja
	for i := 0; i < len(weights); i += 1 {
		weights[i] /= sum
	}

	return Kernel{weights = weights, size = size}
}

generate_box_blur :: proc(size: int) -> Kernel {
	weights := make([dynamic]f32, size * size)
	val := 1.0 / f32(size * size)
	for i := 0; i < len(weights); i += 1 {
		weights[i] = val
	}
	return Kernel{weights = weights, size = size}
}
