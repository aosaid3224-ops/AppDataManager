#import "ExperimentalTrustBackend.h"
#import "SignatureAnalyzer.h"
#import "MachOAnalyzer.h"
#import "ForensicRegistrationProbe.h"
#import "RuntimeEnvironment.h"

@implementation ExperimentalTrustBackend

- (NSString *)backendName { return @"ExperimentalTrustBackend"; }

- (NSDictionary *)embeddedProvisioningEvidenceAtPath:(NSString *)appPath present:(BOOL *)present {
    NSString *path = [appPath stringByAppendingPathComponent:@"embedded.mobileprovision"];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (present) *present = (data.length > 0);
    if (!data.length) return @{};

    NSData *startMarker = [NSData dataWithBytes:"<plist" length:6];
    NSData *endMarker = [NSData dataWithBytes:"</plist>" length:8];
    NSRange start = [data rangeOfData:startMarker options:0 range:NSMakeRange(0, data.length)];
    if (start.location == NSNotFound) return @{ @"profilePath": path, @"present": @YES, @"plistDecoded": @NO, @"parseState": @"UNKNOWN" };
    NSUInteger afterStart = NSMaxRange(start);
    NSRange end = [data rangeOfData:endMarker options:0 range:NSMakeRange(afterStart, data.length - afterStart)];
    if (end.location == NSNotFound || end.location <= start.location) return @{ @"profilePath": path, @"present": @YES, @"plistDecoded": @NO, @"parseState": @"UNKNOWN" };

    NSData *plistData = [data subdataWithRange:NSMakeRange(start.location, NSMaxRange(end) - start.location)];
    NSError *error = nil;
    NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:plistData options:NSPropertyListImmutable format:NULL error:&error];
    if (![plist isKindOfClass:[NSDictionary class]]) {
        return @{ @"profilePath": path, @"present": @YES, @"plistDecoded": @NO, @"parseState": @"UNKNOWN", @"parseError": error.localizedDescription ?: @"plist decode failed" };
    }

    NSDictionary *profileEntitlements = [plist[@"Entitlements"] isKindOfClass:[NSDictionary class]] ? plist[@"Entitlements"] : @{};
    NSArray *devices = [plist[@"ProvisionedDevices"] isKindOfClass:[NSArray class]] ? plist[@"ProvisionedDevices"] : @[];
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    result[@"profilePath"] = path;
    result[@"present"] = @YES;
    result[@"plistDecoded"] = @YES;
    result[@"parseState"] = @"PRESENT";
    result[@"name"] = plist[@"Name"] ?: @"UNKNOWN";
    result[@"teamIdentifier"] = [plist[@"TeamIdentifier"] isKindOfClass:[NSArray class]] ? plist[@"TeamIdentifier"] : @[];
    result[@"applicationIdentifier"] = profileEntitlements[@"application-identifier"] ?: @"UNKNOWN";
    result[@"getTaskAllow"] = profileEntitlements[@"get-task-allow"] ?: @"UNKNOWN";
    result[@"provisionsAllDevices"] = plist[@"ProvisionsAllDevices"] ?: @"UNKNOWN";
    result[@"provisionedDeviceCount"] = @(devices.count);
    result[@"expirationDate"] = [plist[@"ExpirationDate"] description] ?: @"UNKNOWN";
    result[@"entitlements"] = profileEntitlements;
    return result;
}

- (TrustBackendResult *)evaluateApplicationAtPath:(NSString *)appPath bundleID:(NSString *)bundleID {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *infoPath = [appPath stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath] ?: @{};
    NSString *executableName = info[@"CFBundleExecutable"];
    NSString *executablePath = executableName.length ? [appPath stringByAppendingPathComponent:executableName] : @"";

    BOOL appExists = appPath.length && [fm fileExistsAtPath:appPath isDirectory:NULL];
    BOOL executableExists = executablePath.length && [fm isExecutableFileAtPath:executablePath];
    SignatureInfo *signature = executableExists ? [[SignatureAnalyzer sharedAnalyzer] analyzeSignatureAtPath:executablePath] : nil;
    MachOAnalysisResult *machO = executableExists ? [[MachOAnalyzer sharedAnalyzer] analyzeFileAtPath:executablePath] : nil;
    NSDictionary *entitlements = executableExists ? [[SignatureAnalyzer sharedAnalyzer] extractEntitlementsAtPath:executablePath] : @{};
    NSDictionary *registration = bundleID.length ? [[ForensicRegistrationProbe sharedProbe] launchServicesFactsForBundleID:bundleID] : @{};
    RuntimeEnvironment *runtime = [RuntimeEnvironment sharedEnvironment];

    BOOL profilePresent = NO;
    NSDictionary *profile = appExists ? [self embeddedProvisioningEvidenceAtPath:appPath present:&profilePresent] : @{};
    NSString *signatureEvidence = signature ? (signature.isSigned ? @"PRESENT" : @"ABSENT") : @"UNKNOWN";
    NSString *registrationEvidence = registration.count ? ([registration[@"registered"] boolValue] ? @"PRESENT" : @"ABSENT") : @"UNKNOWN";
    NSString *runtimeEvidence = runtime.bootstrapPath.length || runtime.jailbreakType != SpiderJailbreakTypeUnknown ? @"JAILBREAK-LAUNCHABLE" : @"UNKNOWN";
    NSString *profileEvidence = profilePresent ? (profile[@"plistDecoded"] ? @"PRESENT" : @"UNKNOWN") : @"ABSENT";
    NSString *entitlementEvidence = entitlements.count ? @"PRESENT" : @"UNKNOWN";
    NSString *stockEvidence = @"UNKNOWN";
    NSString *persistentEvidence = @"UNKNOWN";

    NSMutableDictionary *evidence = [NSMutableDictionary dictionary];
    evidence[@"bundleID"] = bundleID ?: @"UNKNOWN";
    evidence[@"applicationPath"] = appPath ?: @"UNKNOWN";
    evidence[@"executable"] = executableName ?: @"UNKNOWN";
    evidence[@"signature"] = signatureEvidence;
    evidence[@"codeDirectory"] = machO ? (machO.hasCodeSignature ? @"PRESENT" : @"ABSENT") : @"UNKNOWN";
    evidence[@"cdHash"] = signature.identifier ?: @"UNKNOWN";
    evidence[@"teamIdentifier"] = signature.teamID ?: @"UNKNOWN";
    evidence[@"authority"] = signature.authority ?: @"UNKNOWN";
    evidence[@"adHoc"] = signature ? @(signature.isAdHocSigned) : @"UNKNOWN";
    evidence[@"entitlements"] = entitlementEvidence;
    evidence[@"entitlementValues"] = entitlements ?: @{};
    evidence[@"provisioning"] = profileEvidence;
    evidence[@"provisioningEvidence"] = profile ?: @{};
    evidence[@"registration"] = registrationEvidence;
    evidence[@"registrationFacts"] = registration ?: @{};
    evidence[@"machOType"] = machO.machOTypeName ?: @"UNKNOWN";
    evidence[@"architecture"] = machO.slices.firstObject.architectureName ?: @"UNKNOWN";
    evidence[@"cryptid"] = machO ? @(machO.hasEncryptedSlice) : @"UNKNOWN";
    evidence[@"dependencies"] = machO.dependencies.count ? [machO.dependencies valueForKey:@"rawInstallName"] : @[];
    evidence[@"rpaths"] = machO.rpaths.count ? [machO.rpaths valueForKey:@"rawPath"] : @[];
    evidence[@"jailbreakLaunchability"] = runtimeEvidence;
    evidence[@"rootless"] = @(runtime.isRootless);
    evidence[@"jailbreakType"] = runtime.jailbreakTypeName ?: @"UNKNOWN";
    evidence[@"bootstrapPath"] = runtime.bootstrapPath ?: @"UNKNOWN";
    evidence[@"stockTrustEvidence"] = stockEvidence;
    evidence[@"persistentTrustEvidence"] = persistentEvidence;

    NSString *reason = !appExists || !executableExists ? @"Application or executable could not be inspected" :
                       [NSString stringWithFormat:@"Signature, registration, Mach-O, provisioning, and runtime evidence collected; stock and persistent execution were not observed in this run"];
    NSString *output = [NSString stringWithFormat:
                        @"Experimental Trust Evidence\nSignature: %@\nTeam ID: %@\nAdHoc: %@\nProvisioning: %@\nEntitlements: %@\nRegistration: %@\nMach-O: %@ / %@\nJailbreak Launchability: %@\nStock Trust Evidence: %@\nPersistent Trust Evidence: %@\nTrust State: UNKNOWN\nReason: %@",
                        signatureEvidence, signature.teamID ?: @"UNKNOWN", signature ? (signature.isAdHocSigned ? @"YES" : @"NO") : @"UNKNOWN", profileEvidence, entitlementEvidence, registrationEvidence, machO.machOTypeName ?: @"UNKNOWN", machO.slices.firstObject.architectureName ?: @"UNKNOWN", runtimeEvidence, stockEvidence, persistentEvidence, reason];
    evidence[@"formattedSummary"] = output;

    return [TrustBackendResult resultWithState:TrustBackendStateUnknown backendName:self.backendName available:YES supportedCapabilities:@[@"read-only application evidence", @"read-only provisioning evidence", @"read-only registration evidence", @"read-only runtime evidence"] reason:reason verificationResult:NO persistentExecutionAvailable:NO evidence:evidence];
}

@end
