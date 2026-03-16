/* Minimal sys/stat.h stub */
#ifndef _SYS_STAT_H
#define _SYS_STAT_H

#include <sys/types.h>

struct stat {
    dev_t st_dev;
    ino_t st_ino;
    mode_t st_mode;
    nlink_t st_nlink;
    uid_t st_uid;
    gid_t st_gid;
    off_t st_size;
    long st_atime;
    long st_mtime;
    long st_ctime;
    blksize_t st_blksize;
    blkcnt_t st_blkcnt;
};

#define S_ISREG(m) (((m) & 0170000) == 0100000)
#define S_ISDIR(m) (((m) & 0170000) == 0040000)

static inline int stat(const char *path, struct stat *buf) {
    (void)path; (void)buf;
    return -1;
}

static inline int fstat(int fd, struct stat *buf) {
    (void)fd; (void)buf;
    return -1;
}

#endif /* _SYS_STAT_H */
