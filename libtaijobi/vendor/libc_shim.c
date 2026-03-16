/*
 * Minimal libc implementation for SQLite on wasm32-freestanding.
 * Only the functions SQLite actually calls at runtime.
 */
#include <stddef.h>
#include <stdint.h>

/* --- Memory functions (memcpy/memset/memmove should come from compiler-rt) --- */

void *memchr(const void *s, int c, size_t n) {
    const unsigned char *p = (const unsigned char *)s;
    for (size_t i = 0; i < n; i++) {
        if (p[i] == (unsigned char)c) return (void *)(p + i);
    }
    return NULL;
}

/* --- String functions --- */

size_t strlen(const char *s) {
    size_t len = 0;
    while (s[len]) len++;
    return len;
}

int strcmp(const char *s1, const char *s2) {
    while (*s1 && *s1 == *s2) { s1++; s2++; }
    return (unsigned char)*s1 - (unsigned char)*s2;
}

int strncmp(const char *s1, const char *s2, size_t n) {
    for (size_t i = 0; i < n; i++) {
        if (s1[i] != s2[i] || s1[i] == 0) {
            return (unsigned char)s1[i] - (unsigned char)s2[i];
        }
    }
    return 0;
}

char *strcpy(char *dest, const char *src) {
    char *d = dest;
    while ((*d++ = *src++));
    return dest;
}

char *strncpy(char *dest, const char *src, size_t n) {
    size_t i;
    for (i = 0; i < n && src[i]; i++) dest[i] = src[i];
    for (; i < n; i++) dest[i] = 0;
    return dest;
}

char *strcat(char *dest, const char *src) {
    char *d = dest + strlen(dest);
    while ((*d++ = *src++));
    return dest;
}

char *strncat(char *dest, const char *src, size_t n) {
    char *d = dest + strlen(dest);
    size_t i;
    for (i = 0; i < n && src[i]; i++) d[i] = src[i];
    d[i] = 0;
    return dest;
}

char *strchr(const char *s, int c) {
    while (*s) {
        if (*s == (char)c) return (char *)s;
        s++;
    }
    return c == 0 ? (char *)s : NULL;
}

char *strrchr(const char *s, int c) {
    const char *last = NULL;
    while (*s) {
        if (*s == (char)c) last = s;
        s++;
    }
    if (c == 0) return (char *)s;
    return (char *)last;
}

char *strstr(const char *haystack, const char *needle) {
    if (!*needle) return (char *)haystack;
    size_t nlen = strlen(needle);
    while (*haystack) {
        if (strncmp(haystack, needle, nlen) == 0) return (char *)haystack;
        haystack++;
    }
    return NULL;
}

size_t strspn(const char *s, const char *accept) {
    size_t count = 0;
    while (s[count]) {
        const char *a = accept;
        int found = 0;
        while (*a) {
            if (s[count] == *a) { found = 1; break; }
            a++;
        }
        if (!found) break;
        count++;
    }
    return count;
}

size_t strcspn(const char *s, const char *reject) {
    size_t count = 0;
    while (s[count]) {
        const char *r = reject;
        while (*r) {
            if (s[count] == *r) return count;
            r++;
        }
        count++;
    }
    return count;
}

int strcasecmp(const char *s1, const char *s2) {
    while (*s1 && *s2) {
        int c1 = *s1, c2 = *s2;
        if (c1 >= 'A' && c1 <= 'Z') c1 += 32;
        if (c2 >= 'A' && c2 <= 'Z') c2 += 32;
        if (c1 != c2) return c1 - c2;
        s1++; s2++;
    }
    return (unsigned char)*s1 - (unsigned char)*s2;
}

int strncasecmp(const char *s1, const char *s2, size_t n) {
    for (size_t i = 0; i < n && *s1 && *s2; i++) {
        int c1 = *s1, c2 = *s2;
        if (c1 >= 'A' && c1 <= 'Z') c1 += 32;
        if (c2 >= 'A' && c2 <= 'Z') c2 += 32;
        if (c1 != c2) return c1 - c2;
        s1++; s2++;
    }
    return 0;
}

/* --- stdlib functions --- */

/* First-fit heap allocator with proper free() and coalescing.
   SQLite calls malloc/free extensively — a bump allocator exhausts
   the heap after enough operations (embedding, smart categorize). */
#ifndef HEAP_SIZE
#define HEAP_SIZE (8 * 1024 * 1024)  /* 8 MB heap */
#endif
static unsigned char heap[HEAP_SIZE];
static int heap_ready = 0;

/* Each block: [BlockHeader][payload of `size` bytes] */
typedef struct {
    size_t size;   /* payload size (aligned) */
    size_t used;   /* 1 = allocated, 0 = free */
} BlockHeader;

#define ALIGN_UP(x, a) (((x) + (a) - 1) & ~((a) - 1))
#define BH_SIZE ALIGN_UP(sizeof(BlockHeader), 8)

static void heap_init(void) {
    BlockHeader *b = (BlockHeader *)heap;
    b->size = HEAP_SIZE - BH_SIZE;
    b->used = 0;
    heap_ready = 1;
}

void *malloc(size_t size) {
    if (size == 0) return NULL;
    if (!heap_ready) heap_init();

    size = ALIGN_UP(size, 8);

    unsigned char *p = heap;
    unsigned char *end = heap + HEAP_SIZE;

    while (p + BH_SIZE <= end) {
        BlockHeader *b = (BlockHeader *)p;
        if (b->size == 0) break;

        if (!b->used) {
            /* Coalesce consecutive free blocks */
            unsigned char *np = p + BH_SIZE + b->size;
            while (np + BH_SIZE <= end) {
                BlockHeader *nb = (BlockHeader *)np;
                if (nb->size == 0 || nb->used) break;
                b->size += BH_SIZE + nb->size;
                np = p + BH_SIZE + b->size;
            }

            if (b->size >= size) {
                /* Split if there's room for another block */
                if (b->size >= size + BH_SIZE + 8) {
                    BlockHeader *s = (BlockHeader *)(p + BH_SIZE + size);
                    s->size = b->size - size - BH_SIZE;
                    s->used = 0;
                    b->size = size;
                }
                b->used = 1;
                return p + BH_SIZE;
            }
        }

        p += BH_SIZE + b->size;
    }

    return NULL;
}

void free(void *ptr) {
    if (!ptr) return;
    BlockHeader *b = (BlockHeader *)((unsigned char *)ptr - BH_SIZE);
    b->used = 0;
    /* Coalescing done lazily in malloc's scan */
}

void *realloc(void *ptr, size_t size) {
    if (!ptr) return malloc(size);
    if (size == 0) { free(ptr); return NULL; }

    BlockHeader *b = (BlockHeader *)((unsigned char *)ptr - BH_SIZE);
    size_t old_size = b->size;
    if (ALIGN_UP(size, 8) <= old_size) return ptr;

    void *new_ptr = malloc(size);
    if (!new_ptr) return NULL;

    size_t copy = old_size < size ? old_size : size;
    unsigned char *dst = (unsigned char *)new_ptr;
    unsigned char *src = (unsigned char *)ptr;
    for (size_t i = 0; i < copy; i++) dst[i] = src[i];

    free(ptr);
    return new_ptr;
}

char *strdup(const char *s) {
    size_t len = strlen(s) + 1;
    char *d = (char *)malloc(len);
    if (d) {
        for (size_t i = 0; i < len; i++) d[i] = s[i];
    }
    return d;
}

_Noreturn void abort(void) {
    __builtin_trap();
}

long strtol(const char *nptr, char **endptr, int base) {
    long result = 0;
    int negative = 0;
    const char *s = nptr;

    while (*s == ' ' || *s == '\t') s++;
    if (*s == '-') { negative = 1; s++; }
    else if (*s == '+') { s++; }

    if (base == 0) {
        if (s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) { base = 16; s += 2; }
        else if (s[0] == '0') { base = 8; s++; }
        else { base = 10; }
    } else if (base == 16 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) {
        s += 2;
    }

    while (*s) {
        int digit;
        if (*s >= '0' && *s <= '9') digit = *s - '0';
        else if (*s >= 'a' && *s <= 'f') digit = *s - 'a' + 10;
        else if (*s >= 'A' && *s <= 'F') digit = *s - 'A' + 10;
        else break;
        if (digit >= base) break;
        result = result * base + digit;
        s++;
    }

    if (endptr) *endptr = (char *)s;
    return negative ? -result : result;
}

/* Minimal strtod — SQLite uses this for parsing numeric literals */
double strtod(const char *nptr, char **endptr) {
    double result = 0.0;
    int negative = 0;
    const char *s = nptr;

    while (*s == ' ' || *s == '\t') s++;
    if (*s == '-') { negative = 1; s++; }
    else if (*s == '+') { s++; }

    /* Integer part */
    while (*s >= '0' && *s <= '9') {
        result = result * 10.0 + (*s - '0');
        s++;
    }

    /* Fractional part */
    if (*s == '.') {
        s++;
        double frac = 0.1;
        while (*s >= '0' && *s <= '9') {
            result += (*s - '0') * frac;
            frac *= 0.1;
            s++;
        }
    }

    /* Exponent */
    if (*s == 'e' || *s == 'E') {
        s++;
        int exp_neg = 0;
        int exp = 0;
        if (*s == '-') { exp_neg = 1; s++; }
        else if (*s == '+') { s++; }
        while (*s >= '0' && *s <= '9') {
            exp = exp * 10 + (*s - '0');
            s++;
        }
        double mult = 1.0;
        for (int i = 0; i < exp; i++) mult *= 10.0;
        if (exp_neg) result /= mult;
        else result *= mult;
    }

    if (endptr) *endptr = (char *)s;
    return negative ? -result : result;
}

int atoi(const char *nptr) {
    return (int)strtol(nptr, NULL, 10);
}

/* qsort — SQLite uses this */
static void swap_bytes(char *a, char *b, size_t size) {
    for (size_t i = 0; i < size; i++) {
        char tmp = a[i];
        a[i] = b[i];
        b[i] = tmp;
    }
}

void qsort(void *base, size_t nmemb, size_t size,
            int (*compar)(const void *, const void *)) {
    /* Simple insertion sort — good enough for SQLite's small arrays */
    char *arr = (char *)base;
    for (size_t i = 1; i < nmemb; i++) {
        for (size_t j = i; j > 0; j--) {
            if (compar(arr + j * size, arr + (j - 1) * size) < 0) {
                swap_bytes(arr + j * size, arr + (j - 1) * size, size);
            } else {
                break;
            }
        }
    }
}

/* --- stdio stubs --- */

typedef struct { int dummy; } FILE;
static FILE _stderr_obj;
FILE *stderr = &_stderr_obj;

int fprintf(FILE *f, const char *fmt, ...) { (void)f; (void)fmt; return 0; }
int printf(const char *fmt, ...) { (void)fmt; return 0; }

/* snprintf/vsnprintf — SQLite relies on these for error messages and
   query formatting. We provide a minimal implementation. */
int vsnprintf(char *buf, size_t n, const char *fmt, __builtin_va_list ap) {
    /* Minimal vsnprintf: only handles %s, %d, %ld, %lld, %u, %lu, %llu, %x, %p, %%
       Good enough for SQLite's internal usage. */
    if (n == 0) return 0;

    size_t pos = 0;
    while (*fmt && pos + 1 < n) {
        if (*fmt != '%') {
            buf[pos++] = *fmt++;
            continue;
        }
        fmt++; /* skip % */

        /* Handle flags */
        int left = 0, zero_pad = 0;
        while (*fmt == '-' || *fmt == '0') {
            if (*fmt == '-') left = 1;
            if (*fmt == '0') zero_pad = 1;
            fmt++;
        }
        (void)left;

        /* Width */
        int width = 0;
        while (*fmt >= '0' && *fmt <= '9') {
            width = width * 10 + (*fmt - '0');
            fmt++;
        }

        /* Precision */
        int precision = -1;
        if (*fmt == '.') {
            fmt++;
            precision = 0;
            while (*fmt >= '0' && *fmt <= '9') {
                precision = precision * 10 + (*fmt - '0');
                fmt++;
            }
        }
        (void)precision;

        /* Length modifier */
        int longflag = 0;
        while (*fmt == 'l') { longflag++; fmt++; }

        switch (*fmt) {
        case 's': {
            const char *s = __builtin_va_arg(ap, const char *);
            if (!s) s = "(null)";
            while (*s && pos + 1 < n) buf[pos++] = *s++;
            break;
        }
        case 'd': case 'i': {
            long long val;
            if (longflag >= 2) val = __builtin_va_arg(ap, long long);
            else if (longflag == 1) val = __builtin_va_arg(ap, long);
            else val = __builtin_va_arg(ap, int);

            if (val < 0 && pos + 1 < n) { buf[pos++] = '-'; val = -val; }

            char tmp[20];
            int len = 0;
            if (val == 0) { tmp[len++] = '0'; }
            else { while (val > 0) { tmp[len++] = '0' + (val % 10); val /= 10; } }

            int padding = width - len;
            while (padding > 0 && pos + 1 < n) { buf[pos++] = zero_pad ? '0' : ' '; padding--; }
            for (int i = len - 1; i >= 0 && pos + 1 < n; i--) buf[pos++] = tmp[i];
            break;
        }
        case 'u': {
            unsigned long long val;
            if (longflag >= 2) val = __builtin_va_arg(ap, unsigned long long);
            else if (longflag == 1) val = __builtin_va_arg(ap, unsigned long);
            else val = __builtin_va_arg(ap, unsigned int);

            char tmp[20];
            int len = 0;
            if (val == 0) { tmp[len++] = '0'; }
            else { while (val > 0) { tmp[len++] = '0' + (val % 10); val /= 10; } }
            for (int i = len - 1; i >= 0 && pos + 1 < n; i--) buf[pos++] = tmp[i];
            break;
        }
        case 'x': case 'X': {
            unsigned long long val;
            if (longflag >= 2) val = __builtin_va_arg(ap, unsigned long long);
            else if (longflag == 1) val = __builtin_va_arg(ap, unsigned long);
            else val = __builtin_va_arg(ap, unsigned int);

            const char *hex = (*fmt == 'x') ? "0123456789abcdef" : "0123456789ABCDEF";
            char tmp[16];
            int len = 0;
            if (val == 0) { tmp[len++] = '0'; }
            else { while (val > 0) { tmp[len++] = hex[val & 0xf]; val >>= 4; } }
            for (int i = len - 1; i >= 0 && pos + 1 < n; i--) buf[pos++] = tmp[i];
            break;
        }
        case 'p': {
            void *ptr = __builtin_va_arg(ap, void *);
            unsigned long long val = (unsigned long long)(uintptr_t)ptr;
            if (pos + 2 < n) { buf[pos++] = '0'; buf[pos++] = 'x'; }
            char tmp[16];
            int len = 0;
            if (val == 0) { tmp[len++] = '0'; }
            else { while (val > 0) { tmp[len++] = "0123456789abcdef"[val & 0xf]; val >>= 4; } }
            for (int i = len - 1; i >= 0 && pos + 1 < n; i--) buf[pos++] = tmp[i];
            break;
        }
        case 'c': {
            int c = __builtin_va_arg(ap, int);
            if (pos + 1 < n) buf[pos++] = (char)c;
            break;
        }
        case '%':
            if (pos + 1 < n) buf[pos++] = '%';
            break;
        case 'f': case 'g': case 'e': {
            /* Minimal float formatting */
            double val = __builtin_va_arg(ap, double);
            if (val < 0) { if (pos + 1 < n) buf[pos++] = '-'; val = -val; }
            long long ipart = (long long)val;
            double fpart = val - ipart;

            /* Integer part */
            char tmp[20];
            int len = 0;
            if (ipart == 0) { tmp[len++] = '0'; }
            else { while (ipart > 0) { tmp[len++] = '0' + (ipart % 10); ipart /= 10; } }
            for (int i = len - 1; i >= 0 && pos + 1 < n; i--) buf[pos++] = tmp[i];

            if (pos + 1 < n) buf[pos++] = '.';

            /* Fractional: 6 digits default */
            int fdigits = (precision >= 0) ? precision : 6;
            for (int i = 0; i < fdigits && pos + 1 < n; i++) {
                fpart *= 10.0;
                int d = (int)fpart;
                buf[pos++] = '0' + d;
                fpart -= d;
            }
            break;
        }
        default:
            if (pos + 1 < n) buf[pos++] = *fmt;
            break;
        }
        fmt++;
    }
    buf[pos] = 0;
    return (int)pos;
}

int snprintf(char *buf, size_t n, const char *fmt, ...) {
    __builtin_va_list ap;
    __builtin_va_start(ap, fmt);
    int result = vsnprintf(buf, n, fmt, ap);
    __builtin_va_end(ap);
    return result;
}

/* --- math stubs --- */

double fabs(double x) { return x < 0 ? -x : x; }

double ceil(double x) {
    long long i = (long long)x;
    if (x > 0 && x != (double)i) return (double)(i + 1);
    return (double)i;
}

double floor(double x) {
    long long i = (long long)x;
    if (x < 0 && x != (double)i) return (double)(i - 1);
    return (double)i;
}

double fmod(double x, double y) {
    if (y == 0.0) return 0.0;
    return x - (long long)(x / y) * y;
}

/* sqrt via Newton's method */
double sqrt(double x) {
    if (x < 0) return 0.0/0.0; /* NaN */
    if (x == 0) return 0;
    double guess = x;
    for (int i = 0; i < 50; i++) {
        guess = (guess + x / guess) * 0.5;
    }
    return guess;
}

/* log via series expansion — rough but sufficient for SQLite */
double log(double x) {
    if (x <= 0) return -1.0/0.0;
    /* Reduce to [1, 2) range */
    int exp = 0;
    while (x >= 2.0) { x /= 2.0; exp++; }
    while (x < 1.0) { x *= 2.0; exp--; }
    /* ln(x) = ln(2)*exp + ln(x_reduced) */
    /* ln(1+u) = u - u^2/2 + u^3/3 - ... for |u| < 1 */
    double u = x - 1.0;
    double result = 0;
    double term = u;
    for (int i = 1; i <= 20; i++) {
        result += term / i;
        term *= -u;
    }
    return result + exp * 0.6931471805599453; /* ln(2) */
}

double log10(double x) {
    return log(x) * 0.4342944819032518; /* 1/ln(10) */
}

double pow(double base, double exp) {
    if (exp == 0.0) return 1.0;
    if (base == 0.0) return 0.0;

    /* Integer exponent fast path */
    if (exp == (double)(int)exp && exp > 0 && exp < 100) {
        double result = 1.0;
        int n = (int)exp;
        for (int i = 0; i < n; i++) result *= base;
        return result;
    }

    /* General: base^exp = e^(exp * ln(base)) */
    double lnb = log(fabs(base));
    double y = exp * lnb;

    /* e^y via Taylor series */
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 30; i++) {
        term *= y / i;
        result += term;
    }

    if (base < 0 && (int)exp % 2 != 0) result = -result;
    return result;
}

/* --- time stubs --- */

typedef long time_t;
time_t time(time_t *t) {
    if (t) *t = 0;
    return 0;
}

/* --- other stubs SQLite might need --- */

int getpid(void) { return 1; }

/* system/environ stubs */
char *getenv(const char *name) { (void)name; return NULL; }
