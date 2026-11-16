/*
 * fs_init - minimal initramfs /init
 *
 * Finds the persistent disk, mounts its read-only squashfs root and its
 * writable ext2 partition, combines them with overlayfs and switch_root's
 * into /bin/init.
 *
 * The partitions are found by their content: the first partition with a
 * squashfs, and an ext2 partition on the same disk. So the disk works on
 * any controller the kernel has a driver for (/dev/vda, /dev/sda, ...).
 * Slow devices (e.g. USB) get a few seconds to appear.
 *
 * Optional kernel cmdline parameters:
 *   squashfs_dev=<dev>   read-only lower layer (e.g. /dev/vda1)
 *   rw_dev=<dev>         writable upper layer, ext2 (e.g. /dev/vda2)
 *   fs_wait=<seconds>    how long to wait for the disk (default 10)
 *
 * DISK_DRIVERS (set by the Makefile) lists the disk drivers in the kernel,
 * for the message when no disk is found.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#ifndef DISK_DRIVERS
#define DISK_DRIVERS "unknown"
#endif

#define NEW_ROOT "/overlay_root"
#define WAIT_STEP_MS 250
#define MAX_PARTS 64

enum fs_type { FS_UNKNOWN, FS_SQUASHFS, FS_EXT2 };

struct part {
    char name[32];
    enum fs_type type;
};

static char cmdline[1024];
static struct part parts[MAX_PARTS];
static int nparts;

/* Open /dev/console as stdin/stdout/stderr (if not already open). */
static void setup_console(void)
{
    int fd = open("/dev/console", O_RDWR | O_NOCTTY);
    if (fd < 0)
        return;
    dup2(fd, STDIN_FILENO);
    dup2(fd, STDOUT_FILENO);
    dup2(fd, STDERR_FILENO);
    if (fd > STDERR_FILENO)
        close(fd);
}

static void halt(void)
{
    fprintf(stderr, "fs_init: boot halted\n");
    for (;;)
        pause();
}

/* Do not return: PID 1 exiting would panic and hide the message. */
static void fatal(const char *msg)
{
    if (errno)
        fprintf(stderr, "fs_init: %s: %s\n", msg, strerror(errno));
    else
        fprintf(stderr, "fs_init: %s\n", msg);
    halt();
}

static void read_cmdline(void)
{
    int fd = open("/proc/cmdline", O_RDONLY);
    if (fd < 0)
        fatal("cannot open /proc/cmdline");
    ssize_t n = read(fd, cmdline, sizeof(cmdline) - 1);
    close(fd);
    if (n < 0)
        fatal("cannot read /proc/cmdline");
    cmdline[n] = '\0';
}

/* Copy the value of a whole-word "key=value" token into value[size].
 * Returns value, or NULL if the key is not present. */
static const char *get_cmdline_arg(const char *key, char *value, size_t size)
{
    size_t klen = strlen(key);
    const char *p = cmdline;

    while (*p) {
        while (*p == ' ' || *p == '\n')
            p++;
        const char *end = p + strcspn(p, " \n");
        if ((size_t)(end - p) > klen && !strncmp(p, key, klen) && p[klen] == '=') {
            size_t vlen = end - (p + klen + 1);
            if (vlen >= size)
                vlen = size - 1;
            memcpy(value, p + klen + 1, vlen);
            value[vlen] = '\0';
            return value;
        }
        p = end;
    }
    return NULL;
}

static void sleep_ms(long ms)
{
    struct timespec ts = { ms / 1000, (ms % 1000) * 1000000L };
    nanosleep(&ts, NULL);
}

static int read_at(int fd, off_t off, void *buf, size_t len)
{
    return pread(fd, buf, len, off) == (ssize_t)len;
}

/* Recognize the filesystem by its magic number. */
static enum fs_type probe(const char *name)
{
    char dev[48];
    unsigned char buf[4];
    enum fs_type type = FS_UNKNOWN;

    snprintf(dev, sizeof(dev), "/dev/%s", name);
    int fd = open(dev, O_RDONLY);
    if (fd < 0)
        return FS_UNKNOWN;
    if (read_at(fd, 0, buf, 4) && !memcmp(buf, "hsqs", 4))
        type = FS_SQUASHFS;
    else if (read_at(fd, 1080, buf, 2) && buf[0] == 0x53 && buf[1] == 0xef)
        type = FS_EXT2;
    close(fd);
    return type;
}

/* Read the block devices from /proc/partitions into parts[]: the last
 * word of each line after the header ("major minor #blocks name").
 * (No stdio scanf: it would double the size of fs_init.) */
static void scan_partitions(void)
{
    static char buf[4096];

    nparts = 0;
    int fd = open("/proc/partitions", O_RDONLY);
    if (fd < 0)
        return;
    ssize_t n = read(fd, buf, sizeof(buf) - 1);
    close(fd);
    if (n <= 0)
        return;
    buf[n] = '\0';

    char *line = strchr(buf, '\n');            /* skip the header */
    while (line && nparts < MAX_PARTS) {
        line++;
        char *eol = strchr(line, '\n');
        if (eol)
            *eol = '\0';
        char *name = strrchr(line, ' ');
        if (name && name[1] && strlen(name + 1) < sizeof(parts[0].name)) {
            strcpy(parts[nparts].name, name + 1);
            parts[nparts].type = probe(name + 1);
            nparts++;
        }
        line = eol;
    }
}

/* Length of the disk part of a partition name: sda1 -> sda,
 * nvme0n1p2 -> nvme0n1p (partitions of one disk have the same prefix). */
static size_t disk_prefix_len(const char *name)
{
    size_t n = strlen(name);
    while (n > 0 && name[n - 1] >= '0' && name[n - 1] <= '9')
        n--;
    return n;
}

/* Find the squashfs partition and an ext2 partition on the same disk. */
static int find_disk(char *ro, char *rw, size_t size)
{
    for (int i = 0; i < nparts; i++) {
        if (parts[i].type != FS_SQUASHFS)
            continue;
        size_t plen = disk_prefix_len(parts[i].name);
        for (int j = 0; j < nparts; j++) {
            if (parts[j].type != FS_EXT2 || disk_prefix_len(parts[j].name) != plen ||
                strncmp(parts[i].name, parts[j].name, plen))
                continue;
            snprintf(ro, size, "/dev/%.31s", parts[i].name);
            snprintf(rw, size, "/dev/%.31s", parts[j].name);
            return 1;
        }
    }
    return 0;
}

static void disk_not_found(const char *what)
{
    fprintf(stderr, "fs_init: %s\n", what);
    fprintf(stderr, "fs_init: block devices found:");
    if (nparts == 0)
        fprintf(stderr, " none");
    fprintf(stderr, "\n");
    for (int i = 0; i < nparts; i++) {
        const char *t = parts[i].type == FS_SQUASHFS ? "squashfs" :
                        parts[i].type == FS_EXT2 ? "ext2" : "-";
        fprintf(stderr, "fs_init:   /dev/%-10s %s\n", parts[i].name, t);
    }
    fprintf(stderr,
            "fs_init: disk drivers in this kernel: %s\n"
            "fs_init: Is the disk image attached to the virtual machine, to a\n"
            "fs_init: controller of this type? In VirtualBox: Settings > Storage.\n"
            "fs_init: Or turn on the driver of your controller in 'make menuconfig'\n"
            "fs_init: (Kernel drivers) and build again.\n",
            DISK_DRIVERS);
    halt();
}

/* Wait until the devices exist: the cmdline ones, or a squashfs + ext2
 * pair found by content. */
static void wait_for_disk(char *ro, char *rw, size_t size, int have_cmdline)
{
    char buf[16];
    int wait_s = 10;
    if (get_cmdline_arg("fs_wait", buf, sizeof(buf)))
        wait_s = atoi(buf);

    for (long waited = 0;; waited += WAIT_STEP_MS) {
        if (have_cmdline) {
            if (access(ro, F_OK) == 0 && access(rw, F_OK) == 0)
                return;
        } else {
            scan_partitions();
            if (find_disk(ro, rw, size))
                return;
        }
        if (waited >= wait_s * 1000L)
            break;
        if (waited == 0)
            printf("fs_init: waiting for the disk (%d s)...\n", wait_s);
        sleep_ms(WAIT_STEP_MS);
    }

    if (have_cmdline) {
        char msg[320];
        scan_partitions();
        snprintf(msg, sizeof(msg), "%s or %s (from the kernel cmdline) not found", ro, rw);
        disk_not_found(msg);
    }
    disk_not_found("no disk with a squashfs and an ext2 partition found");
}

static void do_mount(const char *src, const char *dst, const char *type,
                     unsigned long flags, const char *opts)
{
    mkdir(dst, 0755);
    if (mount(src, dst, type, flags, opts) != 0) {
        char msg[192];
        snprintf(msg, sizeof(msg), "mount %s (%s) on %s failed", src, type, dst);
        fatal(msg);
    }
}

int main(void)
{
    do_mount("devtmpfs", "/dev", "devtmpfs", 0, NULL);
    setup_console();
    printf("fs_init: starting\n");

    do_mount("proc", "/proc", "proc", 0, NULL);
    read_cmdline();

    char ro_dev[64], rw_dev[64];
    int from_cmdline = get_cmdline_arg("squashfs_dev", ro_dev, sizeof(ro_dev)) != NULL;
    if (get_cmdline_arg("rw_dev", rw_dev, sizeof(rw_dev)) != NULL) {
        errno = 0;
        if (!from_cmdline)
            fatal("rw_dev= on the kernel cmdline needs squashfs_dev= too");
    } else if (from_cmdline) {
        errno = 0;
        fatal("squashfs_dev= on the kernel cmdline needs rw_dev= too");
    }
    wait_for_disk(ro_dev, rw_dev, sizeof(ro_dev), from_cmdline);

    /* The same paths as in the new root, so /proc/mounts shows the
     * overlay options with the right names after the move below. */
    mkdir("/mnt", 0755);
    do_mount(ro_dev, "/mnt/ro", "squashfs", MS_RDONLY, NULL);
    do_mount(rw_dev, "/mnt/rw", "ext2", 0, NULL);

    mkdir("/mnt/rw/rw_root", 0755);
    mkdir("/mnt/rw/work", 0755);
    do_mount("overlay", NEW_ROOT, "overlay", 0,
             "lowerdir=/mnt/ro,upperdir=/mnt/rw/rw_root,workdir=/mnt/rw/work");
    printf("fs_init: overlay root ready (%s + %s)\n", ro_dev, rw_dev);

    /* Hand over the two layers to the new root (/mnt/ro, /mnt/rw). Left in
     * the initramfs they would be out of reach after switch_root, and the
     * ext2 partition could not be remounted read-only at shutdown: it
     * would never be marked clean. */
    mkdir(NEW_ROOT "/mnt", 0755);
    mkdir(NEW_ROOT "/mnt/ro", 0755);
    mkdir(NEW_ROOT "/mnt/rw", 0755);
    if (mount("/mnt/ro", NEW_ROOT "/mnt/ro", NULL, MS_MOVE, NULL) != 0)
        fatal("moving the squashfs to /mnt/ro failed");
    if (mount("/mnt/rw", NEW_ROOT "/mnt/rw", NULL, MS_MOVE, NULL) != 0)
        fatal("moving the ext2 partition to /mnt/rw failed");

    /* Hand over /dev to the new root; /proc is remounted by inittab. */
    mkdir(NEW_ROOT "/dev", 0755);
    if (mount("/dev", NEW_ROOT "/dev", NULL, MS_MOVE, NULL) != 0)
        fatal("moving /dev to new root failed");
    umount2("/proc", MNT_DETACH);

    execl(NEW_ROOT "/bin/switch_root", "switch_root", NEW_ROOT, "/bin/init", (char *)NULL);
    fatal("exec switch_root failed");
    return 1;
}
