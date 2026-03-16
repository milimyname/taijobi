/*
 * Minimal WASM VFS for SQLite.
 *
 * SQLite on wasm32-freestanding uses SQLITE_OS_OTHER, which means we must
 * provide our own VFS. This is an in-memory VFS — the JS host is responsible
 * for persisting the database bytes to OPFS.
 *
 * We also provide stubs for libc functions that SQLite references but that
 * don't exist in freestanding mode.
 */
#include "sqlite3.h"

#include <stddef.h>
#include <stdint.h>
#include <string.h>

/* ===== In-memory file implementation ===== */

#define MAX_MEM_FILES 4
#ifndef MAX_FILE_SIZE
#define MAX_FILE_SIZE (8 * 1024 * 1024)  /* 8 MB max DB size per file */
#endif

typedef struct MemFile {
    char name[256];
    unsigned char *data;
    int size;
    int capacity;
    int is_open;
} MemFile;

static MemFile mem_files[MAX_MEM_FILES];
static unsigned char mem_storage[MAX_MEM_FILES][MAX_FILE_SIZE];
static int mem_files_init = 0;

static void init_mem_files(void) {
    if (mem_files_init) return;
    for (int i = 0; i < MAX_MEM_FILES; i++) {
        mem_files[i].data = mem_storage[i];
        mem_files[i].size = 0;
        mem_files[i].capacity = MAX_FILE_SIZE;
        mem_files[i].is_open = 0;
        mem_files[i].name[0] = 0;
    }
    mem_files_init = 1;
}

static MemFile *find_file(const char *name) {
    for (int i = 0; i < MAX_MEM_FILES; i++) {
        if (mem_files[i].name[0] && strcmp(mem_files[i].name, name) == 0) {
            return &mem_files[i];
        }
    }
    return NULL;
}

static MemFile *alloc_file(const char *name) {
    MemFile *f = find_file(name);
    if (f) return f;
    for (int i = 0; i < MAX_MEM_FILES; i++) {
        if (!mem_files[i].name[0]) {
            size_t len = strlen(name);
            if (len >= 256) len = 255;
            memcpy(mem_files[i].name, name, len);
            mem_files[i].name[len] = 0;
            mem_files[i].size = 0;
            return &mem_files[i];
        }
    }
    return NULL;
}

/* ===== SQLite VFS file methods ===== */

typedef struct WasmFile {
    sqlite3_file base;
    MemFile *mem;
} WasmFile;

static int wasm_close(sqlite3_file *pFile) {
    WasmFile *p = (WasmFile *)pFile;
    if (p->mem) p->mem->is_open = 0;
    return SQLITE_OK;
}

static int wasm_read(sqlite3_file *pFile, void *buf, int iAmt, sqlite3_int64 iOfst) {
    WasmFile *p = (WasmFile *)pFile;
    if (!p->mem) return SQLITE_IOERR_READ;

    if (iOfst + iAmt > p->mem->size) {
        int avail = p->mem->size - (int)iOfst;
        if (avail <= 0) {
            memset(buf, 0, iAmt);
            return SQLITE_IOERR_SHORT_READ;
        }
        memcpy(buf, p->mem->data + iOfst, avail);
        memset((char *)buf + avail, 0, iAmt - avail);
        return SQLITE_IOERR_SHORT_READ;
    }
    memcpy(buf, p->mem->data + iOfst, iAmt);
    return SQLITE_OK;
}

static int wasm_write(sqlite3_file *pFile, const void *buf, int iAmt, sqlite3_int64 iOfst) {
    WasmFile *p = (WasmFile *)pFile;
    if (!p->mem) return SQLITE_IOERR_WRITE;

    int end = (int)iOfst + iAmt;
    if (end > p->mem->capacity) return SQLITE_FULL;

    memcpy(p->mem->data + iOfst, buf, iAmt);
    if (end > p->mem->size) p->mem->size = end;
    return SQLITE_OK;
}

static int wasm_truncate(sqlite3_file *pFile, sqlite3_int64 size) {
    WasmFile *p = (WasmFile *)pFile;
    if (p->mem) p->mem->size = (int)size;
    return SQLITE_OK;
}

static int wasm_sync(sqlite3_file *pFile, int flags) {
    (void)pFile; (void)flags;
    return SQLITE_OK;
}

static int wasm_file_size(sqlite3_file *pFile, sqlite3_int64 *pSize) {
    WasmFile *p = (WasmFile *)pFile;
    *pSize = p->mem ? p->mem->size : 0;
    return SQLITE_OK;
}

static int wasm_lock(sqlite3_file *pFile, int lock) {
    (void)pFile; (void)lock;
    return SQLITE_OK;
}

static int wasm_unlock(sqlite3_file *pFile, int lock) {
    (void)pFile; (void)lock;
    return SQLITE_OK;
}

static int wasm_check_reserved_lock(sqlite3_file *pFile, int *pResOut) {
    (void)pFile;
    *pResOut = 0;
    return SQLITE_OK;
}

static int wasm_file_control(sqlite3_file *pFile, int op, void *pArg) {
    (void)pFile; (void)op; (void)pArg;
    return SQLITE_NOTFOUND;
}

static int wasm_sector_size(sqlite3_file *pFile) {
    (void)pFile;
    return 512;
}

static int wasm_device_characteristics(sqlite3_file *pFile) {
    (void)pFile;
    return SQLITE_IOCAP_ATOMIC | SQLITE_IOCAP_SAFE_APPEND;
}

static const sqlite3_io_methods wasm_io_methods = {
    1,                            /* iVersion */
    wasm_close,
    wasm_read,
    wasm_write,
    wasm_truncate,
    wasm_sync,
    wasm_file_size,
    wasm_lock,
    wasm_unlock,
    wasm_check_reserved_lock,
    wasm_file_control,
    wasm_sector_size,
    wasm_device_characteristics,
    /* v2+ methods */
    0, 0, 0, 0
};

/* ===== SQLite VFS methods ===== */

static int wasm_vfs_open(sqlite3_vfs *pVfs, const char *zName, sqlite3_file *pFile,
                         int flags, int *pOutFlags) {
    (void)pVfs;
    WasmFile *p = (WasmFile *)pFile;

    init_mem_files();

    const char *name = zName ? zName : ":memory:";
    MemFile *mf = alloc_file(name);
    if (!mf) return SQLITE_CANTOPEN;

    mf->is_open = 1;
    p->mem = mf;
    p->base.pMethods = &wasm_io_methods;

    if (pOutFlags) *pOutFlags = flags;
    return SQLITE_OK;
}

static int wasm_vfs_delete(sqlite3_vfs *pVfs, const char *zName, int syncDir) {
    (void)pVfs; (void)syncDir;
    init_mem_files();
    MemFile *mf = find_file(zName);
    if (mf) {
        mf->name[0] = 0;
        mf->size = 0;
    }
    return SQLITE_OK;
}

static int wasm_vfs_access(sqlite3_vfs *pVfs, const char *zName, int flags, int *pResOut) {
    (void)pVfs; (void)flags;
    init_mem_files();
    *pResOut = find_file(zName) != NULL;
    return SQLITE_OK;
}

static int wasm_vfs_full_pathname(sqlite3_vfs *pVfs, const char *zName,
                                  int nOut, char *zOut) {
    (void)pVfs;
    size_t len = strlen(zName);
    if ((int)len >= nOut) len = nOut - 1;
    memcpy(zOut, zName, len);
    zOut[len] = 0;
    return SQLITE_OK;
}

static int wasm_vfs_randomness(sqlite3_vfs *pVfs, int nByte, char *zOut) {
    (void)pVfs;
    /* Simple PRNG — not cryptographically secure, but fine for SQLite's needs */
    static unsigned int seed = 12345;
    for (int i = 0; i < nByte; i++) {
        seed = seed * 1103515245 + 12345;
        zOut[i] = (char)(seed >> 16);
    }
    return nByte;
}

static int wasm_vfs_sleep(sqlite3_vfs *pVfs, int microseconds) {
    (void)pVfs; (void)microseconds;
    return 0;
}

static int wasm_vfs_current_time(sqlite3_vfs *pVfs, double *pTime) {
    (void)pVfs;
    /* Return a fixed time — good enough for SQLite's purposes in WASM */
    *pTime = 2460000.5; /* ~2023 Julian date */
    return SQLITE_OK;
}

static sqlite3_vfs wasm_vfs = {
    1,                          /* iVersion */
    sizeof(WasmFile),           /* szOsFile */
    256,                        /* mxPathname */
    0,                          /* pNext */
    "wasm",                     /* zName */
    0,                          /* pAppData */
    wasm_vfs_open,
    wasm_vfs_delete,
    wasm_vfs_access,
    wasm_vfs_full_pathname,
    0,                          /* xDlOpen */
    0,                          /* xDlError */
    0,                          /* xDlSym */
    0,                          /* xDlClose */
    wasm_vfs_randomness,
    wasm_vfs_sleep,
    wasm_vfs_current_time,
    0,                          /* xGetLastError */
};

/* ===== Init function — must be called before sqlite3_open ===== */

/* This is called automatically by sqlite3_initialize() because
   SQLITE_OS_OTHER is set. We register our VFS as the default. */
int sqlite3_os_init(void) {
    return sqlite3_vfs_register(&wasm_vfs, 1);
}

int sqlite3_os_end(void) {
    return SQLITE_OK;
}

/* ===== DB persistence helpers (called from Zig via extern) ===== */

/* Get pointer to the raw DB bytes for the named file. */
unsigned char *wasm_vfs_get_db_ptr(const char *name) {
    init_mem_files();
    MemFile *mf = find_file(name);
    if (!mf) return NULL;
    return mf->data;
}

/* Get the current size of the named DB file. */
int wasm_vfs_get_db_size(const char *name) {
    init_mem_files();
    MemFile *mf = find_file(name);
    if (!mf) return 0;
    return mf->size;
}

/* Load DB bytes into the named file's memory before sqlite3_open.
   Creates the file slot if it doesn't exist.
   Also clears any stale WAL/SHM files to prevent OpenFailed on re-init. */
int wasm_vfs_load_db(const char *name, const unsigned char *data, int size) {
    init_mem_files();
    MemFile *mf = alloc_file(name);
    if (!mf) return -1;
    if (size > mf->capacity) return -2;
    memcpy(mf->data, data, size);
    mf->size = size;

    /* Clear stale WAL/SHM files — after sqlite3_close these persist in VFS
       but don't match the freshly loaded DB bytes. */
    size_t name_len = strlen(name);
    if (name_len < 248) {
        char buf[256];
        memcpy(buf, name, name_len);
        memcpy(buf + name_len, "-wal", 5);
        MemFile *wal = find_file(buf);
        if (wal) { wal->name[0] = 0; wal->size = 0; }
        memcpy(buf + name_len, "-shm", 5);
        MemFile *shm = find_file(buf);
        if (shm) { shm->name[0] = 0; shm->size = 0; }
    }

    return 0;
}
