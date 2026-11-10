/*
 * fs_init - minimal initramfs /init
 *
 * Mounts a read-only squashfs root and a writable ext2 partition,
 * combines them with overlayfs and switch_root's into /bin/init.
 *
 * Kernel cmdline parameters:
 *   squashfs_dev=<dev>   read-only lower layer (e.g. /dev/vda1)
 *   rw_dev=<dev>         writable upper layer, ext2 (e.g. /dev/vda2)
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <unistd.h>

#define NEW_ROOT "/overlay_root"

static char cmdline[1024];

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

/* Do not return: PID 1 exiting would panic and hide the message. */
static void fatal(const char *msg)
{
    if (errno)
        fprintf(stderr, "fs_init: %s: %s\n", msg, strerror(errno));
    else
        fprintf(stderr, "fs_init: %s\n", msg);
    fprintf(stderr, "fs_init: boot halted\n");
    for (;;)
        pause();
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

/* Return the value of a whole-word "key=value" token, or NULL. */
static const char *get_cmdline_arg(const char *key)
{
    static char value[128];
    size_t klen = strlen(key);
    const char *p = cmdline;

    while (*p) {
        while (*p == ' ' || *p == '\n')
            p++;
        const char *end = p + strcspn(p, " \n");
        if ((size_t)(end - p) > klen && !strncmp(p, key, klen) && p[klen] == '=') {
            size_t vlen = end - (p + klen + 1);
            if (vlen >= sizeof(value))
                vlen = sizeof(value) - 1;
            memcpy(value, p + klen + 1, vlen);
            value[vlen] = '\0';
            return value;
        }
        p = end;
    }
    return NULL;
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

    const char *ro_dev = get_cmdline_arg("squashfs_dev");
    if (!ro_dev)
        fatal("missing squashfs_dev= on kernel cmdline");
    do_mount(ro_dev, "/ro_root", "squashfs", MS_RDONLY, NULL);

    const char *rw_dev = get_cmdline_arg("rw_dev");
    if (!rw_dev)
        fatal("missing rw_dev= on kernel cmdline");
    do_mount(rw_dev, "/mnt_overlay", "ext2", 0, NULL);

    mkdir("/mnt_overlay/rw_root", 0755);
    mkdir("/mnt_overlay/work", 0755);
    do_mount("overlay", NEW_ROOT, "overlay", 0,
             "lowerdir=/ro_root,upperdir=/mnt_overlay/rw_root,workdir=/mnt_overlay/work");
    printf("fs_init: overlay root ready (%s + %s)\n", ro_dev, rw_dev);

    /* Hand over /dev to the new root; /proc is remounted by inittab. */
    mkdir(NEW_ROOT "/dev", 0755);
    if (mount("/dev", NEW_ROOT "/dev", NULL, MS_MOVE, NULL) != 0)
        fatal("moving /dev to new root failed");
    umount2("/proc", MNT_DETACH);

    execl(NEW_ROOT "/bin/switch_root", "switch_root", NEW_ROOT, "/bin/init", (char *)NULL);
    fatal("exec switch_root failed");
    return 1;
}
