#import <Foundation/Foundation.h>
#ifndef ROOTLESS_H
#define ROOTLESS_H

#include <sys/stat.h>
#include <sys/syslimits.h>
#include <unistd.h>
#include <dlfcn.h>
#include <string.h>

static inline const char *SPLibrootJBRoot(void) {
    typedef const char *(*SPJBRootFn)(void);
    SPJBRootFn fn = (SPJBRootFn)dlsym(RTLD_DEFAULT, "libroot_get_jbroot_prefix");
    if (fn) {
        const char *value = fn();
        if (value && value[0] != '\0') return value;
    }
    return NULL;
}

static inline NSString *SPJBRRootPath(NSString *path) {
    if (!path || path.length == 0) return path;
    if ([path hasPrefix:@"/var/containers/"] && [path containsString:@".jbroot-"]) return path;
    const char *prefix = SPLibrootJBRoot();
    if (prefix && prefix[0] != '\0') {
        NSString *root = [NSString stringWithUTF8String:prefix];
        if ([path isEqualToString:root] || [path hasPrefix:[root stringByAppendingString:@"/"]]) return path;
        return [root stringByAppendingPathComponent:path];
    }
    if ([path hasPrefix:@"/var/jb"]) return path;
    struct stat st;
    if (stat("/var/jb", &st) == 0 && S_ISDIR(st.st_mode)) return [@"/var/jb" stringByAppendingPathComponent:path];
    return path;
}

static inline NSString *ROOT_PATH_NS(NSString *path) { return SPJBRRootPath(path); }
static inline const char *ROOT_PATH_C(const char *path) {
    if (!path) return path;
    NSString *resolved = SPJBRRootPath([NSString stringWithUTF8String:path]);
    return resolved.fileSystemRepresentation;
}

#endif
