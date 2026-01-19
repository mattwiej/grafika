package main

import "core:math"

Normalize_RGB :: proc(color: RGB_models) -> RGB_models {
	col: RGB_models
	col.r = color.r / 255
	col.g = color.g / 255
	col.b = color.b / 255
	return col
}

RGB_To_CMYK :: proc(color: RGB_models) -> CMYK_models {
	tempCol: RGB_models = color
	tempCol = Normalize_RGB(tempCol)

	r, g, b: f32

	r = tempCol.r
	g = tempCol.g
	b = tempCol.b

	cmykCol: CMYK_models

	cmykCol.K = math.min((1 - r), (1 - g), (1 - b))
	if (cmykCol.K == 1) {
		cmykCol.C = 0
		cmykCol.M = 0
		cmykCol.Y = 0
		return cmykCol
	}
	div := 1 - cmykCol.K


	cmykCol.C = (1 - r - cmykCol.K) / div
	cmykCol.M = (1 - g - cmykCol.K) / div
	cmykCol.Y = (1 - b - cmykCol.K) / div

	return cmykCol


}

CMYK_To_RGB :: proc(color: CMYK_models) -> RGB_models {

	r, g, b: f32
	c, m, y, k: f32
	c = color.C
	m = color.M
	y = color.Y
	k = color.K

	r = math.round((1 - math.min(1.0, c * (1 - k) + k)) * 255)
	g = math.round((1 - math.min(1.0, m * (1 - k) + k)) * 255)
	b = math.round((1 - math.min(1.0, y * (1 - k) + k)) * 255)

	tempCol: RGB_models = {
		r = r,
		g = g,
		b = b,
	}
	return tempCol
}
