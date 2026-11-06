/* CLI-only transport. Codec cores receive callbacks, never this process state. */
#ifndef PB_CLI_DIAGNOSTICS_H
#define PB_CLI_DIAGNOSTICS_H
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <stdarg.h>
#include <string.h>
#include <errno.h>
#include "printable_binary.h"

static struct {
    bool ndjson, complete, help;
    size_t warning_count, warnings_retained;
    char warnings[8][1024];
} pb_cli_diag;

/* JSON remains valid even when a diagnostic includes a malformed filename. */
static inline void pb_cli_json_string(FILE *stream, const char *text, size_t len) {
    fputc('"', stream);
    for (size_t i = 0; i < len;) {
        unsigned char byte = (unsigned char)text[i];
        if (byte == '"' || byte == '\\') { fputc('\\', stream); fputc(byte, stream); i++; }
        else if (byte < 32 || byte == 127) { fprintf(stream, "\\u%04x", byte); i++; }
        else if (byte < 128) { fputc(byte, stream); i++; }
        else {
            size_t width = byte >= 0xc2 && byte <= 0xdf ? 2 : byte >= 0xe0 && byte <= 0xef ? 3 : byte >= 0xf0 && byte <= 0xf4 ? 4 : 0;
            bool valid = width != 0 && width <= len - i;
            for (size_t j = 1; valid && j < width; j++) valid = ((unsigned char)text[i + j] & 0xc0) == 0x80;
            if (valid && ((byte == 0xe0 && (unsigned char)text[i + 1] < 0xa0) ||
                (byte == 0xed && (unsigned char)text[i + 1] >= 0xa0) ||
                (byte == 0xf0 && (unsigned char)text[i + 1] < 0x90) ||
                (byte == 0xf4 && (unsigned char)text[i + 1] >= 0x90))) valid = false;
            if (valid) { fwrite(text + i, 1, width, stream); i += width; }
            else { fprintf(stream, "\\u%04x", byte); i++; }
        }
    }
    fputc('"', stream);
}

/* Ordinary CLI log calls go through here; raw diagnostics below never recurse. */
static inline int pb_cli_fprintf(FILE *stream, const char *format, ...) {
    va_list args;
    va_start(args, format);
    if (!pb_cli_diag.ndjson || stream != stderr || pb_cli_diag.help) {
        int written = vfprintf(pb_cli_diag.help && stream == stderr ? stdout : stream, format, args);
        va_end(args);
        return written;
    }
    char buffer[1024];
    int written = vsnprintf(buffer, sizeof buffer, format, args);
    va_end(args);
    if (written < 0) return written;
    size_t length = (size_t)written < sizeof buffer ? (size_t)written : sizeof buffer - 1;
    if (strncmp(buffer, "Warning", 7) == 0) {
        pb_cli_diag.warning_count++;
        if (pb_cli_diag.warnings_retained < 8) {
            memcpy(pb_cli_diag.warnings[pb_cli_diag.warnings_retained], buffer, length + 1);
            pb_cli_diag.warnings_retained++;
        }
    } else {
        fputs("{\"type\":\"error\",\"fatal\":true,\"message\":", stderr);
        pb_cli_json_string(stderr, buffer, length);
        fputs("}\n", stderr);
    }
    return written;
}

static inline void pb_cli_perror(const char *prefix) {
    int saved = errno;
    pb_cli_fprintf(stderr, "%s: %s\n", prefix, strerror(saved));
}

static inline void pb_cli_warnings(void) {
    fputs(",\"warnings\":[", stderr);
    for (size_t i = 0; i < pb_cli_diag.warnings_retained; i++) {
        if (i) fputc(',', stderr);
        pb_cli_json_string(stderr, pb_cli_diag.warnings[i], strlen(pb_cli_diag.warnings[i]));
    }
    fprintf(stderr, "],\"warnings_omitted\":%zu", pb_cli_diag.warning_count - pb_cli_diag.warnings_retained);
}

static inline void pb_cli_incomplete(void) {
    if (pb_cli_diag.ndjson && !pb_cli_diag.complete) {
        fputs("{\"type\":\"summary\",\"complete\":false,\"invalid_events\":null,\"invalid_bytes\":null,\"input_bytes\":null,\"output_bytes\":null", stderr);
        pb_cli_warnings();
        fputs("}\n", stderr);
    }
}

static inline void pb_cli_diagnostics_init(int argc, char **argv) {
    for (int i = 1; i < argc && strcmp(argv[i], "--") != 0; i++)
        if (strcmp(argv[i], "--ndjson-stderr") == 0) pb_cli_diag.ndjson = true;
    if (pb_cli_diag.ndjson) atexit(pb_cli_incomplete);
}

static inline int pb_cli_event(void *context, const pb_decode_event_t *event) {
    FILE *stream = context;
    if (pb_cli_diag.ndjson)
        fprintf(stream, "{\"type\":\"error\",\"input_offset\":%zu,\"output_offset\":%zu,\"input_length\":%zu,\"output_length\":%zu,\"hex\":\"",
            event->input_offset, event->output_offset, event->input_length, event->output_length);
    else
        fprintf(stream, "Error: invalid encoded input input_offset=%zu output_offset=%zu input_length=%zu output_length=%zu hex=",
            event->input_offset, event->output_offset, event->input_length, event->output_length);
    const char hex[] = "0123456789abcdef";
    char buffer[512];
    for (size_t offset = 0; offset < event->input_length;) {
        size_t count = event->input_length - offset;
        if (count > sizeof buffer / 2) count = sizeof buffer / 2;
        for (size_t i = 0; i < count; i++) {
            unsigned char byte = event->bytes[offset + i];
            buffer[2 * i] = hex[byte >> 4]; buffer[2 * i + 1] = hex[byte & 15];
        }
        if (fwrite(buffer, 2, count, stream) != count) return 1;
        offset += count;
    }
    fputs(pb_cli_diag.ndjson ? "\"}\n" : "\n", stream);
    return ferror(stream) ? 1 : 0;
}

static inline int pb_cli_summary(size_t events, size_t bytes, size_t input, size_t output, double elapsed) {
    if (elapsed < 0.0005) elapsed = 0.0005;
    if (pb_cli_diag.ndjson) {
        fprintf(stderr, "{\"type\":\"summary\",\"invalid_events\":%zu,\"invalid_bytes\":%zu,\"input_bytes\":%zu,\"output_bytes\":%zu,\"complete\":true,\"elapsed_seconds\":%.9f,\"input_mbps\":%.9f",
            events, bytes, input, output, elapsed, (double)input / 1000000.0 / elapsed);
        pb_cli_warnings();
        fputs("}\n", stderr);
    } else if (events) fprintf(stderr, "Invalid input: %zu events, %zu bytes\n", events, bytes);
    if (fflush(stderr) != 0 || ferror(stderr)) return 1;
    pb_cli_diag.complete = true;
    return 0;
}
#endif
