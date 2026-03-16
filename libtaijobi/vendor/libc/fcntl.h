/* Minimal fcntl.h stub for wasm32-freestanding */
#ifndef _FCNTL_H
#define _FCNTL_H

#define O_RDONLY  0
#define O_WRONLY  1
#define O_RDWR    2
#define O_CREAT   0100
#define O_EXCL    0200
#define O_TRUNC   01000

static inline int open(const char *path, int flags, ...) {
    (void)path; (void)flags;
    return -1;
}

#endif /* _FCNTL_H */
