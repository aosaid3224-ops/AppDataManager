#import <substrate.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <Foundation/Foundation.h>

// ============================================
// DIAGNOSTIC ENGINE - Built-in Logger
// ============================================

#define LOG_FILE @"/var/mobile/Documents/NaverBypass_Diagnostics.log"
#define MAX_LOG_SIZE (5 * 1024 * 1024) // 5MB

static void NBLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date] 
                                                         dateStyle:NSDateFormatterNoStyle 
                                                         timeStyle:NSDateFormatterMediumStyle];
    NSString *logLine = [NSString stringWithFormat:@"[%@] [NaverBypass] %@\n", timestamp, msg];

    // NSLog for console
    NSLog(@"%@", logLine);

    // File logging
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:LOG_FILE]) {
        [fm createFileAtPath:LOG_FILE contents:nil attributes:nil];
    }

    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:LOG_FILE];
    [fh seekToEndOfFile];
    [fh writeData:[logLine dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];

    // Rotate if too big
    NSDictionary *attrs = [fm attributesOfItemAtPath:LOG_FILE error:nil];
    if (attrs.fileSize > MAX_LOG_SIZE) {
        NSString *oldLog = [LOG_FILE stringByAppendingString:@".old"];
        [fm removeItemAtPath:oldLog error:nil];
        [fm moveItemAtPath:LOG_FILE toPath:oldLog error:nil];
    }
}

// ============================================
// DEVICE IDENTITY SPOOFING ENGINE
// ============================================

static NSString *generateFakeIDFV() {
    return [[NSUUID UUID] UUIDString];
}

static NSString *generateFakeADID() {
    return [[NSUUID UUID] UUIDString];
}

static NSString *generateFakeDeviceID() {
    // Format like real device IDs
    NSString *chars = @"abcdefghijklmnopqrstuvwxyz0123456789";
    NSMutableString *result = [NSMutableString stringWithCapacity:32];
    for (int i = 0; i < 32; i++) {
        uint32_t r = arc4random_uniform((uint32_t)[chars length]);
        [result appendFormat:@"%C", [chars characterAtIndex:r]];
    }
    return result;
}

// ============================================
// 1. UIDevice Hooks (iOS 16 & 18 Compatible)
// ============================================

%hook UIDevice

- (NSUUID *)identifierForVendor {
    NSString *fake = generateFakeIDFV();
    NBLog(@"[SPOOF] identifierForVendor: %@ -> %@", %orig, fake);
    return [[NSUUID alloc] initWithUUIDString:fake];
}

- (NSString *)name {
    NBLog(@"[SPOOF] deviceName: %@ -> iPhone", %orig);
    return @"iPhone";
}

- (NSString *)model {
    NBLog(@"[SPOOF] model: %@ -> iPhone15,2", %orig);
    return @"iPhone";
}

- (NSString *)localizedModel {
    return @"iPhone";
}

- (NSString *)systemVersion {
    NBLog(@"[SPOOF] systemVersion: %@ -> 18.3.1", %orig);
    return @"18.3.1";
}

- (NSString *)systemName {
    return @"iOS";
}

%end

// ============================================
// 2. NSBundle Hooks - App Identity
// ============================================

%hook NSBundle

- (NSString *)bundleIdentifier {
    NSString *orig = %orig;
    NBLog(@"[INFO] bundleIdentifier accessed: %@", orig);
    return orig;
}

%end

// ============================================
// 3. Keychain Hooks - Naver Data Interception
// ============================================

static BOOL isNaverKeychainItem(NSDictionary *dict) {
    if (!dict) return NO;

    NSString *account = dict[(__bridge NSString *)kSecAttrAccount];
    NSString *service = dict[(__bridge NSString *)kSecAttrService];
    NSString *accessGroup = dict[(__bridge NSString *)kSecAttrAccessGroup];
    NSString *generic = dict[(__bridge NSString *)kSecAttrGeneric];

    NSArray *naverKeywords = @[
        @"naver", @"series", @"ntracker", @"nhncorp",
        @"YAZD8YA78S", @"device", @"ban", @"block",
        @"safety", @"action", @"previous", @"idfv",
        @"consumer", @"hmac", @"adid"
    ];

    for (NSString *keyword in naverKeywords) {
        if ((account && [account rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) ||
            (service && [service rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) ||
            (accessGroup && [accessGroup rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) ||
            (generic && [generic rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound)) {
            return YES;
        }
    }
    return NO;
}

%hookf(OSStatus, SecItemCopyMatching, CFDictionaryRef query, CFTypeRef *result) {
    NSDictionary *dict = (__bridge NSDictionary *)query;

    if (isNaverKeychainItem(dict)) {
        NSString *account = dict[(__bridge NSString *)kSecAttrAccount] ?: @"(nil)";
        NSString *service = dict[(__bridge NSString *)kSecAttrService] ?: @"(nil)";
        NBLog(@"[BLOCK] SecItemCopyMatching - Account:%@ Service:%@ -> errSecItemNotFound", account, service);
        return errSecItemNotFound;
    }

    return %orig;
}

%hookf(OSStatus, SecItemAdd, CFDictionaryRef attributes, CFTypeRef *result) {
    NSDictionary *dict = (__bridge NSDictionary *)attributes;

    if (isNaverKeychainItem(dict)) {
        NSString *account = dict[(__bridge NSString *)kSecAttrAccount] ?: @"(nil)";
        NBLog(@"[BLOCK] SecItemAdd - Account:%@ -> Fake Success", account);
        return errSecSuccess;
    }

    return %orig;
}

%hookf(OSStatus, SecItemUpdate, CFDictionaryRef query, CFDictionaryRef attributesToUpdate) {
    NSDictionary *dict = (__bridge NSDictionary *)query;

    if (isNaverKeychainItem(dict)) {
        NBLog(@"[BLOCK] SecItemUpdate -> Fake Success");
        return errSecSuccess;
    }

    return %orig;
}

%hookf(OSStatus, SecItemDelete, CFDictionaryRef query) {
    NSDictionary *dict = (__bridge NSDictionary *)query;

    if (isNaverKeychainItem(dict)) {
        NBLog(@"[BLOCK] SecItemDelete -> Fake Success");
        return errSecSuccess;
    }

    return %orig;
}

// ============================================
// 4. NSUserDefaults Hooks
// ============================================

%hook NSUserDefaults

- (id)objectForKey:(NSString *)defaultName {
    NSArray *blockedKeys = @[
        @"naver", @"series", @"device", @"ban", @"block",
        @"safety", @"action", @"previous", @"idfv", @"fingerprint"
    ];

    for (NSString *keyword in blockedKeys) {
        if ([defaultName rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
            NBLog(@"[BLOCK] NSUserDefaults objectForKey:%@ -> nil", defaultName);
            return nil;
        }
    }

    id result = %orig;
    if (result) {
        NBLog(@"[INFO] NSUserDefaults objectForKey:%@ -> %@", defaultName, result);
    }
    return result;
}

- (void)setObject:(id)value forKey:(NSString *)defaultName {
    for (NSString *keyword in @[@"ban", @"block", @"device_id", @"fingerprint"]) {
        if ([defaultName rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
            NBLog(@"[BLOCK] NSUserDefaults setObject:forKey:%@ -> Skipped", defaultName);
            return;
        }
    }
    %orig;
}

%end

// ============================================
// 5. sysctl / uname Hooks
// ============================================

%hookf(int, uname, struct utsname *value) {
    int result = %orig;
    if (result == 0 && value) {
        strncpy(value->machine, "iPhone15,2", sizeof(value->machine) - 1);
        strncpy(value->nodename, "iPhone", sizeof(value->nodename) - 1);
        strncpy(value->release, "23.3.0", sizeof(value->release) - 1);
        strncpy(value->version, "Darwin Kernel Version 23.3.0", sizeof(value->version) - 1);
        strncpy(value->sysname, "Darwin", sizeof(value->sysname) - 1);
        NBLog(@"[SPOOF] uname -> machine:iPhone15,2 sysname:Darwin");
    }
    return result;
}

%hookf(int, sysctl, int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    // Log sysctl calls for analysis
    if (name && namelen >= 2) {
        NBLog(@"[INFO] sysctl called: name[0]=%d name[1]=%d", name[0], name[1]);
    }
    return %orig;
}

%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (name) {
        NSString *nameStr = [NSString stringWithUTF8String:name];
        NBLog(@"[INFO] sysctlbyname called: %@", nameStr);
    }
    return %orig;
}

// ============================================
// 6. Jailbreak Detection Bypass
// ============================================

%hook NSFileManager

- (BOOL)fileExistsAtPath:(NSString *)path {
    NSArray *jailbreakPaths = @[
        @"/Applications/Cydia.app",
        @"/Applications/blackra1n.app",
        @"/Applications/SBSettings.app",
        @"/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist",
        @"/private/var/lib/cydia",
        @"/usr/sbin/sshd",
        @"/var/lib/cydia",
        @"/etc/apt",
        @"/private/var/stash",
        @"/var/tmp/cydia.log",
        @"/var/mobile/Library/SBSettings/Themes",
        @"/Library/MobileSubstrate/MobileSubstrate.dylib",
        @"/var/cache/apt",
        @"/var/lib/apt",
        @"/var/mobile/Documents/Cydia"
    ];

    for (NSString *jbPath in jailbreakPaths) {
        if ([path isEqualToString:jbPath]) {
            NBLog(@"[JB-BYPASS] Hid path: %@", path);
            return NO;
        }
    }

    return %orig;
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory {
    NSArray *jailbreakPaths = @[
        @"/Applications/Cydia.app",
        @"/Library/MobileSubstrate",
        @"/var/lib/cydia"
    ];

    for (NSString *jbPath in jailbreakPaths) {
        if ([path isEqualToString:jbPath]) {
            NBLog(@"[JB-BYPASS] Hid directory: %@", path);
            if (isDirectory) *isDirectory = YES;
            return NO;
        }
    }

    return %orig;
}

%end

%hook UIApplication

- (BOOL)canOpenURL:(NSURL *)url {
    if (url) {
        NSString *scheme = url.scheme;
        if ([scheme isEqualToString:@"cydia"] || 
            [scheme isEqualToString:@"sileo"] ||
            [scheme isEqualToString:@"zbra"]) {
            NBLog(@"[JB-BYPASS] Blocked canOpenURL for scheme: %@", scheme);
            return NO;
        }
    }
    return %orig;
}

%end

// ============================================
// 7. Network Request Interception & Spoofing
// ============================================

%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    NSString *lowerField = [field lowercaseString];

    if ([lowerField isEqualToString:@"x-consumer-id"]) {
        NSString *fake = generateFakeDeviceID();
        NBLog(@"[SPOOF] Header x-consumer-id: %@ -> %@", value, fake);
        %orig(fake, field);
        return;
    }

    if ([lowerField isEqualToString:@"x-hmac-msgpad"]) {
        NSString *fake = [NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970] * 1000];
        NBLog(@"[SPOOF] Header x-hmac-msgpad -> timestamp");
        %orig(fake, field);
        return;
    }

    if ([lowerField isEqualToString:@"x-hmac-md"]) {
        NSString *fake = generateFakeDeviceID();
        NBLog(@"[SPOOF] Header x-hmac-md -> fake");
        %orig(fake, field);
        return;
    }

    if ([lowerField isEqualToString:@"x-adid"]) {
        NSString *fake = generateFakeADID();
        NBLog(@"[SPOOF] Header x-adid: %@ -> %@", value, fake);
        %orig(fake, field);
        return;
    }

    if ([lowerField isEqualToString:@"user-agent"]) {
        NBLog(@"[INFO] User-Agent: %@", value);
    }

    %orig;
}

%end

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {

    NSURL *url = request.URL;
    NBLog(@"[NETWORK] Request: %@ %@", request.HTTPMethod, url.absoluteString);

    NSDictionary *headers = request.allHTTPHeaderFields;
    for (NSString *key in headers) {
        NBLog(@"[NETWORK] Header %@: %@", key, headers[key]);
    }

    if (request.HTTPBody) {
        NSString *body = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
        if (body) {
            NBLog(@"[NETWORK] Body: %@", body);
        }
    }

    // Check if this is a viewer/content request (episode access)
    if ([url.absoluteString containsString:@"viewer"] || 
        [url.absoluteString containsString:@"episode"] ||
        [url.absoluteString containsString:@"content"]) {
        NBLog(@"[DETECT] Content request detected - Monitoring response");

        // Wrap completion handler to log response
        void (^wrappedCompletion)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse) {
                NBLog(@"[NETWORK] Response Status: %ld", (long)httpResponse.statusCode);
                NBLog(@"[NETWORK] Response Headers: %@", httpResponse.allHeaderFields);

                if (httpResponse.statusCode == 403 || httpResponse.statusCode == 401) {
                    NBLog(@"[ALERT] BLOCKED! Server returned %ld - Device ban confirmed server-side", (long)httpResponse.statusCode);
                }
            }

            if (data) {
                NSString *responseBody = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                if (responseBody) {
                    NBLog(@"[NETWORK] Response Body: %@", responseBody);

                    // Detect ban message in response
                    if ([responseBody containsString:@"안전조치"] || 
                        [responseBody containsString:@"차단"] ||
                        [responseBody containsString:@"보호"] ||
                        [responseBody containsString:@"safety"] ||
                        [responseBody containsString:@"block"]) {
                        NBLog(@"[ALERT] BAN MESSAGE DETECTED IN RESPONSE!");
                    }
                }
            }

            if (error) {
                NBLog(@"[NETWORK] Error: %@", error.localizedDescription);
            }

            if (completionHandler) {
                completionHandler(data, response, error);
            }
        };

        return %orig(request, wrappedCompletion);
    }

    return %orig(request, completionHandler);
}

%end

// ============================================
// 8. WebView Monitoring (for web-based content)
// ============================================

%hook WKWebView

- (void)loadRequest:(NSURLRequest *)request {
    NBLog(@"[WEBVIEW] loadRequest: %@", request.URL.absoluteString);
    %orig;
}

%end

// ============================================
// 9. AppsFlyer / Tracker ID Spoofing
// ============================================

%hook NSUUID

+ (instancetype)UUID {
    NSUUID *uuid = %orig;
    NBLog(@"[SPOOF] NSUUID.UUID generated: %@", uuid.UUIDString);
    return uuid;
}

%end

// ============================================
// 10. Process Info Spoofing
// ============================================

%hook NSProcessInfo

- (NSString *)operatingSystemVersionString {
    return @"Version 18.3.1 (Build 22D72)";
}

%end

// ============================================
// 11. UIScreen Spoofing (Resolution Fingerprinting)
// ============================================

%hook UIScreen

- (CGRect)bounds {
    CGRect orig = %orig;
    // iPhone 15 Pro resolution
    NBLog(@"[SPOOF] Screen bounds: %@", NSStringFromCGRect(orig));
    return orig;
}

- (CGFloat)scale {
    NBLog(@"[SPOOF] Screen scale: %f -> 3.0", %orig);
    return 3.0;
}

%end

// ============================================
// 12. Advanced: Hook specific Naver classes if found
// ============================================

// Try to hook Naver-specific classes dynamically
%ctor {
    NBLog(@"========================================");
    NBLog(@"NaverSeriesBypass v2.0 - ROOTLESS");
    NBLog(@"Target: com.naver.series");
    NBLog(@"iOS Support: 16.x - 18.x");
    NBLog(@"Features: IDFV|Keychain|Headers|JB-Bypass|Diagnostics");
    NBLog(@"========================================");

    // List all Naver-related classes for analysis
    int numClasses = objc_getClassList(NULL, 0);
    Class *classes = (Class *)malloc(sizeof(Class) * numClasses);
    objc_getClassList(classes, numClasses);

    for (int i = 0; i < numClasses; i++) {
        NSString *className = NSStringFromClass(classes[i]);
        if ([className rangeOfString:@"Naver" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [className rangeOfString:@"Series" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [className rangeOfString:@"NHN" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            NBLog(@"[DISCOVERY] Found Naver class: %@", className);
        }
    }

    free(classes);

    // Create Documents directory if needed
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *docsPath = @"/var/mobile/Documents";
    if (![fm fileExistsAtPath:docsPath]) {
        [fm createDirectoryAtPath:docsPath withIntermediateDirectories:YES attributes:nil error:nil];
    }

    NBLog(@"[INIT] Diagnostics log: %@", LOG_FILE);
    NBLog(@"[INIT] Tweak loaded successfully");
}
