//
// SigningTarget.h
// IPAInstallerPro — Phase 2/3: Smart Signing System
//
// Represents a single binary target within an IPA that needs signing decisions.
//

#import <Foundation/Foundation.h>
@class EntitlementSet;

typedef NS_ENUM(NSInteger, SigningTargetType) {
    SigningTargetTypeUnknown = 0,
    SigningTargetTypeMainExecutable = 1,
    SigningTargetTypeAppExtension = 2,
    SigningTargetTypeXPCService = 3,
    SigningTargetTypeFramework = 4,
    SigningTargetTypeDylib = 5,
    SigningTargetTypeBundle = 6
};

typedef NS_ENUM(NSInteger, SigningStrategy) {
    SigningStrategyUnknown = 0,
    SigningStrategyPreserveOriginal = 1,  // Keep original entitlements exactly
    SigningStrategyGeneric = 2,            // Use full generic jailbreak entitlements
    SigningStrategyMinimal = 3,            // Use minimal entitlements (platform-app only)
    SigningStrategySkip = 4                // Do not re-sign this target
};

@interface SigningTarget : NSObject

@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) NSString *targetName;
@property (nonatomic, assign) SigningTargetType targetType;
@property (nonatomic, strong) NSString *targetTypeName;

// Original state (from IPA before any modification)
@property (nonatomic, strong) EntitlementSet *originalEntitlements;
@property (nonatomic, assign) BOOL hasOriginalSignature;
@property (nonatomic, strong) NSString *originalTeamID;
@property (nonatomic, strong) NSString *originalAuthority;

// Planned state (what the planner decided)
@property (nonatomic, strong) EntitlementSet *plannedEntitlements;
@property (nonatomic, assign) SigningStrategy strategy;
@property (nonatomic, strong) NSString *strategyName;
@property (nonatomic, strong) NSString *strategyReason;
@property (nonatomic, assign) NSInteger signingOrder; // 1=dylib, 2=framework, 3=extension, 4=main
@property (nonatomic, assign) BOOL needsSigning;

- (NSString *)typeName;
- (NSString *)strategyNameString;
- (NSDictionary *)dictionaryRepresentation;

@end
