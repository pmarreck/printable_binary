// Exhaust the shared decoder using exact glyph bytes as the reverse oracle.
#define main printable_binary_cli_main
#include "../../src/printable_binary.c"
#undef main

int main(void) {
	encode_table = calloc(256, sizeof(*encode_table));
	int16_t *expected = malloc(65536 * sizeof(*expected));
	if (!encode_table || !expected) return 1;
	load_map_from_embedded();
	for (size_t pair = 0; pair < 65536; pair++) expected[pair] = -1;
	for (size_t byte = 0; byte < 256; byte++) {
		utf8_sequence_t glyph = encode_table[byte];
		if (glyph.length == 2)
			expected[((size_t)glyph.bytes[0] << 8) | glyph.bytes[1]] = (int16_t)byte;
	}
	int status = 0;
	for (size_t pair = 0; pair < 65536; pair++) {
		uint8_t input[2] = {(uint8_t)(pair >> 8), (uint8_t)pair};
		buffer_t output = decode_data(input, sizeof(input), false);
		bool correct = expected[pair] < 0
			? output.size == 2 && memcmp(output.data, input, 2) == 0
			: output.size == 1 && (uint8_t)output.data[0] == (uint8_t)expected[pair];
		buffer_free(&output);
		if (!correct) {
			fprintf(stderr, "FAIL: shared C decoder disagrees with exact mapping for %04zx\n", pair);
			status = 1;
			break;
		}
	}
	free(expected);
	free(encode_table);
	if (status == 0) puts("PASS: shared C decoder exhausts all 65,536 two-byte inputs");
	return status;
}
