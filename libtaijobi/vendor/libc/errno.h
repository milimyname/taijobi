/* Minimal errno.h stub for wasm32-freestanding */
#ifndef _ERRNO_H
#define _ERRNO_H

static int _wasm_errno = 0;
#define errno _wasm_errno

#define ENOENT 2
#define EACCES 13
#define EEXIST 17
#define ENOTDIR 20
#define EISDIR 21
#define EINVAL 22
#define ENOMEM 12
#define ENOSPC 28
#define ERANGE 34

#endif /* _ERRNO_H */
