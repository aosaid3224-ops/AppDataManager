//
// SignatureAnalyzer.m
//

#import "SignatureAnalyzer.h"
#import "RootlessManager.h"
#import <spawn.h>

@implementation SignatureInfo
- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"isSigned"] = @(self.isSigned);
    d[@"isAdHocSigned"] = @(self.isAdHocSigned);
    if (self.teamID) d[@"teamID"] = self.teamID;
    if (self.identifier) d[@"identifier"] = self.identifier;
    if (self.authority) d[@"authority"] = self.authority;
    if (self.signatureStatus) d[@"signatureStatus"] = self.signatureStatus;
    if (self.source) d[@"source"] = self.source;
    if (self.parseError) d[@"parseError"] = self.parseError;
    return d;
}
@end

@interface SignatureAnalyzer ()
@property (nonatomic, strong) NSString *ldidPath;
@end

@implementation SignatureAnalyzer

+ (instancetype)sharedAnalyzer {
    static SignatureAnalyzer *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _ldidPath = [[RootlessManager sharedManager] resolvePath:@"/usr/bin/ldid"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:_ldidPath]) {
            _ldidPath = @"ldid"; // fallback to PATH only when the rootless path is unavailable
        }
    }
    return self;
}

- (NSString *)runLdid:(NSString *)arg target:(NSString *)path {
    return [self runCommand:self.ldidPath args:@[arg, path]];
}

- (NSString *)runCommand:(NSString *)cmd args:(NSArray *)args {
    NSMutableArray *cArgs = [NSMutableArray arrayWithObject:cmd];
    [cArgs addObjectsFromArray:args];

    char **argv = (char **)malloc(sizeof(char *) * (cArgs.count + 1));
    for (NSUInteger i = 0; i < cArgs.count; i++) {
        argv[i] = strdup([cArgs[i] UTF8String]);
    }
    argv[cArgs.count] = NULL;

    posix_spawn_file_actions_t action;
    posix_spawn_file_actions_init(&action);

    int outPipe[2];
    pipe(outPipe);
    posix_spawn_file_actions_adddup2(&action, outPipe[1], STDOUT_FILENO);
    posix_spawn_file_actions_adddup2(&action, outPipe[1], STDERR_FILENO);
    posix_spawn_file_actions_addclose(&action, outPipe[0]);

    pid_t pid;
    int status = posix_spawn(&pid, [cmd UTF8String], &action, NULL, argv, NULL);

    for (NSUInteger i = 0; i < cArgs.count; i++) free(argv[i]);
    free(argv);
    posix_spawn_file_actions_destroy(&action);
    close(outPipe[1]);

    if (status != 0) {
        close(outPipe[0]);
        return nil;
    }

    waitpid(pid, &status, 0);

    NSMutableData *data = [NSMutableData data];
    char buffer[4096];
    ssize_t n;
    while ((n = read(outPipe[0], buffer, sizeof(buffer))) > 0) {
        [data appendBytes:buffer length:n];
    }
    close(outPipe[0]);

    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return output;
}

#pragma mark - Signature Analysis

- (SignatureInfo *)analyzeSignatureAtPath:(NSString *)path {
    SignatureInfo *info = [[SignatureInfo alloc] init];
    info.source = @"ldid";

    NSString *output = [self runLdid:@"-d" target:path];
    if (!output || output.length == 0) {
        info.isSigned = NO;
        info.signatureStatus = @"unsigned";
        return info;
    }

    info.isSigned = YES;
    info.signatureStatus = @"signed";

    // Parse ldid -d output
    // Example: "Identifier: com.example.app\nTeamIdentifier: ABC123\n..."
    NSArray *lines = [output componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmed.length == 0) continue;

        if ([trimmed hasPrefix:@"Identifier:"]) {
            info.identifier = [[trimmed substringFromIndex:11] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }
        else if ([trimmed hasPrefix:@"TeamIdentifier:"]) {
            info.teamID = [[trimmed substringFromIndex:15] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }
        else if ([trimmed hasPrefix:@"Authority:"]) {
            info.authority = [[trimmed substringFromIndex:10] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if ([info.authority rangeOfString:@"adhoc" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [info.authority rangeOfString:@"AdHoc" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                info.isAdHocSigned = YES;
            }
        }
    }

    // If no authority found but signed, assume ad-hoc
    if (!info.authority && info.isSigned) {
        info.isAdHocSigned = YES;
        info.authority = @"AdHoc";
    }

    return info;
}

#pragma mark - Entitlement Extraction

- (NSDictionary *)extractEntitlementsAtPath:(NSString *)path {
    NSString *output = [self runLdid:@"-e" target:path];
    if (!output || output.length < 10) return nil;

    // ldid may write diagnostics before the plist because this helper captures
    // stdout and stderr together. Isolate the plist payload instead of treating
    // the whole mixed stream as a property list.
    NSString *plistPayload = output;
    NSRange xmlStart = [output rangeOfString:@"<?xml"];
    NSRange plistEnd = [output rangeOfString:@"</plist>" options:NSBackwardsSearch];
    if (xmlStart.location != NSNotFound && plistEnd.location != NSNotFound &&
        NSMaxRange(plistEnd) > xmlStart.location) {
        plistPayload = [output substringWithRange:NSMakeRange(xmlStart.location,
                                                               NSMaxRange(plistEnd) - xmlStart.location)];
    }

    NSData *data = [plistPayload dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return nil;

    NSError *error = nil;
    id plist = [NSPropertyListSerialization propertyListWithData:data
                                                            options:NSPropertyListImmutable
                                                             format:nil
                                                              error:&error];
    if ([plist isKindOfClass:[NSDictionary class]]) return plist;

    NSLog(@"[SignatureAnalyzer] Could not parse ldid entitlements for %@: %@", path, error.localizedDescription ?: @"unknown format");
    return nil;
}

@end
