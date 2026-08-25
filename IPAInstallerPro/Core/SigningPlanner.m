//
// SigningPlanner.m
//

#import "SigningPlanner.h"
#import "IPAStructuralResult.h"
#import "SigningPlan.h"
#import "SigningTarget.h"
#import "EntitlementSet.h"
#import "SignatureAnalyzer.h"

@interface SigningPlanner ()
@end

@implementation SigningPlanner

+ (instancetype)sharedPlanner {
    static SigningPlanner *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

#pragma mark - Main Entry Point

- (SigningPlan *)createPlanForStructuralResult:(IPAStructuralResult *)result {
    SigningPlan *plan = [[SigningPlan alloc] init];
    plan.ipaPath = result.ipaPath;

    NSMutableArray<SigningTarget *> *targets = [NSMutableArray array];

    // Analyze each executable while its extracted source still exists.
    // Store paths relative to the top-level app bundle: the structural analyzer
    // cleans its temporary extraction before the install signer runs.
    NSString *appRoot = nil;
    for (IPAStructuralBundle *bundle in result.bundles) {
        if ([bundle.bundleType isEqualToString:@".app"] && bundle.nestingLevel == 0) {
            appRoot = bundle.path;
            break;
        }
    }

    for (IPAStructuralExecutable *exe in result.executables) {
        SigningTarget *target = [self analyzeExecutable:exe inResult:result];
        if (target) {
            if (appRoot.length > 0 && [target.filePath hasPrefix:appRoot]) {
                NSString *relative = [target.filePath substringFromIndex:appRoot.length];
                while ([relative hasPrefix:@"/"]) relative = [relative substringFromIndex:1];
                target.filePath = relative;
            }
            [targets addObject:target];
        }
    }

    plan.targets = [targets copy];

    // Compute statistics
    [self computeStatistics:plan];

    // Validate plan viability
    [self validatePlan:plan];

    // Generate recommendations
    [self generateRecommendations:plan result:result];

    return plan;
}

#pragma mark - Executable Analysis

- (SigningTarget *)analyzeExecutable:(IPAStructuralExecutable *)exe inResult:(IPAStructuralResult *)result {
    SigningTarget *target = [[SigningTarget alloc] init];
    target.filePath = exe.path;
    target.targetName = exe.name;
    target.needsSigning = YES;

    // 1. Classify target type
    target.targetType = [self classifyTargetType:exe path:exe.path bundles:result.bundles];
    target.targetTypeName = [target typeName];

    // 2. Analyze original signature
    SignatureInfo *sigInfo = [[SignatureAnalyzer sharedAnalyzer] analyzeSignatureAtPath:exe.path];
    target.hasOriginalSignature = sigInfo.isSigned;
    target.originalTeamID = sigInfo.teamID;
    target.originalAuthority = sigInfo.authority;

    // 3. Extract original entitlements
    NSDictionary *rawEnts = [[SignatureAnalyzer sharedAnalyzer] extractEntitlementsAtPath:exe.path];
    if (rawEnts) {
        target.originalEntitlements = [[EntitlementSet alloc] initWithDictionary:rawEnts sourcePath:exe.path];
    }

    // 4. Decide strategy
    [self decideStrategyForTarget:target];

    // 5. Build planned entitlements based on strategy
    [self buildPlannedEntitlementsForTarget:target];

    return target;
}

#pragma mark - Target Classification

- (SigningTargetType)classifyTargetType:(IPAStructuralExecutable *)exe path:(NSString *)path bundles:(NSArray<IPAStructuralBundle *> *)bundles {
    NSString *lower = path.lowercaseString;

    // Check by path patterns (most reliable)
    if ([lower containsString:@".appex/"]) return SigningTargetTypeAppExtension;
    if ([lower containsString:@".xpc/"]) return SigningTargetTypeXPCService;
    if ([lower containsString:@".framework/"]) return SigningTargetTypeFramework;

    // Check by Mach-O type
    if ([exe.machOTypeName isEqualToString:@"MH_DYLIB"]) return SigningTargetTypeDylib;

    // Check if it's the main executable of a top-level .app
    for (IPAStructuralBundle *bundle in bundles) {
        if ([bundle.bundleType isEqualToString:@".app"] && bundle.nestingLevel == 0) {
            // Check if this executable belongs to the main app
            if (bundle.executablePath && [path isEqualToString:bundle.executablePath]) {
                return SigningTargetTypeMainExecutable;
            }
        }
    }

    // Check if it's an executable inside any .app (could be nested or main)
    for (IPAStructuralBundle *bundle in bundles) {
        if ([bundle.bundleType isEqualToString:@".app"] && bundle.executablePath && [path isEqualToString:bundle.executablePath]) {
            return SigningTargetTypeMainExecutable;
        }
    }

    // Check for .bundle type
    if ([lower containsString:@".bundle/"]) return SigningTargetTypeBundle;

    // Default: if it's MH_EXECUTE and we couldn't classify, assume main
    if ([exe.machOTypeName isEqualToString:@"MH_EXECUTE"]) {
        return SigningTargetTypeMainExecutable;
    }

    return SigningTargetTypeUnknown;
}

#pragma mark - Strategy Decision (THE BRAIN)

- (void)decideStrategyForTarget:(SigningTarget *)target {
    switch (target.targetType) {
        case SigningTargetTypeAppExtension:
        case SigningTargetTypeXPCService:
            [self decideExtensionStrategy:target];
            break;

        case SigningTargetTypeFramework:
            [self decideFrameworkStrategy:target];
            break;

        case SigningTargetTypeDylib:
            [self decideDylibStrategy:target];
            break;

        case SigningTargetTypeMainExecutable:
            [self decideMainAppStrategy:target];
            break;

        case SigningTargetTypeBundle:
            [self decideBundleStrategy:target];
            break;

        default:
            target.strategy = SigningStrategyGeneric;
            target.strategyReason = @"Unknown target type — defaulting to generic jailbreak entitlements";
            target.signingOrder = 4;
            break;
    }
}

// MARK: - Extension Strategy
- (void)decideExtensionStrategy:(SigningTarget *)target {
    // Extensions ALWAYS need their original entitlements preserved
    // because they rely on specific Apple services (Push, Siri, Share, etc.)
    target.signingOrder = 3;

    if (target.originalEntitlements && target.originalEntitlements.isComplex) {
        target.strategy = SigningStrategyPreserveOriginal;
        target.strategyReason = [NSString stringWithFormat:
            @"%@ requires original entitlements: %@",
            target.targetTypeName,
            [target.originalEntitlements.specialEntitlementKeys componentsJoinedByString:@", "]];
    } else if (target.originalEntitlements && target.originalEntitlements.entitlementCount > 0) {
        target.strategy = SigningStrategyPreserveOriginal;
        target.strategyReason = [NSString stringWithFormat:
            @"%@ has entitlements that must be preserved for proper functionality",
            target.targetTypeName];
    } else {
        // No original entitlements found — use generic but warn
        target.strategy = SigningStrategyGeneric;
        target.strategyReason = [NSString stringWithFormat:
            @"%@ has no original entitlements — using generic (may lose functionality)",
            target.targetTypeName];
    }
}

// MARK: - Framework Strategy
- (void)decideFrameworkStrategy:(SigningTarget *)target {
    // Frameworks only need code signature validation
    // They don't need special entitlements for runtime
    target.strategy = SigningStrategyMinimal;
    target.strategyReason = @"Frameworks only need minimal entitlements for code signature validation";
    target.signingOrder = 2;

    // Exception: Some frameworks have embedded entitlements for specific reasons
    if (target.originalEntitlements && target.originalEntitlements.isComplex) {
        [self addWarningToTarget:target message:[NSString stringWithFormat:
            @"Framework %@ has complex entitlements — verify minimal signing is sufficient",
            target.targetName]];
    }
}

// MARK: - Dylib Strategy
- (void)decideDylibStrategy:(SigningTarget *)target {
    // Dylibs are the lowest level — minimal entitlements only
    target.strategy = SigningStrategyMinimal;
    target.strategyReason = @"Dylibs only need platform-application for code loading";
    target.signingOrder = 1;
}

// MARK: - Main App Strategy
- (void)decideMainAppStrategy:(SigningTarget *)target {
    target.signingOrder = 4; // Last to sign (depends on everything else)

    if (!target.originalEntitlements) {
        // No original entitlements found
        target.strategy = SigningStrategyGeneric;
        target.strategyReason = @"Main app has no original entitlements — using generic jailbreak set";
        return;
    }

    if (target.originalEntitlements.isComplex) {
        // Has special Apple service entitlements — MUST preserve
        target.strategy = SigningStrategyPreserveOriginal;
        target.strategyReason = [NSString stringWithFormat:
            @"Main app has complex entitlements that must be preserved: %@",
            [target.originalEntitlements.specialEntitlementKeys componentsJoinedByString:@", "]];

        // Add specific recommendations
        if (target.originalEntitlements.hasPushNotifications) {
            [self addRecommendationToTarget:target message:@"Push Notifications entitlement preserved — app must be registered with same bundle ID"];
        }
        if (target.originalEntitlements.hasGameCenter) {
            [self addRecommendationToTarget:target message:@"Game Center entitlement preserved — verify Apple ID sign-in works"];
        }
        if (target.originalEntitlements.hasAppGroups) {
            [self addRecommendationToTarget:target message:@"App Groups entitlement preserved — shared containers may need manual setup"];
        }
        if (target.originalEntitlements.hasiCloud) {
            [self addRecommendationToTarget:target message:@"iCloud entitlement preserved — verify container identifiers match"];
        }
    } else {
        // Simple app — generic entitlements are sufficient
        target.strategy = SigningStrategyGeneric;
        target.strategyReason = @"Main app has no special service entitlements — generic jailbreak set sufficient";
    }
}

// MARK: - Bundle Strategy
- (void)decideBundleStrategy:(SigningTarget *)target {
    // Resource bundles with code — minimal signing
    target.strategy = SigningStrategyMinimal;
    target.strategyReason = @"Bundle only needs minimal entitlements";
    target.signingOrder = 2;
}

#pragma mark - Planned Entitlements Builder

- (void)buildPlannedEntitlementsForTarget:(SigningTarget *)target {
    switch (target.strategy) {
        case SigningStrategyPreserveOriginal:
            if (target.originalEntitlements) {
                target.plannedEntitlements = target.originalEntitlements;
            } else {
                // Fallback if no original found
                target.plannedEntitlements = [[EntitlementSet alloc] initWithDictionary:[EntitlementSet genericJailbreakEntitlements] sourcePath:target.filePath];
                [self addWarningToTarget:target message:@"PreserveOriginal requested but no original entitlements found — falling back to generic"];
            }
            break;

        case SigningStrategyGeneric:
            target.plannedEntitlements = [[EntitlementSet alloc] initWithDictionary:[EntitlementSet genericJailbreakEntitlements] sourcePath:target.filePath];
            break;

        case SigningStrategyMinimal:
            target.plannedEntitlements = [[EntitlementSet alloc] initWithDictionary:[EntitlementSet minimalEntitlements] sourcePath:target.filePath];
            break;

        case SigningStrategySkip:
            target.plannedEntitlements = nil;
            target.needsSigning = NO;
            break;

        default:
            target.plannedEntitlements = [[EntitlementSet alloc] initWithDictionary:[EntitlementSet genericJailbreakEntitlements] sourcePath:target.filePath];
            break;
    }
}

#pragma mark - Statistics

- (void)computeStatistics:(SigningPlan *)plan {
    plan.totalTargets = plan.targets.count;

    NSInteger preserve = 0, generic = 0, minimal = 0, skip = 0, complex = 0;
    for (SigningTarget *t in plan.targets) {
        switch (t.strategy) {
            case SigningStrategyPreserveOriginal: preserve++; break;
            case SigningStrategyGeneric: generic++; break;
            case SigningStrategyMinimal: minimal++; break;
            case SigningStrategySkip: skip++; break;
            default: break;
        }
        if (t.originalEntitlements && t.originalEntitlements.isComplex) {
            complex++;
        }
    }

    plan.preserveCount = preserve;
    plan.genericCount = generic;
    plan.minimalCount = minimal;
    plan.skipCount = skip;
    plan.complexTargetsCount = complex;
}

#pragma mark - Validation

- (void)validatePlan:(SigningPlan *)plan {
    // Check for critical issues
    for (SigningTarget *t in plan.targets) {
        if (t.targetType == SigningTargetTypeAppExtension || t.targetType == SigningTargetTypeXPCService) {
            if (t.strategy != SigningStrategyPreserveOriginal && t.strategy != SigningStrategyGeneric) {
                [plan.warnings addObject:[NSString stringWithFormat:
                    @"⚠️ %@ (%@) is not using PreserveOriginal — may crash due to missing entitlements",
                    t.targetName, t.targetTypeName]];
            }
        }
    }

    // Check if main app has no entitlements at all
    for (SigningTarget *t in plan.targets) {
        if (t.targetType == SigningTargetTypeMainExecutable) {
            if (!t.plannedEntitlements || t.plannedEntitlements.entitlementCount == 0) {
                plan.isViable = NO;
                plan.viabilityReason = @"Main executable has no planned entitlements — plan is not viable";
                return;
            }
        }
    }

    plan.isViable = YES;
    plan.viabilityReason = @"All critical targets have valid signing strategies";
}

#pragma mark - Recommendations

- (void)generateRecommendations:(SigningPlan *)plan result:(IPAStructuralResult *)result {
    if (plan.complexTargetsCount > 0) {
        [plan.recommendations addObject:[NSString stringWithFormat:
            @"📋 %ld target(s) have complex entitlements — verify functionality after install",
            (long)plan.complexTargetsCount]];
    }

    if (result.frameworkCount > 5) {
        [plan.recommendations addObject:@"📦 Many frameworks detected — ensure all are properly signed in order"];
    }

    BOOL hasFatBinary = NO;
    for (IPAStructuralExecutable *executable in result.executables) {
        if (executable.slices.count > 1) {
            hasFatBinary = YES;
            break;
        }
    }
    if (hasFatBinary) {
        [plan.recommendations addObject:@"FAT binary detected — verify device architecture compatibility"];
    }

    if (plan.preserveCount > 0) {
        [plan.recommendations addObject:[NSString stringWithFormat:
            @"🔒 %ld target(s) will preserve original entitlements — these apps should function normally",
            (long)plan.preserveCount]];
    }

    if (plan.genericCount > 0) {
        [plan.recommendations addObject:[NSString stringWithFormat:
            @"⚙️ %ld target(s) will use generic entitlements — simple apps should work fine",
            (long)plan.genericCount]];
    }
}

#pragma mark - Helpers

- (void)addWarningToTarget:(SigningTarget *)target message:(NSString *)message {
    // Warnings are stored at plan level, but we can log them
    NSLog(@"[SigningPlanner] Warning for %@: %@", target.targetName, message);
}

- (void)addRecommendationToTarget:(SigningTarget *)target message:(NSString *)message {
    NSLog(@"[SigningPlanner] Recommendation for %@: %@", target.targetName, message);
}

@end
