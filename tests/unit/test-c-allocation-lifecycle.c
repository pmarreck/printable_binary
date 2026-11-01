// Record the actual standalone C kernel's malloc/calloc/realloc/free boundary.
// Bookkeeping and libc's internal allocations are deliberately outside coverage.
#define _POSIX_C_SOURCE 200809L
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct allocation {
	void *pointer;
	size_t size;
	struct allocation *next;
} allocation;

static allocation *owned;
static size_t live_bytes, peak_bytes, allocation_count;

static void remember(void *pointer, size_t size) {
	if (!pointer) return;
	allocation *record = malloc(sizeof(*record));
	if (!record) abort();
	*record = (allocation){pointer, size, owned};
	owned = record;
	live_bytes += size;
	if (live_bytes > peak_bytes) peak_bytes = live_bytes;
	allocation_count++;
}

static allocation **find_allocation(void *pointer) {
	allocation **record = &owned;
	while (*record && (*record)->pointer != pointer) record = &(*record)->next;
	if (!*record) abort(); // Unknown ownership or double free must not pass.
	return record;
}

static void *record_malloc(size_t size) {
	void *pointer = malloc(size);
	remember(pointer, size);
	return pointer;
}

static void *record_calloc(size_t count, size_t size) {
	if (size && count > SIZE_MAX / size) return NULL;
	void *pointer = calloc(count, size);
	remember(pointer, count * size);
	return pointer;
}

static void record_free(void *pointer) {
	if (!pointer) return;
	allocation **slot = find_allocation(pointer);
	allocation *record = *slot;
	*slot = record->next;
	live_bytes -= record->size;
	free(record);
	free(pointer);
}

static void *record_realloc(void *pointer, size_t size) {
	if (!pointer) return record_malloc(size);
	if (!size) { record_free(pointer); return NULL; }
	allocation *record = *find_allocation(pointer);
	void *replacement = realloc(pointer, size);
	if (!replacement) return NULL; // A failed realloc retains the old ownership.
	live_bytes -= record->size;
	live_bytes += size;
	if (live_bytes > peak_bytes) peak_bytes = live_bytes;
	allocation_count++;
	record->pointer = replacement;
	record->size = size;
	return replacement;
}

#define malloc record_malloc
#define calloc record_calloc
#define realloc record_realloc
#define free record_free
#define main printable_binary_cli_main
#include "../../src/printable_binary.c"
#undef main

static int lifecycle(const uint8_t *input, size_t len, int retain_result) {
	options_t options = {0};
	buffer_t encoded = encode_data(input, len, &options);
	size_t offset = 0;
	int correct = 1;
	for (size_t i = 0; i < len; i++) {
		utf8_sequence_t glyph = encode_table[input[i]];
		if (offset + glyph.length > encoded.size ||
			memcmp(encoded.data + offset, glyph.bytes, glyph.length)) { correct = 0; break; }
		offset += glyph.length;
	}
	correct &= offset == encoded.size;
	buffer_t decoded = decode_data((const uint8_t *)encoded.data, encoded.size, false);
	correct &= decoded.size == len && memcmp(decoded.data, input, len) == 0;
	buffer_t formatted = format_output(&encoded, 8, 10, false);
	offset = 0;
	for (size_t i = 0; i < formatted.size; i++) {
		if (strchr(" \t\r\n", (unsigned char)formatted.data[i])) continue;
		if (offset >= encoded.size || formatted.data[i] != encoded.data[offset++]) { correct = 0; break; }
	}
	correct &= offset == encoded.size;
	buffer_t hex = hexlike_encode(input, len, &options);
	bool found = false;
	buffer_t unhex = hexlike_decode((const uint8_t *)hex.data, hex.size, &found);
	correct &= unhex.size == len && memcmp(unhex.data, input, len) == 0;
	buffer_free(&unhex);
	buffer_free(&hex);
	buffer_free(&formatted);
	buffer_free(&decoded);
	if (!retain_result) buffer_free(&encoded);
	return correct;
}

int main(int argc, char **argv) {
	const int retain_result = argc == 2 && strcmp(argv[1], "--retain-result") == 0;
	const int skip_work = argc == 2 && strcmp(argv[1], "--skip-work") == 0;
	encode_table = calloc(256, sizeof(*encode_table));
	uint8_t *input = malloc(8192);
	if (!encode_table || !input) return 1;
	load_map_from_embedded();
	for (size_t i = 0; i < 8192; i++) input[i] = (uint8_t)i;
	const size_t baseline = live_bytes; // Only the explicitly owned map and input.
	const size_t sizes[] = {0, 1, 2, 255, 256, 257, 8192};
	for (size_t cycle = 0; cycle < 16; cycle++) {
		const size_t before = allocation_count;
		for (size_t i = 0; !skip_work && i < sizeof(sizes) / sizeof(sizes[0]); i++) {
			if (!lifecycle(input, sizes[i], retain_result)) {
				fputs("FAIL: C allocation lifecycle produced wrong bytes\n", stderr);
				return 1;
			}
			if (live_bytes != baseline) {
				fputs("FAIL: C allocation lifecycle retained requested bytes\n", stderr);
				return 1;
			}
		}
		if (allocation_count == before) {
			fputs("FAIL: C allocation lifecycle skipped allocating work\n", stderr);
			return 1;
		}
	}
	free(input);
	free(encode_table);
	if (live_bytes || owned) return 1;
	printf("PASS: C allocation lifecycles; %zu allocation requests, peak %zu bytes, residual 0\n", allocation_count, peak_bytes);
	return 0;
}
