/* Minimal string.h stub for SQLite on wasm32-freestanding */
#ifndef _STRING_H
#define _STRING_H

#include <stddef.h>

extern void *memcpy(void *dest, const void *src, size_t n);
extern void *memmove(void *dest, const void *src, size_t n);
extern void *memset(void *s, int c, size_t n);
extern int memcmp(const void *s1, const void *s2, size_t n);
extern size_t strlen(const char *s);
extern int strcmp(const char *s1, const char *s2);
extern int strncmp(const char *s1, const char *s2, size_t n);
extern char *strcpy(char *dest, const char *src);
extern char *strncpy(char *dest, const char *src, size_t n);
extern char *strcat(char *dest, const char *src);
extern char *strchr(const char *s, int c);
extern char *strrchr(const char *s, int c);
extern char *strstr(const char *haystack, const char *needle);
extern void *memchr(const void *s, int c, size_t n);
extern size_t strspn(const char *s, const char *accept);
extern size_t strcspn(const char *s, const char *reject);
extern char *strncat(char *dest, const char *src, size_t n);
extern char *strdup(const char *s);
extern int strcasecmp(const char *s1, const char *s2);
extern int strncasecmp(const char *s1, const char *s2, size_t n);

#endif /* _STRING_H */
