package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

UpdateBinarizationTexture :: proc(
	dest_pixels: [dynamic]u8,
	img: ^ImageBuffer_models,
	state: ^State_models,
) {
	if state.previewTexture.id != 0 {
		rl.UnloadTexture(state.previewTexture)
	}

	temp_image := rl.Image {
		data    = raw_data(dest_pixels),
		width   = img.width,
		height  = img.height,
		mipmaps = 1,
		format  = .UNCOMPRESSED_GRAYSCALE,
	}

	state.previewTexture = rl.LoadTextureFromImage(temp_image)

	state.hasPreview = true
}
GetHistogramArray :: proc(img: ^ImageBuffer_models) -> ([256]i64, bool) {
	if img.hist == nil {return {}, false}

	if img.channelCount != 1 {return {}, false}

	h := cast(^HistogramOneChannel_models)img.hist
	return h.data, true
}
ManualBinarization :: proc(img: ^ImageBuffer_models, state: ^State_models) {

	if img.channelCount != 1 {
		return
	}

	Th := math.clamp(state.thresholdManual, 0, 255)

	switch pixel in &img.maxVal {

	case [dynamic]u8:
		temp := make([dynamic]u8, len(pixel))
		for i := 0; i < len(pixel); i += 1 {

			if pixel[i] >= u8(Th) {
				temp[i] = 255
			} else {
				temp[i] = 0
			}
		}

		UpdateBinarizationTexture(temp, img, state)


	case [dynamic]u16:
	}
}


CalculateThreshold_PercentBlack :: proc(img: ^ImageBuffer_models, percent: f32) -> int {
	hist, ok := GetHistogramArray(img)
	if !ok {return 127}

	total_pixels := i64(img.width) * i64(img.height)
	target_count := i64(f32(total_pixels) * math.clamp(percent, 0.0, 1.0))

	sum: i64 = 0
	for t := 0; t < 256; t += 1 {
		sum += hist[t]
		if sum >= target_count {
			return t
		}
	}
	return 255
}


CalculateThreshold_IterativeMean :: proc(img: ^ImageBuffer_models) -> int {
	hist, ok := GetHistogramArray(img)
	if !ok {return 127}

	// Startowy próg (np. 127 lub średnia całego obrazu)
	T := 127
	old_T := -1

	// Pętla zbieżności
	for T != old_T {
		old_T = T

		// 1. Oblicz średnią tła (poniżej T) -> mu1
		sum1: i64 = 0
		count1: i64 = 0
		for i := 0; i < T; i += 1 {
			sum1 += i64(i) * hist[i]
			count1 += hist[i]
		}
		mu1 := (count1 == 0) ? 0.0 : f32(sum1) / f32(count1)

		// 2. Oblicz średnią obiektu (powyżej lub równe T) -> mu2
		sum2: i64 = 0
		count2: i64 = 0
		for i := T; i < 256; i += 1 {
			sum2 += i64(i) * hist[i]
			count2 += hist[i]
		}
		mu2 := (count2 == 0) ? 0.0 : f32(sum2) / f32(count2)

		T = int((mu1 + mu2) / 2.0)

		if abs(T - old_T) <= 1 {break}
	}

	return T
}

CalculateThreshold_Entropy :: proc(img: ^ImageBuffer_models) -> int {
	hist, ok := GetHistogramArray(img)
	if !ok {return 127}

	total_pixels := f64(img.width * img.height)
	if total_pixels == 0 {return 127}

	// Normalizacja histogramu do prawdopodobieństw P[i]
	norm_hist: [256]f64
	for i in 0 ..< 256 {
		norm_hist[i] = f64(hist[i]) / total_pixels
	}

	max_entropy := -1.0
	best_T := 0

	// Tablice pomocnicze dla sumy prawdopodobieństw i entropii skumulowanej
	// P(t) = suma p_i od 0 do t
	// H(t) = suma -p_i * ln(p_i) od 0 do t
	P: [256]f64
	H: [256]f64

	current_P := 0.0
	current_H := 0.0

	for i in 0 ..< 256 {
		prob := norm_hist[i]
		current_P += prob
		if prob > 0 {
			current_H -= prob * math.ln(prob)
		}
		P[i] = current_P
		H[i] = current_H
	}

	// Szukamy T maksymalizującego sumę entropii
	// Total Entropy = H_black + H_white
	for t := 0; t < 255; t += 1 {
		// Prawdopodobieństwo klasy czarnej (omega0) i białej (omega1)
		w0 := P[t]
		w1 := 1.0 - w0

		if w0 == 0 || w1 == 0 {continue}

		// Entropia klasy czarnej: H0 = ln(w0) + H[t] / w0
		// (Wzór uproszczony Kapura)
		h0 := H[t] / w0 + math.ln(w0)

		// Entropia klasy białej
		h1 := (H[255] - H[t]) / w1 + math.ln(w1)

		total_ent := h0 + h1

		if total_ent > max_entropy {
			max_entropy = total_ent
			best_T = t
		}
	}

	return best_T
}

CalculateThreshold_MinError :: proc(img: ^ImageBuffer_models) -> int {
	hist, ok := GetHistogramArray(img)
	if !ok {return 127}

	total := f64(img.width * img.height)

	min_J := 1.7976931348623157e+308 // Max f64
	best_T := 127

	// Pre-kalkulacja momentów (P, mu) dla szybszego działania
	// P1(t) - suma pikseli do t
	// S1(t) - suma (i * piksele) do t
	// S2(t) - suma (i^2 * piksele) do t - potrzebne do wariancji

	// Tutaj zrobimy to w pętli dla czytelności, choć można zoptymalizować tablicami
	for t := 1; t < 255; t += 1 {
		// --- KLASA 1 (Tło) ---
		w1: f64 = 0 // Waga (Prawdopodobieństwo)
		sum1: f64 = 0
		sum_sq1: f64 = 0

		for i := 0; i <= t; i += 1 {
			val := f64(hist[i])
			w1 += val
			sum1 += f64(i) * val
			sum_sq1 += f64(i * i) * val
		}

		// --- KLASA 2 (Obiekt) ---
		w2 := total - w1
		if w1 == 0 || w2 == 0 {continue} 	// Unikamy log(0)

		// Średnie (mu)
		mu1 := sum1 / w1
		// Obliczamy drugą część histogramu przez odejmowanie od całości (optymalizacja)
		// Ale tu policzymy "na piechotę" dla bezpieczeństwa:
		sum2: f64 = 0
		sum_sq2: f64 = 0
		for i := t + 1; i < 256; i += 1 {
			val := f64(hist[i])
			sum2 += f64(i) * val
			sum_sq2 += f64(i * i) * val
		}
		mu2 := sum2 / w2

		// Wariancje (sigma^2)
		// Var = E[x^2] - (E[x])^2
		var1 := (sum_sq1 / w1) - (mu1 * mu1)
		var2 := (sum_sq2 / w2) - (mu2 * mu2)

		// Zabezpieczenie przed sigma = 0 (logarytm wybucha)
		if var1 < 0.5 {var1 = 0.5}
		if var2 < 0.5 {var2 = 0.5}

		sigma1 := math.sqrt(var1)
		sigma2 := math.sqrt(var2)

		// Funkcja Kryterialna Kittlera-Illingwortha
		// J(T) = 1 + 2*(P1*ln(s1) + P2*ln(s2)) - 2*(P1*ln(P1) + P2*ln(P2))
		// Część stałą i czynniki *2 można pominąć przy szukaniu minimum

		// Wersja uproszczona często stosowana:
		// J = w1 * log(var1) + w2 * log(var2) - 2*(w1*log(w1) + w2*log(w2))

		term1 := w1 * math.ln(sigma1) + w2 * math.ln(sigma2)
		term2 := w1 * math.ln(w1 / total) + w2 * math.ln(w2 / total)

		J := 1.0 + 2.0 * (term1 - term2)

		if J < min_J {
			min_J = J
			best_T = t
		}
	}

	return best_T
}

CalculateThreshold_Fuzzy :: proc(img: ^ImageBuffer_models) -> int {
	hist, ok := GetHistogramArray(img)
	if !ok {return 127}

	// Szukamy min i max wartości jasności w obrazie, żeby zawęzić pętlę
	first_bin := 0
	last_bin := 255
	for i := 0; i < 256; i += 1 {if hist[i] > 0 {first_bin = i;break}}
	for i := 255; i >= 0; i -= 1 {if hist[i] > 0 {last_bin = i;break}}

	best_T := 127
	min_fuzziness := 1.7976931348623157e+308


	// Iterujemy po możliwych progach
	for t := first_bin; t < last_bin; t += 1 {

		// 1. Oblicz średnie dla μ0 (tło) i μ1 (obiekt)
		sum0: i64 = 0;cnt0: i64 = 0
		for i := first_bin; i <= t; i += 1 {
			sum0 += i64(i) * hist[i]
			cnt0 += hist[i]
		}
		mu0 := (cnt0 == 0) ? f64(t) : f64(sum0) / f64(cnt0)

		sum1: i64 = 0;cnt1: i64 = 0
		for i := t + 1; i <= last_bin; i += 1 {
			sum1 += i64(i) * hist[i]
			cnt1 += hist[i]
		}
		mu1 := (cnt1 == 0) ? f64(t) : f64(sum1) / f64(cnt1)

		// 2. Oblicz Fuzziness (Entropy) dla tego progu T
		// Wzór Huanga: E(T) = (-1/N) * sum [ S(miu_x) * h(x) ]
		// Gdzie S(u) = -u*ln(u) - (1-u)*ln(1-u) (Shannon)
		// Funkcja przynależności miu_x zależy od odległości od średniej (mu0 lub mu1)

		entropy_sum: f64 = 0

		for i := first_bin; i <= last_bin; i += 1 {
			val := f64(i)
			count := f64(hist[i])
			if count == 0 {continue}

			membership: f64 = 0
			C: f64 = 0 // Stała normalizująca (rozpiętość)

			if i <= t {
				// Tło
				C = f64(last_bin - first_bin)
				membership = 1.0 / (1.0 + math.abs(val - mu0) / C)
			} else {
				// Obiekt
				C = f64(last_bin - first_bin)
				membership = 1.0 / (1.0 + math.abs(val - mu1) / C)
			}

			// Shannon Entropy dla membership function
			// unikamy log(0) i log(1)
			mu := membership
			if mu < 0.0001 {mu = 0.0001}
			if mu > 0.9999 {mu = 0.9999}

			term := -mu * math.ln(mu) - (1.0 - mu) * math.ln(1.0 - mu)
			entropy_sum += term * count
		}

		if entropy_sum < min_fuzziness {
			min_fuzziness = entropy_sum
			best_T = t
		}
	}

	return best_T
}

ApplyAutoBinarization :: proc(state: ^State_models) {
	img := &state.currentImage

	// Upewnij się, że histogram jest policzony!
	if img.hist == nil {
		CreateHistogram(state, img)
	}

	calculated_T: int = 127

	switch state.selectedMethod {
	case .None:
		return
	case .Manual:
		// Dla manuala bierzemy z suwaka
		calculated_T = state.thresholdManual

	case .PercentBlack:
		// percent w state to np. 0.5
		calculated_T = CalculateThreshold_PercentBlack(img, state.thresholdPercent)

	case .MeanIterative:
		calculated_T = CalculateThreshold_IterativeMean(img)

	case .Entropy:
		calculated_T = CalculateThreshold_Entropy(img)

	case .MinError:
		calculated_T = CalculateThreshold_MinError(img)

	case .FuzzyMinError:
		calculated_T = CalculateThreshold_Fuzzy(img)
	}

	// 1. Zaktualizuj UI (żeby suwak wskoczył na wyliczoną pozycję)
	state.thresholdManual = calculated_T
	fmt.printfln("Auto-Threshold Calculated: %d (Method: %v)", calculated_T, state.selectedMethod)

	// 2. Wykonaj binaryzację (stworzenie podglądu)
	// UWAGA: ManualBinarization w Twoim kodzie bierze próg ze state.thresholdManual,
	// więc wystarczy, że zaktualizowaliśmy go linijkę wyżej.
	ManualBinarization(img, state)
}
