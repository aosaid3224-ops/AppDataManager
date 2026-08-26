#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)installApplication:(NSURL *)path withOptions:(NSDictionary *)options error:(NSError **)error;
@end

static int fail(NSString *message, NSString *statusPath) {
    NSString *text = message ?: @"system installer failed";
    fprintf(stderr, "%s\n", text.UTF8String);
    if (statusPath.length > 0) [text writeToFile:statusPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    return 1;
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        if (argc != 4) return fail(@"Usage: ipainstallerpro_systeminstall <ipa-path> <bundle-id> <status-file>", nil);
        NSString *ipaPath = [NSString stringWithUTF8String:argv[1]];
        NSString *bundleID = [NSString stringWithUTF8String:argv[2]];
        NSString *statusPath = [NSString stringWithUTF8String:argv[3]];
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:ipaPath]) {
            return fail([NSString stringWithFormat:@"IPA does not exist: %@", ipaPath], statusPath);
        }
        Class workspaceClass = objc_getClass("LSApplicationWorkspace");
        if (!workspaceClass) return fail(@"LSApplicationWorkspace class unavailable", statusPath);
        LSApplicationWorkspace *workspace = [workspaceClass performSelector:@selector(defaultWorkspace)];
        if (!workspace) return fail(@"LSApplicationWorkspace defaultWorkspace unavailable", statusPath);
        NSError *error = nil;
        BOOL accepted = NO;
        @try {
            NSDictionary *options = bundleID.length > 0 ? @{ @"CFBundleIdentifier": bundleID } : @{};
            accepted = [workspace installApplication:[NSURL fileURLWithPath:ipaPath]
                                         withOptions:options
                                               error:&error];
        } @catch (NSException *exception) {
            return fail([NSString stringWithFormat:@"installApplication exception: %@", exception.reason ?: @"unknown"], statusPath);
        }
        if (!accepted) {
            return fail([NSString stringWithFormat:@"installApplication rejected IPA: %@", error.localizedDescription ?: @"no NSError details"], statusPath);
        }
        [@"system install accepted" writeToFile:statusPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        printf("system install accepted: %s bundleID=%s\n", ipaPath.UTF8String, bundleID.UTF8String);
        return 0;
    }
}

