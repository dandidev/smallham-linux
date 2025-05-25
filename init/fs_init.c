#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <errno.h>
#include <dirent.h>
#include <string.h>
#include <fcntl.h> 
#include <sys/ioctl.h>
#include <linux/loop.h>
#include <fcntl.h>

void list_directory_contents(const char *path) {
    DIR *d;
    struct dirent *dir;
    d = opendir(path);
    if (d) {
        printf("Contents of %s:\n", path);
        while ((dir = readdir(d)) != NULL) {
            printf("%s\n", dir->d_name);
        }
        closedir(d);
    } else {
        perror("Could not open directory");
    }
}

char* get_cmdline_arg(const char* key) {
    static char value[128];
    FILE *f = fopen("/proc/cmdline", "r");
    if (!f) return NULL;

    char buf[1024];
    if (fgets(buf, sizeof(buf), f)) {
        char *start = strstr(buf, key);
        if (start) {
            start += strlen(key);
            if (*start == '=') {
                start++;
                sscanf(start, "%127s", value);
                char *end = strchr(value, ' ');
                if (end) *end = '\0';
                fclose(f);
                return value;
            }
        }
    }

    fclose(f);
    return NULL;
}

int main(int argc, char *argv[]) {
    printf("Run fs_init\n");

    mkdir("/proc", 0555);
    if (mount("proc", "/proc", "proc", 0, NULL) != 0) {
        perror("mount /proc failed");
        return 1;
    }
    printf("procfs mounted on /proc\n");
    
    mkdir("/dev", 0755);
    if (mount("devtmpfs", "/dev", "devtmpfs", 0, NULL) != 0) {
        perror("Failed to mount devtmpfs");
        return 1;
    }
    printf("devtmpfs mounted on /dev\n");

    
    char *squashfs_dev = get_cmdline_arg("squashfs_dev");
    if (!squashfs_dev) {
        fprintf(stderr, "Missing squashfs_dev= in kernel cmdline\n");
        return 1;
    }
    mkdir("/ro_root", 0755);
    if (mount(squashfs_dev, "/ro_root", "squashfs", MS_RDONLY, NULL) != 0) {
        perror("SquashFS mount to /ro_root failed");
        return 1;
    }

    char *rw_dev = get_cmdline_arg("rw_dev");
    if (!rw_dev) {
        fprintf(stderr, "Missing rw_dev= in kernel cmdline\n");
        return 1;
    }
    mkdir("/mnt_overlay", 0755);
    if (mount(rw_dev, "/mnt_overlay", "ext2", 0, NULL)) {
        perror("Root FS mount to /mnt_overlay failed");
        return 1;
    }

    mkdir("/mnt_overlay/rw_root", 0755);
    mkdir("/mnt_overlay/work", 0755);

    mkdir("/overlay_root", 0755);
    printf("/overlay_root created\n");

    char overlay_options[256];
    snprintf(overlay_options, sizeof(overlay_options), "lowerdir=/ro_root,upperdir=/mnt_overlay/rw_root,workdir=/mnt_overlay/work");
    printf("Mounting OverlayFS to / with options: %s\n", overlay_options);
    if (mount("overlay", "/overlay_root", "overlay", 0, overlay_options) != 0) {
        perror("OverlayFS mount failed");
        return 1;
    }
    printf("OverlayFS mounted on /\n");

    //list_directory_contents("/");

    // chdir("/overlay_root");
    // chroot(".");

    // execve("/bin/init", (char *[]){"/bin/init", NULL}, NULL);
    // perror("execve failed");

    close(STDIN_FILENO);
    close(STDOUT_FILENO);
    close(STDERR_FILENO);
    open("/dev/null", O_RDONLY);  // stdin
    open("/dev/null", O_WRONLY);  // stdout
    open("/dev/null", O_WRONLY);  // stderr


    int ret = execve("/overlay_root/bin/switch_root", (char *[]){
        "switch_root",
        "/overlay_root",
        "/bin/init",
        NULL
    }, NULL);
    if (ret < 0) {
        perror("switch_root failed");
        exit(1);
    }

    return 1;
}