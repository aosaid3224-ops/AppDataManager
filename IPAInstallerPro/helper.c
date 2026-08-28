//
// helper.c
// IPA Installer Pro Helper
//
// v2.3 — Robust root execution for Dopamine 3.0
//

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <errno.h>
#include <string.h>
#include <copyfile.h>

int main(int argc, char *argv[], char *envp[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <command> [args...]\n", argv[0]);
        return 1;
    }

    // Attempt to gain root privileges
    uid_t original_uid = getuid();

    if (setuid(0) != 0) {
        // setuid failed — try seteuid for Dopamine 3.0
        if (seteuid(0) != 0) {
            fprintf(stderr, "Warning: Could not acquire root (errno=%d). Running as uid=%d\n", errno, original_uid);
        } else {
            setegid(0);
        }
    } else {
        setgid(0);
        seteuid(0);
        setegid(0);
    }

    // Never execute privileged installer commands unless the helper actually
    // acquired effective UID 0. Returning success here would make the caller
    // believe that signing/uicache/chown ran with root while it did not.
    uid_t current_uid = getuid();
    uid_t current_euid = geteuid();
    if (current_euid != 0) {
        fprintf(stderr, "ERROR: Could not acquire root (uid=%d, euid=%d)\n", current_uid, current_euid);
        return 126;
    }

    // A verified tree-copy primitive for application bundles. This avoids
    // relying on platform-specific cp recursion behavior for framework
    // metadata/resources while keeping the operation inside the root helper.
    if (argc == 4 && strcmp(argv[1], "--copy-tree") == 0) {
        int copyFlags = COPYFILE_ALL | COPYFILE_RECURSIVE | COPYFILE_NOFOLLOW_SRC;
#ifdef COPYFILE_CLONE
        copyFlags |= COPYFILE_CLONE;
#endif
        int copyResult = copyfile(argv[2], argv[3], NULL, copyFlags);
        if (copyResult != 0) {
            int cloneError = errno;
            // APFS clone is an optimization only. If the source/destination
            // filesystem cannot clone, preserve the proven copyfile path.
            if (cloneError == ENOTSUP || cloneError == EINVAL || cloneError == EXDEV) {
                fprintf(stderr, "copyfile clone unavailable; using regular copy errno=%d\n", cloneError);
                copyResult = copyfile(argv[2], argv[3], NULL,
                                      COPYFILE_ALL | COPYFILE_RECURSIVE | COPYFILE_NOFOLLOW_SRC);
            }
        }
        if (copyResult != 0) {
            fprintf(stderr, "copyfile failed: %s -> %s errno=%d\n", argv[2], argv[3], errno);
            return 1;
        }
        return 0;
    }

    // Execute target command with original environment
    execve(argv[1], &argv[1], envp);

    // If execve fails, report error and exit
    fprintf(stderr, "execve failed for %s: errno=%d\n", argv[1], errno);
    return 1;
}
