/* Minimal stdlib.h stub for SQLite on wasm32-freestanding */
#ifndef _STDLIB_H
#define _STDLIB_H

#include <stddef.h>

/* Implementations provided by libc_shim.c */
extern void *malloc(size_t size);
extern void free(void *ptr);
extern void *realloc(void *ptr, size_t size);
extern void abort(void) __attribute__((noreturn));
extern long strtol(const char *nptr, char **endptr, int base);
extern double strtod(const char *nptr, char **endptr);
extern int atoi(const char *nptr);
extern void qsort(void *base, size_t nmemb, size_t size,
                   int (*compar)(const void *, const void *));
extern char *getenv(const char *name);

#define RAND_MAX 32767
extern int rand(void);

#endif /* _STDLIB_H */
