#+feature dynamic-literals
package main
import "core:fmt"
import "core:math"
import "core:slice"

FilterType :: enum {
	Average,
	Sharpen,
	Sobel,
	Median,
	Gaussian,
	Custom,
}
Kernel :: struct {
	weights: [dynamic]f32,
	size:    int,
}

ApplyFilter :: proc(
	img: ^ImageBuffer_models,
	type: FilterType,
	sigma: f32 = 1.0,
	custom_kernel: Kernel = {},
) {
	switch data in &img.maxVal {

	case [dynamic]u8:
		process_filter_u8(img, data, type, sigma, custom_kernel)

	case [dynamic]u16:
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

	channels := len(data) / (w * h)

	switch type {

	case .Average:
		k := generate_box_blur(3)
		defer delete(k.weights)
		apply_convolution_generic(w, h, channels, data, k)

	case .Sharpen:
		weights := [dynamic]f32{0, -1, 0, -1, 5, -1, 0, -1, 0}
		k := Kernel {
			weights = weights,
			size    = 3,
		}
		defer delete(weights)
		apply_convolution_generic(w, h, channels, data, k)

	case .Custom:
		apply_convolution_generic(w, h, channels, data, user_kernel)

	case .Gaussian:
		apply_gaussian_separable(w, h, channels, data, sigma)

	case .Median:
		apply_median_filter(w, h, channels, data)

	case .Sobel:
		apply_sobel_filter(w, h, channels, data)
	}
}


apply_convolution_generic :: proc(w, h, channels: int, data: [dynamic]u8, k: Kernel) {
	output := make([]u8, len(data))
	defer delete(output)
	copy(output[:], data[:])

	radius := k.size / 2

	for y := radius; y < h - radius; y += 1 {
		for x := radius; x < w - radius; x += 1 {

			for c := 0; c < channels; c += 1 {
				sum: f32 = 0

				for ky := 0; ky < k.size; ky += 1 {
					for kx := 0; kx < k.size; kx += 1 {

						img_y := y + (ky - radius)
						img_x := x + (kx - radius)

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

	window_size :: 9
	window: [window_size]u8

	for y := 1; y < h - 1; y += 1 {
		for x := 1; x < w - 1; x += 1 {
			for c := 0; c < channels; c += 1 {

				idx_w := 0
				for ky := -1; ky <= 1; ky += 1 {
					for kx := -1; kx <= 1; kx += 1 {
						src_idx := ((y + ky) * w + (x + kx)) * channels + c
						window[idx_w] = data[src_idx]
						idx_w += 1
					}
				}

				slice.sort(window[:])

				target_idx := (y * w + x) * channels + c
				output[target_idx] = window[4]
			}
		}
	}
	copy(data[:], output[:])
}


apply_sobel_filter :: proc(w, h, channels: int, data: [dynamic]u8) {
	output := make([]u8, len(data))
	defer delete(output)

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


Kernel1D :: struct {
	weights: [dynamic]f32,
	radius:  int,
}

apply_gaussian_separable :: proc(w, h, channels: int, data: [dynamic]u8, sigma: f32) {
	k := generate_gaussian_kernel_1d(sigma)
	defer delete(k.weights)

	temp_buffer := make([]f32, len(data))
	defer delete(temp_buffer)

	for y := 0; y < h; y += 1 {
		for x := 0; x < w; x += 1 {
			for c := 0; c < channels; c += 1 {

				sum: f32 = 0
				weight_sum: f32 = 0

				for i := -k.radius; i <= k.radius; i += 1 {
					sample_x := clamp(x + i, 0, w - 1)

					src_idx := (y * w + sample_x) * channels + c
					weight := k.weights[i + k.radius]

					sum += f32(data[src_idx]) * weight
					weight_sum += weight
				}

				dst_idx := (y * w + x) * channels + c
				temp_buffer[dst_idx] = sum / weight_sum
			}
		}
	}

	for x := 0; x < w; x += 1 {
		for y := 0; y < h; y += 1 {
			for c := 0; c < channels; c += 1 {

				sum: f32 = 0
				weight_sum: f32 = 0

				for i := -k.radius; i <= k.radius; i += 1 {
					sample_y := clamp(y + i, 0, h - 1)

					src_idx := (sample_y * w + x) * channels + c
					weight := k.weights[i + k.radius]

					sum += temp_buffer[src_idx] * weight
					weight_sum += weight
				}

				dst_idx := (y * w + x) * channels + c
				data[dst_idx] = u8(clamp(sum / weight_sum, 0, 255))
			}
		}
	}
}

generate_gaussian_kernel_1d :: proc(sigma: f32) -> Kernel1D {
	radius := int(math.ceil(3.0 * sigma))
	if radius < 1 do radius = 1

	size := 2 * radius + 1
	weights := make([dynamic]f32, size)

	sum: f32 = 0
	two_sigma_sq := 2.0 * sigma * sigma
	if two_sigma_sq == 0 do two_sigma_sq = 1.0

	for i := -radius; i <= radius; i += 1 {
		x := f32(i)
		val := math.exp(-(x * x) / two_sigma_sq)

		weights[i + radius] = val
		sum += val
	}

	for i := 0; i < size; i += 1 {
		weights[i] /= sum
	}

	return Kernel1D{weights = weights, radius = radius}
}
