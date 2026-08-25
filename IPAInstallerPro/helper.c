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

    // Execute target command with original environment
    execve(argv[1], &argv[1], envp);

    // If execve fails, report error and exit
    fprintf(stderr, "execve failed for %s: errno=%d\n", argv[1], errno);
    return 1;
}
