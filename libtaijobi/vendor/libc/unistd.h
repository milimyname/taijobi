/* Minimal unistd.h stub for wasm32-freestanding */
#ifndef _UNISTD_H
#define _UNISTD_H

#include <stddef.h>

typedef int pid_t;
typedef int uid_t;
typedef int gid_t;

static inline pid_t getpid(void) { return 1; }
static inline int close(int fd) { (void)fd; return 0; }
static inline int unlink(const char *path) { (void)path; return 0; }
static inline int access(const char *path, int mode) { (void)path; (void)mode; return -1; }
static inline long sysconf(int name) { (void)name; return -1; }

#define F_OK 0
#define R_OK 4
#define W_OK 2
#define X_OK 1
#define _SC_PAGESIZE 30

#endif /* _UNISTD_H */
