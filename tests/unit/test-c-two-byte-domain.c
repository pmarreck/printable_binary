// Exhaust the shared decoder using exact glyph bytes as the reverse oracle.
#define main printable_binary_cli_main
#include "../../src/printable_binary.c"
#undef main

typedef struct { const uint8_t *input; size_t events; bool fail; } event_context_t;
static int record_event(void *opaque, const pb_decode_event_t *event) {
	event_context_t *context = opaque;
	context->events++;
	return context->fail || event->input_offset != 11 || event->output_offset != 0 ||
		event->input_length != 1 || event->output_length != 1 || event->bytes != context->input;
}

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

	// Every canonical glyph must be reachable immediately after an invalid byte.
	const uint8_t malformed[] = {0x80, 0xc0, 0xc1, 0xe0, 0xf0, 0xff};
	for (size_t prefix = 0; prefix < sizeof malformed; prefix++) {
		for (size_t byte = 0; byte < 256; byte++) {
			uint8_t input[5] = {malformed[prefix]};
			utf8_sequence_t glyph = encode_table[byte];
			memcpy(input + 1, glyph.bytes, glyph.length);
			event_context_t context = {.input = input};
			decoded_report_t report = decode_report_data(input, 1 + glyph.length, false, false, 11, record_event, &context);
			bool correct = report.error_code == 0 && report.invalid_events == 1 && report.invalid_bytes == 1 &&
				context.events == 1 && report.bytes.size == 2 && (uint8_t)report.bytes.data[0] == input[0] && (uint8_t)report.bytes.data[1] == byte;
			buffer_free(&report.bytes);
			if (!correct) { fprintf(stderr, "FAIL: C byte resynchronization prefix=%02x byte=%zu\n", input[0], byte); status = 1; }
		}
	}
	const uint8_t bad[] = {0xe0, 'A'};
	event_context_t failed = {.input = bad, .fail = true};
	decoded_report_t aborted = decode_report_data(bad, sizeof bad, false, false, 11, record_event, &failed);
	if (aborted.error_code != 2 || aborted.bytes.data != NULL) { fprintf(stderr, "FAIL: C sink failure must release output\n"); status = 1; }
	// Runtime maps can contain four-byte glyphs, unlike the current default map.
	encode_table[10] = make_utf8("💩");
	finalize_decode_entries();
	decoded_report_t custom = decode_report_data((const uint8_t *)"💩", 4, false, false, 0, NULL, NULL);
	if (custom.error_code || custom.invalid_events || custom.bytes.size != 1 || custom.bytes.data[0] != 10) {
		fprintf(stderr, "FAIL: C four-byte custom glyph\n"); status = 1;
	}
	buffer_free(&custom.bytes);
	free(expected);
	free(encode_table);
	if (status == 0) puts("PASS: shared C decoder exhausts all 65,536 two-byte inputs");
	return status;
}
