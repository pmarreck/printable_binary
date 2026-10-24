#ifndef PRINTABLE_BINARY_PLATFORM_IDENTITY_H
#define PRINTABLE_BINARY_PLATFORM_IDENTITY_H

#include <stdio.h>
#include <stdlib.h>
#if defined(__COSMOPOLITAN__)
#include <libc/dce.h>
#endif

#if defined(__aarch64__) || defined(_M_ARM64)
#define PB_ARCH "arm64"
#elif defined(__x86_64__) || defined(_M_X64)
#define PB_ARCH "amd64"
#elif !defined(__EMSCRIPTEN__)
#error Unsupported PrintableBinary architecture
#endif

static void pb_print_about(const char *implementation) {
	printf("printable-binary 1.0.0 (%s) Encode bytes as printable UTF-8; ", implementation);
#if defined(__EMSCRIPTEN__)
	/* Execution PF is known by the host launcher, outside the WASM sandbox. */
	const char *execution_pf = getenv("PRINTABLE_BINARY_EXECUTION_PF");
	if (execution_pf) printf("PF=%s ", execution_pf);
	puts("target=wasm32-unknown-emscripten");
#elif defined(__COSMOPOLITAN__)
	const char *os = IsWindows() ? "mswin" : IsXnu() ? "macos" : IsLinux() ? "linux" : "unsupported";
	printf("PF=%s-" PB_ARCH " target=cosmopolitan\n", os);
#elif defined(_WIN32)
	printf("PF=mswin-" PB_ARCH);
#if defined(__MINGW32__)
	printf(" VARIANT=gnu");
#endif
	putchar('\n');
#elif defined(__APPLE__)
	puts("PF=macos-" PB_ARCH);
#elif defined(__linux__)
	printf("PF=linux-" PB_ARCH);
#if defined(__GLIBC__)
	printf(" VARIANT=gnu");
#endif
	putchar('\n');
#else
#error Unsupported PrintableBinary operating system
#endif
}

#endif
