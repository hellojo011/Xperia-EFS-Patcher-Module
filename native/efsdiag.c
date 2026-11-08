// efsdiag: on-device Qualcomm EFS2/NV writer over vendor libdiag DCI.
// Mirrors EfsTools "uploadDirectory" semantics (mkdir -p, unlink, open/write)
// but runs on the phone itself, with backup, read-back verify and rollback.
//
// Usage:
//   efsdiag probe
//   efsdiag stat <efs_path>...
//   efsdiag get <efs_path> <local_file>
//   efsdiag apply <plan.tsv> <tx_dir>
//   efsdiag restore <tx_dir>
//
// plan.tsv lines:  E<TAB>/efs/path<TAB>/local/file
//                  N<TAB><nv_item_id><TAB>/local/file

#include <dlfcn.h>
#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/system_properties.h>
#include <time.h>
#include <unistd.h>

#define LIBDIAG_PATH "/vendor/lib64/libdiag.so"
#define DCI_NO_ERROR 1001
#define DIAG_CON_APSS 0x0001
#define DIAG_CON_MPSS 0x0002
#define PROC_MSM 0

#define DIAG_SUBSYS_CMD 0x4B
#define DIAG_NV_READ 0x26
#define DIAG_NV_WRITE 0x27
#define SUBSYS_EFS 0x13

#define EFS2_HELLO 0
#define EFS2_OPEN 2
#define EFS2_CLOSE 3
#define EFS2_READ 4
#define EFS2_WRITE 5
#define EFS2_UNLINK 8
#define EFS2_MKDIR 9
#define EFS2_STAT 15
#define EFS2_GET 39
#define EFS2_SYNC_NO_WAIT 48

#define EFS_O_RDONLY 00
#define EFS_O_WRONLY 01
#define EFS_O_CREAT 0100
#define EFS_O_TRUNC 01000
#define EFS_S_IFMT 0170000
#define EFS_S_IFDIR 0040000
#define EFS_ENOENT 2
#define EFS_EEXIST 17

#define NV_DATA_SIZE 128
#define NV_PKT_SIZE (3 + NV_DATA_SIZE + 2)
#define NV_DONE_S 0

#define CHUNK 512
#define RSP_BUF_SIZE 16384
#define REQ_TIMEOUT_SEC 5
#define MAX_FILE (1024 * 1024)

typedef void (*dci_rsp_cb)(unsigned char *ptr, int len, void *data);

static struct {
    void *handle;
    int (*lsm_init)(void *);
    int (*lsm_deinit)(void);
    int (*support_list_proc)(int, uint16_t *);
    int (*register_client)(int *, uint16_t *, int, void *);
    int (*release_client)(int *);
    int (*send_async)(int, unsigned char *, int, unsigned char *, int, dci_rsp_cb, void *);
} lib;

static int g_client = -1;
static int g_signal = SIGCONT;
static unsigned char g_rsp_buf[RSP_BUF_SIZE];
static unsigned char g_rsp[RSP_BUF_SIZE];
static int g_rsp_len;
static int g_rsp_ready;
static pthread_mutex_t g_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t g_cond = PTHREAD_COND_INITIALIZER;

static void on_signal(int sig) { (void)sig; }
static int diag_open_efs(void);

static void on_response(unsigned char *ptr, int len, void *data) {
    (void)data;
    pthread_mutex_lock(&g_lock);
    if (ptr && len > 0) {
        if (len > RSP_BUF_SIZE) len = RSP_BUF_SIZE;
        memcpy(g_rsp, ptr, len);
        g_rsp_len = len;
    } else {
        g_rsp_len = 0;
    }
    g_rsp_ready = 1;
    pthread_cond_signal(&g_cond);
    pthread_mutex_unlock(&g_lock);
}

static int load_libdiag(void) {
    lib.handle = dlopen(LIBDIAG_PATH, RTLD_NOW);
    if (!lib.handle) {
        printf("ERROR dlopen %s: %s\n", LIBDIAG_PATH, dlerror());
        return -1;
    }
    lib.lsm_init = dlsym(lib.handle, "Diag_LSM_Init");
    lib.lsm_deinit = dlsym(lib.handle, "Diag_LSM_DeInit");
    lib.support_list_proc = dlsym(lib.handle, "diag_get_dci_support_list_proc");
    lib.register_client = dlsym(lib.handle, "diag_register_dci_client");
    lib.release_client = dlsym(lib.handle, "diag_release_dci_client");
    lib.send_async = dlsym(lib.handle, "diag_send_dci_async_req");
    if (!lib.lsm_init || !lib.lsm_deinit || !lib.support_list_proc || !lib.register_client ||
        !lib.release_client || !lib.send_async) {
        printf("ERROR libdiag is missing DCI symbols\n");
        return -1;
    }
    return 0;
}

static void diag_close(void) {
    if (g_client >= 0) {
        lib.release_client(&g_client);
        g_client = -1;
    }
    if (lib.lsm_deinit) lib.lsm_deinit();
}

static int diag_open(void) {
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = on_signal;
    sigaction(SIGCONT, &sa, NULL);

    if (load_libdiag() != 0) return -1;

    // DCI state (num_dci_proc) is only initialized inside
    // diag_register_dci_client, so the support list must be queried after
    // registering; before that it always fails with 1008 (PARAM_FAIL).
    for (int attempt = 1; attempt <= 5; attempt++) {
        if (!(lib.lsm_init(NULL) & 0xFF)) {
            printf("WARN Diag_LSM_Init failed (attempt %d)\n", attempt);
            sleep(1);
            continue;
        }
        uint16_t want = DIAG_CON_APSS | DIAG_CON_MPSS;
        int client = -1;
        int rc = lib.register_client(&client, &want, PROC_MSM, &g_signal);
        if (rc == DCI_NO_ERROR) {
            uint16_t list = 0;
            int src = lib.support_list_proc(PROC_MSM, &list);
            printf("DCI_REGISTERED client=%d support_rc=%d mask=0x%x\n", client, src, list);
            if (src == DCI_NO_ERROR && !(list & DIAG_CON_MPSS))
                printf("WARN modem (MPSS) not listed as DCI capable yet\n");
            g_client = client;
            return 0;
        }
        printf("WARN diag_register_dci_client rc=%d (attempt %d)\n", rc, attempt);
        lib.lsm_deinit();
        sleep(1);
    }
    printf("ERROR could not open a DCI session to the modem\n");
    return -1;
}

// Sends one request and waits for its response. Returns response length or -1.
static int dci_xfer(unsigned char *req, int req_len) {
    pthread_mutex_lock(&g_lock);
    g_rsp_ready = 0;
    g_rsp_len = 0;
    pthread_mutex_unlock(&g_lock);

    int rc = lib.send_async(g_client, req, req_len, g_rsp_buf, RSP_BUF_SIZE, on_response, NULL);
    if (rc != DCI_NO_ERROR) {
        printf("ERROR diag_send_dci_async_req rc=%d cmd=0x%02x\n", rc, req[0]);
        return -1;
    }

    struct timespec deadline;
    clock_gettime(CLOCK_REALTIME, &deadline);
    deadline.tv_sec += REQ_TIMEOUT_SEC;
    pthread_mutex_lock(&g_lock);
    while (!g_rsp_ready) {
        if (pthread_cond_timedwait(&g_cond, &g_lock, &deadline) == ETIMEDOUT) break;
    }
    int ready = g_rsp_ready, len = g_rsp_len;
    pthread_mutex_unlock(&g_lock);
    if (!ready) {
        printf("ERROR DCI response timeout cmd=0x%02x\n", req[0]);
        return -1;
    }
    return len;
}

static void put_u16(unsigned char *p, uint16_t v) { p[0] = v; p[1] = v >> 8; }
static void put_u32(unsigned char *p, uint32_t v) { p[0] = v; p[1] = v >> 8; p[2] = v >> 16; p[3] = v >> 24; }
static uint16_t get_u16(const unsigned char *p) { return p[0] | (p[1] << 8); }
static int32_t get_i32(const unsigned char *p) { return (int32_t)(p[0] | (p[1] << 8) | (p[2] << 16) | ((uint32_t)p[3] << 24)); }

static int efs_hdr(unsigned char *p, uint16_t cmd) {
    p[0] = DIAG_SUBSYS_CMD;
    p[1] = SUBSYS_EFS;
    put_u16(p + 2, cmd);
    return 4;
}

// Sends an EFS2 request; returns response length (>= min_len) or -1.
static int efs_xfer(unsigned char *req, int req_len, uint16_t cmd, int min_len) {
    int len = dci_xfer(req, req_len);
    if (len < 0) return -1;
    if (len >= 1 && (g_rsp[0] == 0x13 || g_rsp[0] == 0x14 || g_rsp[0] == 0x15)) {
        printf("ERROR modem rejected EFS cmd %u (diag code 0x%02x)\n", cmd, g_rsp[0]);
        return -1;
    }
    if (len < min_len || g_rsp[0] != DIAG_SUBSYS_CMD || g_rsp[1] != SUBSYS_EFS || get_u16(g_rsp + 2) != cmd) {
        printf("ERROR unexpected EFS response cmd=%u len=%d\n", cmd, len);
        return -1;
    }
    return len;
}

static int efs_path_req(unsigned char *req, int off, const char *path) {
    size_t n = strlen(path);
    memcpy(req + off, path, n + 1);
    return off + (int)n + 1;
}

static int efs_hello(void) {
    unsigned char req[44];
    int off = efs_hdr(req, EFS2_HELLO);
    for (int i = 0; i < 6; i++) put_u32(req + off + i * 4, 0x100000);
    put_u32(req + 28, 1);
    put_u32(req + 32, 1);
    put_u32(req + 36, 1);
    put_u32(req + 40, 0xFFFFFFFF);
    if (efs_xfer(req, 44, EFS2_HELLO, 4) < 0) return -1;
    printf("EFS_HELLO ok\n");
    return 0;
}

// Returns 0 and fills mode/size, or the EFS errno (>0), or -1 on transport error.
static int efs_stat(const char *path, int32_t *mode, int32_t *size) {
    unsigned char req[1100];
    int off = efs_path_req(req, efs_hdr(req, EFS2_STAT), path);
    if (efs_xfer(req, off, EFS2_STAT, 16) < 0) return -1;
    int32_t err = get_i32(g_rsp + 4);
    if (err) return err;
    if (mode) *mode = get_i32(g_rsp + 8);
    if (size) *size = get_i32(g_rsp + 12);
    return 0;
}

static int efs_simple_path(uint16_t cmd, const char *path, int mkdir_mode) {
    unsigned char req[1100];
    int off = efs_hdr(req, cmd);
    if (mkdir_mode >= 0) {
        put_u16(req + off, (uint16_t)mkdir_mode);
        off += 2;
    }
    off = efs_path_req(req, off, path);
    if (efs_xfer(req, off, cmd, 8) < 0) return -1;
    return get_i32(g_rsp + 4);
}

static int efs_unlink(const char *path) { return efs_simple_path(EFS2_UNLINK, path, -1); }

static int efs_mkdir_p(const char *file_path) {
    char buf[1024];
    snprintf(buf, sizeof(buf), "%s", file_path);
    char *slash = strrchr(buf, '/');
    if (!slash || slash == buf) return 0;
    *slash = '\0';
    for (char *p = buf + 1; ; p++) {
        if (*p == '/' || *p == '\0') {
            char c = *p;
            *p = '\0';
            // Like EfsTools: only mkdir what stat says is missing. This modem
            // answers mkdir on an existing directory with errno 6, not EEXIST.
            int32_t mode = 0;
            int st = efs_stat(buf, &mode, NULL);
            if (st < 0) return -1;
            if (st != 0) {
                int err = efs_simple_path(EFS2_MKDIR, buf, 0777);
                if (err < 0) return -1;
                if (err != 0) st = efs_stat(buf, &mode, NULL);
                if (err != 0 && st != 0) {
                    printf("ERROR MKDIR %s errno=%d\n", buf, err);
                    return err;
                }
            }
            if (st == 0 && (mode & EFS_S_IFMT) != EFS_S_IFDIR) {
                printf("ERROR %s exists on the modem but is not a directory\n", buf);
                return -1;
            }
            *p = c;
            if (c == '\0') break;
        }
    }
    return 0;
}

static int efs_open(const char *path, int32_t flags, int32_t mode, int32_t *fd) {
    unsigned char req[1100];
    int off = efs_hdr(req, EFS2_OPEN);
    put_u32(req + off, flags);
    put_u32(req + off + 4, mode);
    off = efs_path_req(req, off + 8, path);
    if (efs_xfer(req, off, EFS2_OPEN, 12) < 0) return -1;
    *fd = get_i32(g_rsp + 4);
    return get_i32(g_rsp + 8);
}

static int efs_close(int32_t fd) {
    unsigned char req[8];
    int off = efs_hdr(req, EFS2_CLOSE);
    put_u32(req + off, fd);
    if (efs_xfer(req, off + 4, EFS2_CLOSE, 8) < 0) return -1;
    return get_i32(g_rsp + 4);
}

// EFS item nodes cannot always be opened; EFS2_GET reads them whole.
static int efs_get_item(const char *path, unsigned char *out, int cap, int *out_len) {
    unsigned char req[1100];
    int off = efs_hdr(req, EFS2_GET);
    size_t n = strlen(path) + 1;
    put_u32(req + off, cap > 4096 ? 4096 : cap);
    put_u32(req + off + 4, (uint32_t)n);
    put_u16(req + off + 8, 1);
    off = efs_path_req(req, off + 10, path);
    int len = efs_xfer(req, off, EFS2_GET, 14);
    if (len < 0) return -1;
    int32_t num = get_i32(g_rsp + 4), err = get_i32(g_rsp + 8);
    if (err) return err;
    if (num < 0 || num > cap || 14 + num > len) return -1;
    memcpy(out, g_rsp + 14, num);
    *out_len = num;
    return 0;
}

// Reads a whole EFS file. Returns 0, EFS errno (>0) or -1.
static int efs_read_file(const char *path, unsigned char *out, int cap, int *out_len) {
    int32_t fd;
    int err = efs_open(path, EFS_O_RDONLY, 0, &fd);
    if (err < 0) return -1;
    if (err) {
        int ierr = efs_get_item(path, out, cap, out_len);
        return ierr == 0 ? 0 : err;
    }
    int total = 0, result = 0;
    for (;;) {
        unsigned char req[16];
        int off = efs_hdr(req, EFS2_READ);
        put_u32(req + off, fd);
        put_u32(req + off + 4, CHUNK);
        put_u32(req + off + 8, total);
        int len = efs_xfer(req, off + 12, EFS2_READ, 20);
        if (len < 0) { result = -1; break; }
        int32_t got = get_i32(g_rsp + 12), rerr = get_i32(g_rsp + 16);
        if (rerr) { result = rerr; break; }
        if (got <= 0) break;
        if (total + got > cap || 20 + got > len) { result = -1; break; }
        memcpy(out + total, g_rsp + 20, got);
        total += got;
    }
    efs_close(fd);
    *out_len = total;
    return result;
}

// *mutated is set once the existing file may have been touched, so rollback
// skips entries that failed before any change (e.g. during mkdir).
static int efs_write_file(const char *path, const unsigned char *data, int data_len, int *mutated) {
    if (efs_mkdir_p(path) != 0) return -1;
    int32_t mode, size;
    int st = efs_stat(path, &mode, &size);
    if (st < 0) return -1;
    if (mutated) *mutated = 1;
    if (st == 0) {
        int err = efs_unlink(path);
        if (err != 0) {
            printf("ERROR UNLINK %s errno=%d\n", path, err);
            return -1;
        }
    }
    int32_t fd;
    int err = efs_open(path, EFS_O_WRONLY | EFS_O_CREAT | EFS_O_TRUNC, 0777, &fd);
    if (err != 0) {
        printf("ERROR OPEN %s errno=%d\n", path, err);
        return -1;
    }
    int written = 0, result = 0;
    while (written < data_len) {
        unsigned char req[12 + CHUNK];
        int n = data_len - written > CHUNK ? CHUNK : data_len - written;
        int off = efs_hdr(req, EFS2_WRITE);
        put_u32(req + off, fd);
        put_u32(req + off + 4, written);
        memcpy(req + off + 8, data + written, n);
        if (efs_xfer(req, off + 8 + n, EFS2_WRITE, 20) < 0) { result = -1; break; }
        int32_t did = get_i32(g_rsp + 12), werr = get_i32(g_rsp + 16);
        if (werr || did <= 0) {
            printf("ERROR WRITE %s errno=%d written=%d\n", path, werr, did);
            result = -1;
            break;
        }
        written += did;
    }
    if (efs_close(fd) != 0 && result == 0) result = -1;
    return result;
}

static void efs_sync(void) {
    unsigned char req[16];
    int off = efs_hdr(req, EFS2_SYNC_NO_WAIT);
    put_u16(req + off, 1);
    off = efs_path_req(req, off + 2, "/");
    if (efs_xfer(req, off, EFS2_SYNC_NO_WAIT, 4) >= 0) printf("EFS_SYNC requested\n");
}

// NV items: classic 133-byte NV_READ/NV_WRITE packets.
static int nv_xfer(uint8_t cmd, uint16_t id, const unsigned char *data, int len, unsigned char *out) {
    unsigned char req[NV_PKT_SIZE];
    memset(req, 0, sizeof(req));
    req[0] = cmd;
    put_u16(req + 1, id);
    if (data) memcpy(req + 3, data, len > NV_DATA_SIZE ? NV_DATA_SIZE : len);
    int rlen = dci_xfer(req, NV_PKT_SIZE);
    if (rlen < 0) return -1;
    if (rlen < NV_PKT_SIZE || g_rsp[0] != cmd) {
        printf("ERROR NV cmd 0x%02x item %u rejected (diag code 0x%02x len %d)\n", cmd, id, g_rsp[0], rlen);
        return -1;
    }
    if (out) memcpy(out, g_rsp + 3, NV_DATA_SIZE);
    return get_u16(g_rsp + 3 + NV_DATA_SIZE);
}

static unsigned char *read_local(const char *path, int *len) {
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    unsigned char *buf = malloc(MAX_FILE);
    *len = (int)fread(buf, 1, MAX_FILE, f);
    fclose(f);
    return buf;
}

static int write_local(const char *path, const unsigned char *data, int len) {
    FILE *f = fopen(path, "wb");
    if (!f) return -1;
    int ok = (int)fwrite(data, 1, len, f) == len;
    fclose(f);
    return ok ? 0 : -1;
}

typedef struct {
    char kind;          // 'E' or 'N'
    char target[1024];  // EFS path or NV id
    char local[1024];
    int had_backup;     // 1: backup file saved, 0: target did not exist, -1: unknown
    int applied;
} entry_t;

static entry_t *load_plan(const char *path, int *count) {
    FILE *f = fopen(path, "r");
    if (!f) return NULL;
    int cap = 64, n = 0;
    entry_t *list = calloc(cap, sizeof(entry_t));
    char line[2200];
    while (fgets(line, sizeof(line), f)) {
        line[strcspn(line, "\r\n")] = '\0';
        char *k = strtok(line, "\t"), *t = strtok(NULL, "\t"), *l = strtok(NULL, "\t");
        if (!k || !t || (k[0] != 'E' && k[0] != 'N')) continue;
        if (n == cap) list = realloc(list, sizeof(entry_t) * (cap *= 2));
        memset(&list[n], 0, sizeof(entry_t));
        list[n].kind = k[0];
        snprintf(list[n].target, sizeof(list[n].target), "%s", t);
        snprintf(list[n].local, sizeof(list[n].local), "%s", l ? l : "");
        n++;
    }
    fclose(f);
    *count = n;
    return list;
}

static void backup_name(char *out, size_t cap, const char *tx, int idx) {
    snprintf(out, cap, "%s/backup/%04d.bin", tx, idx);
}

// Restores entries [0, upto) that were applied (or all with a manifest state when upto < 0).
static int rollback(entry_t *list, int count, const char *tx, int only_applied) {
    int failed = 0;
    unsigned char *buf = malloc(MAX_FILE);
    for (int i = count - 1; i >= 0; i--) {
        entry_t *e = &list[i];
        if (only_applied && !e->applied) continue;
        char bpath[1200];
        backup_name(bpath, sizeof(bpath), tx, i);
        if (e->kind == 'E') {
            if (e->had_backup == 1) {
                int len = 0;
                unsigned char *data = read_local(bpath, &len);
                if (!data || efs_write_file(e->target, data, len, NULL) != 0) {
                    printf("RESTORE_FAILED %s\n", e->target);
                    failed++;
                } else {
                    printf("RESTORED %s\n", e->target);
                }
                free(data);
            } else if (e->had_backup == 0) {
                int err = efs_unlink(e->target);
                if (err != 0 && err != EFS_ENOENT) {
                    printf("RESTORE_FAILED %s (unlink errno=%d)\n", e->target, err);
                    failed++;
                } else {
                    printf("REMOVED %s\n", e->target);
                }
            }
        } else if (e->had_backup == 1) {
            int len = 0;
            unsigned char *data = read_local(bpath, &len);
            uint16_t id = (uint16_t)atoi(e->target);
            if (!data || nv_xfer(DIAG_NV_WRITE, id, data, len, buf) != NV_DONE_S) {
                printf("RESTORE_FAILED nv %u\n", id);
                failed++;
            } else {
                printf("RESTORED nv %u\n", id);
            }
            free(data);
        }
    }
    free(buf);
    efs_sync();
    return failed;
}

static int write_manifest(entry_t *list, int count, const char *tx) {
    char path[1200];
    snprintf(path, sizeof(path), "%s/manifest.tsv", tx);
    FILE *f = fopen(path, "w");
    if (!f) return -1;
    for (int i = 0; i < count; i++)
        fprintf(f, "%c\t%s\t%d\n", list[i].kind, list[i].target, list[i].had_backup);
    fclose(f);
    return 0;
}

static int cmd_apply(const char *plan, const char *tx) {
    int count = 0;
    entry_t *list = load_plan(plan, &count);
    if (!list || count == 0) {
        printf("ERROR empty or unreadable plan %s\n", plan);
        return 1;
    }
    char dir[1200];
    snprintf(dir, sizeof(dir), "%s/backup", tx);
    mkdir(tx, 0700);
    mkdir(dir, 0700);

    if (diag_open_efs() != 0) return 1;
    unsigned char *buf = malloc(MAX_FILE), *nvbuf = malloc(NV_DATA_SIZE);

    // Phase 1: back up every target before anything is written.
    for (int i = 0; i < count; i++) {
        entry_t *e = &list[i];
        char bpath[1200];
        backup_name(bpath, sizeof(bpath), tx, i);
        printf("BACKUP %d/%d %c %s\n", i + 1, count, e->kind, e->target);
        if (e->kind == 'E') {
            int32_t mode = 0, size = 0;
            int st = efs_stat(e->target, &mode, &size);
            if (st == EFS_ENOENT) {
                e->had_backup = 0;
                continue;
            }
            if (st != 0) {
                printf("ERROR STAT %s errno=%d; nothing was written\n", e->target, st);
                write_manifest(list, i, tx);
                diag_close();
                return 1;
            }
            if ((mode & EFS_S_IFMT) == EFS_S_IFDIR) {
                printf("ERROR %s is a directory on the modem; nothing was written\n", e->target);
                diag_close();
                return 1;
            }
            int len = 0;
            int err = efs_read_file(e->target, buf, MAX_FILE, &len);
            if (err != 0 || write_local(bpath, buf, len) != 0) {
                printf("ERROR backup of %s failed (errno=%d); nothing was written\n", e->target, err);
                write_manifest(list, i, tx);
                diag_close();
                return 1;
            }
            e->had_backup = 1;
        } else {
            uint16_t id = (uint16_t)atoi(e->target);
            int status = nv_xfer(DIAG_NV_READ, id, NULL, 0, nvbuf);
            if (status == NV_DONE_S && write_local(bpath, nvbuf, NV_DATA_SIZE) == 0) {
                e->had_backup = 1;
            } else {
                // Unreadable NV items are skipped rather than overwritten blind.
                printf("NV_SKIP %u (read status %d, cannot back up)\n", id, status);
                e->had_backup = -1;
            }
        }
    }
    write_manifest(list, count, tx);

    // Phase 2: write and verify.
    int nv_warn = 0;
    for (int i = 0; i < count; i++) {
        entry_t *e = &list[i];
        int len = 0;
        unsigned char *data = read_local(e->local, &len);
        if (!data) {
            printf("ERROR cannot read local file %s\n", e->local);
            goto fail;
        }
        printf("WRITE %d/%d %c %s (%d bytes)\n", i + 1, count, e->kind, e->target, len);
        if (e->kind == 'E') {
            int vlen = 0;
            if (efs_write_file(e->target, data, len, &e->applied) != 0 ||
                efs_read_file(e->target, buf, MAX_FILE, &vlen) != 0 || vlen != len || memcmp(buf, data, len) != 0) {
                printf("ERROR write/verify failed for %s\n", e->target);
                free(data);
                goto fail;
            }
        } else if (e->had_backup == 1) {
            uint16_t id = (uint16_t)atoi(e->target);
            int n = len > NV_DATA_SIZE ? NV_DATA_SIZE : len;
            if (len == 0) {
                printf("NV_SKIP %u (empty file)\n", id);
            } else {
                e->applied = 1;
                int status = nv_xfer(DIAG_NV_WRITE, id, data, n, NULL);
                if (status != NV_DONE_S || nv_xfer(DIAG_NV_READ, id, NULL, 0, nvbuf) != NV_DONE_S ||
                    memcmp(nvbuf, data, n) != 0) {
                    printf("NV_WARN %u not applied (status %d)\n", id, status);
                    nv_warn++;
                }
            }
        }
        free(data);
    }
    efs_sync();
    diag_close();
    printf("RESULT=%s\n", nv_warn ? "OK_WITH_NV_WARNINGS" : "OK");
    return 0;

fail:
    printf("Apply failed, rolling back written entries\n");
    int failed = rollback(list, count, tx, 1);
    diag_close();
    printf("RESULT=%s\n", failed ? "FAILED_RESTORE_INCOMPLETE" : "FAILED_RESTORED");
    return 2;
}

static int cmd_restore(const char *tx) {
    char path[1200];
    snprintf(path, sizeof(path), "%s/manifest.tsv", tx);
    FILE *f = fopen(path, "r");
    if (!f) {
        printf("ERROR no manifest in %s\n", tx);
        return 1;
    }
    int cap = 64, n = 0;
    entry_t *list = calloc(cap, sizeof(entry_t));
    char line[1200];
    while (fgets(line, sizeof(line), f)) {
        line[strcspn(line, "\r\n")] = '\0';
        char *k = strtok(line, "\t"), *t = strtok(NULL, "\t"), *b = strtok(NULL, "\t");
        if (!k || !t || !b) continue;
        if (n == cap) list = realloc(list, sizeof(entry_t) * (cap *= 2));
        memset(&list[n], 0, sizeof(entry_t));
        list[n].kind = k[0];
        snprintf(list[n].target, sizeof(list[n].target), "%s", t);
        list[n].had_backup = atoi(b);
        n++;
    }
    fclose(f);
    if (diag_open_efs() != 0) return 1;
    int failed = rollback(list, n, tx, 0);
    diag_close();
    printf("RESULT=%s\n", failed ? "RESTORE_INCOMPLETE" : "RESTORED");
    return failed ? 2 : 0;
}

// Opens DCI and says EFS2 hello; one full reconnect if the first hello fails.
static int diag_open_efs(void) {
    for (int attempt = 1; attempt <= 2; attempt++) {
        if (diag_open() != 0) return -1;
        if (efs_hello() == 0) return 0;
        printf("WARN EFS hello failed (attempt %d), reconnecting\n", attempt);
        diag_close();
        sleep(1);
    }
    return -1;
}

static int cmd_probe(void) {
    int rc = diag_open_efs();
    if (rc != 0) {
        printf("RESULT=FAILED\n");
        return 1;
    }
    static const char *paths[] = {
        "/nv/item_files/ims",
        "/nv/item_files/mcfg/mcfg_autoselect_by_uim",
        "/nv/item_files/mcfg/mcfg_autoselect_by_uim_Subscription01",
    };
    for (size_t i = 0; i < sizeof(paths) / sizeof(paths[0]); i++) {
        int32_t mode = 0, size = 0;
        int st = efs_stat(paths[i], &mode, &size);
        printf("STAT %s errno=%d mode=0%o size=%d\n", paths[i], st, mode, size);
    }
    diag_close();
    printf("RESULT=%s\n", rc == 0 ? "OK" : "FAILED");
    return rc == 0 ? 0 : 1;
}

static int cmd_stat(int n, char **paths) {
    if (diag_open_efs() != 0) return 1;
    for (int i = 0; i < n; i++) {
        int32_t mode = 0, size = 0;
        int st = efs_stat(paths[i], &mode, &size);
        printf("STAT %s errno=%d mode=0%o size=%d\n", paths[i], st, mode, size);
    }
    diag_close();
    return 0;
}

static int cmd_get(const char *remote, const char *local) {
    if (diag_open_efs() != 0) return 1;
    unsigned char *buf = malloc(MAX_FILE);
    int len = 0;
    int err = efs_read_file(remote, buf, MAX_FILE, &len);
    diag_close();
    if (err != 0) {
        printf("ERROR read %s errno=%d\n", remote, err);
        return 1;
    }
    if (write_local(local, buf, len) != 0) return 1;
    printf("RESULT=OK %d bytes\n", len);
    return 0;
}

// Read-only check that every EFS entry of a plan still holds its local bytes.
// Exit 0 all match, 2 something differs or is missing, 1 diag unavailable.
static int cmd_verify(const char *plan) {
    int count = 0;
    entry_t *list = load_plan(plan, &count);
    if (!list) {
        printf("ERROR cannot read plan %s\n", plan);
        return 1;
    }
    if (diag_open_efs() != 0) {
        free(list);
        printf("RESULT=UNAVAILABLE\n");
        return 1;
    }
    unsigned char *buf = malloc(MAX_FILE);
    int checked = 0, changed = 0, failed = 0;
    for (int i = 0; i < count; i++) {
        if (list[i].kind != 'E') continue;
        int want_len = 0, got_len = 0;
        unsigned char *want = read_local(list[i].local, &want_len);
        if (!want) {
            printf("ERROR local %s\n", list[i].local);
            failed++;
            continue;
        }
        int err = efs_read_file(list[i].target, buf, MAX_FILE, &got_len);
        checked++;
        if (err == 2) {
            printf("MISSING %s\n", list[i].target);
            changed++;
        } else if (err != 0) {
            printf("ERROR read %s errno=%d\n", list[i].target, err);
            failed++;
        } else if (got_len != want_len || memcmp(buf, want, want_len) != 0) {
            printf("DIFF %s (efs %d bytes, expected %d)\n", list[i].target, got_len, want_len);
            changed++;
        }
        free(want);
    }
    free(buf);
    free(list);
    diag_close();
    printf("CHECKED=%d CHANGED=%d ERRORS=%d\n", checked, changed, failed);
    if (changed) { printf("RESULT=CHANGED\n"); return 2; }
    if (failed) { printf("RESULT=UNAVAILABLE\n"); return 1; }
    printf("RESULT=MATCH\n");
    return 0;
}

static void mkdir_local_parents(const char *file_path) {
    char tmp[2048];
    snprintf(tmp, sizeof(tmp), "%s", file_path);
    for (char *p = tmp + 1; *p; p++) {
        if (*p != '/') continue;
        *p = 0;
        mkdir(tmp, 0700);
        *p = '/';
    }
}

// Read-only: copies every EFS path listed in `list` (one per line) to
// outdir/<path>. Exit 0 done (missing files are reported), 1 diag unavailable.
static int cmd_pull(const char *list_path, const char *outdir) {
    FILE *f = fopen(list_path, "r");
    if (!f) {
        printf("ERROR cannot read list %s\n", list_path);
        return 1;
    }
    if (diag_open_efs() != 0) {
        fclose(f);
        printf("RESULT=UNAVAILABLE\n");
        return 1;
    }
    unsigned char *buf = malloc(MAX_FILE);
    char line[1024], local[2048];
    int pulled = 0, missing = 0, failed = 0;
    while (fgets(line, sizeof(line), f)) {
        line[strcspn(line, "\r\n")] = 0;
        if (line[0] != '/') continue;
        int len = 0;
        int err = efs_read_file(line, buf, MAX_FILE, &len);
        if (err == 2) {
            printf("MISSING %s\n", line);
            missing++;
            continue;
        }
        if (err != 0) {
            printf("ERROR read %s errno=%d\n", line, err);
            failed++;
            continue;
        }
        snprintf(local, sizeof(local), "%s%s", outdir, line);
        mkdir_local_parents(local);
        if (write_local(local, buf, len) != 0) {
            printf("ERROR local %s\n", local);
            failed++;
            continue;
        }
        pulled++;
    }
    fclose(f);
    free(buf);
    diag_close();
    printf("PULLED=%d MISSING=%d ERRORS=%d\n", pulled, missing, failed);
    printf("RESULT=%s\n", failed ? "PARTIAL" : "OK");
    return 0;
}

// Sleeps in the kernel (futex) until system property `name` is set again or
// `timeout` seconds pass (0 = no limit); no CPU is used while waiting.
// Exit 0 changed (prints the new value), 1 timeout.
static int cmd_propwait(const char *name, int timeout) {
    struct timespec ts = { timeout, 0 };
    const struct timespec *tp = timeout > 0 ? &ts : NULL;
    uint32_t new_serial = 0;
    const prop_info *pi = __system_property_find(name);
    if (!pi) {
        // Not created yet: wait for any property change; the caller re-checks.
        return __system_property_wait(NULL, __system_property_area_serial(), &new_serial, tp) ? 0 : 1;
    }
    if (!__system_property_wait(pi, __system_property_serial(pi), &new_serial, tp)) return 1;
    char value[PROP_VALUE_MAX] = "";
    __system_property_get(name, value);
    printf("%s\n", value);
    return 0;
}

int main(int argc, char **argv) {
    setvbuf(stdout, NULL, _IOLBF, 0);
    if (argc >= 2 && !strcmp(argv[1], "probe")) return cmd_probe();
    if (argc >= 3 && !strcmp(argv[1], "stat")) return cmd_stat(argc - 2, argv + 2);
    if (argc >= 4 && !strcmp(argv[1], "get")) return cmd_get(argv[2], argv[3]);
    if (argc >= 4 && !strcmp(argv[1], "apply")) return cmd_apply(argv[2], argv[3]);
    if (argc >= 3 && !strcmp(argv[1], "restore")) return cmd_restore(argv[2]);
    if (argc >= 3 && !strcmp(argv[1], "verify")) return cmd_verify(argv[2]);
    if (argc >= 4 && !strcmp(argv[1], "pull")) return cmd_pull(argv[2], argv[3]);
    if (argc >= 3 && !strcmp(argv[1], "propwait")) return cmd_propwait(argv[2], argc >= 4 ? atoi(argv[3]) : 0);
    fprintf(stderr, "usage: efsdiag probe | get <efs> <local> | apply <plan> <txdir> | restore <txdir> | verify <plan>\n");
    return 64;
}
