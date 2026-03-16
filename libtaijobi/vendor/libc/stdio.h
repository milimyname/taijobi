/* Minimal stdio.h stub for SQLite on wasm32-freestanding */
#ifndef _STDIO_H
#define _STDIO_H

#include <stddef.h>
#include <stdarg.h>

typedef struct FILE FILE;

#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2
#define EOF (-1)

/* Implementations provided by libc_shim.c */
extern FILE *stderr;
extern int fprintf(FILE *f, const char *fmt, ...);
extern int printf(const char *fmt, ...);
extern int snprintf(char *buf, size_t n, const char *fmt, ...);
extern int vsnprintf(char *buf, size_t n, const char *fmt, va_list ap);

#endif /* _STDIO_H */
