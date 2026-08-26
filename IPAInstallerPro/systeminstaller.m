#import <Foundation/Foundation.h>

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)installApplication:(NSURL *)path withOptions:(NSDictionary *)options error:(NSError **)error;
@end

static int fail(NSString *message) {
    fprintf(stderr, "%s\n", message.UTF8String ?: "system installer failed");
    return 1;
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        if (argc != 2) return fail(@"Usage: ipainstallerpro_systeminstall <ipa-path>");
        NSString *ipaPath = [NSString stringWithUTF8String:argv[1]];
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:ipaPath]) {
            return fail([NSString stringWithFormat:@"IPA does not exist: %@", ipaPath]);
        }
        Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
        if (!workspaceClass) return fail(@"LSApplicationWorkspace class unavailable");
        LSApplicationWorkspace *workspace = [workspaceClass defaultWorkspace];
        if (!workspace) return fail(@"LSApplicationWorkspace defaultWorkspace unavailable");
        NSError *error = nil;
        BOOL accepted = NO;
        @try {
            NSDictionary *options = @{};
            accepted = [workspace installApplication:[NSURL fileURLWithPath:ipaPath]
                                         withOptions:options
                                               error:&error];
        } @catch (NSException *exception) {
            return fail([NSString stringWithFormat:@"installApplication exception: %@", exception.reason ?: @"unknown"]);
        }
        if (!accepted) {
            return fail([NSString stringWithFormat:@"installApplication rejected IPA: %@", error.localizedDescription ?: @"no NSError details"]);
        }
        printf("system install accepted: %s\n", ipaPath.UTF8String);
        return 0;
    }
}

