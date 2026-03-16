/* Minimal math.h stub for SQLite on wasm32-freestanding */
#ifndef _MATH_H
#define _MATH_H

/* Implementations provided by libc_shim.c */
extern double fabs(double x);
extern double ceil(double x);
extern double floor(double x);
extern double sqrt(double x);
extern double log(double x);
extern double log10(double x);
extern double pow(double x, double y);
extern double fmod(double x, double y);

#define isnan(x) ((x) != (x))
#define isinf(x) (!isnan(x) && isnan((x) - (x)))

#define HUGE_VAL (__builtin_huge_val())
#define NAN (__builtin_nan(""))
#define INFINITY (__builtin_inf())

#endif /* _MATH_H */
