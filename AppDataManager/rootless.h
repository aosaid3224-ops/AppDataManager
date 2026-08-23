#ifndef ROOTLESS_H
#define ROOTLESS_H

#include <sys/stat.h>
#include <string.h>

static inline const char *ROOT_PATH(const char *path) {
    if (access("/var/jb", F_OK) == 0) {
        static char newPath[PATH_MAX];
        snprintf(newPath, sizeof(newPath), "/var/jb%s", path);
        return newPath;
    }
    return path;
}

static inline NSString *ROOT_PATH_NS(NSString *path) {
    if (access("/var/jb", F_OK) == 0) {
        return [@"/var/jb" stringByAppendingPathComponent:path];
    }
    return path;
}

#endif
