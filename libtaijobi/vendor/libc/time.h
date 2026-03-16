/* Minimal time.h stub for wasm32-freestanding */
#ifndef _TIME_H
#define _TIME_H

#include <stddef.h>

typedef long time_t;

struct tm {
    int tm_sec;
    int tm_min;
    int tm_hour;
    int tm_mday;
    int tm_mon;
    int tm_year;
    int tm_wday;
    int tm_yday;
    int tm_isdst;
};

static inline time_t time(time_t *t) {
    if (t) *t = 0;
    return 0;
}

#endif /* _TIME_H */
