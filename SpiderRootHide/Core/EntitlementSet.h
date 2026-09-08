//
// EntitlementSet.h
// IPAInstallerPro — Phase 2/3: Smart Signing System
//
// Parsed and analyzed entitlement dictionary with intelligence.
//

#import <Foundation/Foundation.h>

@interface EntitlementSet : NSObject

@property (nonatomic, strong) NSString *sourcePath;
@property (nonatomic, strong) NSDictionary *rawEntitlements;
@property (nonatomic, assign) NSInteger entitlementCount;

// Core jailbreak entitlements
@property (nonatomic, assign) BOOL hasPlatformApplication;
@property (nonatomic, assign) BOOL hasGetTaskAllow;
@property (nonatomic, assign) BOOL hasNoContainer;
@property (nonatomic, assign) BOOL hasNoSandbox;
@property (nonatomic, assign) BOOL hasSkipLibraryValidation;
@property (nonatomic, assign) BOOL hasRunUnsignedCode;

// Apple services (these MUST be preserved for functionality)
@property (nonatomic, assign) BOOL hasPushNotifications;           // aps-environment
@property (nonatomic, assign) BOOL hasGameCenter;                  // com.apple.developer.game-center
@property (nonatomic, assign) BOOL hasAppGroups;                   // com.apple.security.application-groups
@property (nonatomic, assign) BOOL hasHealthKit;                   // com.apple.developer.healthkit
@property (nonatomic, assign) BOOL hasiCloud;                      // com.apple.developer.icloud-services
@property (nonatomic, assign) BOOL hasSiri;                        // com.apple.developer.siri
@property (nonatomic, assign) BOOL hasNetworkExtension;            // com.apple.developer.networking.networkextension
@property (nonatomic, assign) BOOL hasAssociatedDomains;           // com.apple.developer.associated-domains
@property (nonatomic, assign) BOOL hasKeychainAccess;              // keychain-access-groups
@property (nonatomic, assign) BOOL hasCarPlay;                     // com.apple.developer.carplay
@property (nonatomic, assign) BOOL hasHomeKit;                     // com.apple.developer.homekit
@property (nonatomic, assign) BOOL hasWirelessAccessory;           // com.apple.external-accessory.wireless
@property (nonatomic, assign) BOOL hasInAppPurchase;               // com.apple.developer.in-app-purchase
@property (nonatomic, assign) BOOL hasApplePay;                    // com.apple.developer.in-app-payments
@property (nonatomic, assign) BOOL hasVPN;                         // com.apple.developer.networking.vpn.api
@property (nonatomic, assign) BOOL hasMultipath;                   // com.apple.developer.networking.multipath
@property (nonatomic, assign) BOOL hasBackgroundModes;             // UIBackgroundModes (in Info.plist but related)
@property (nonatomic, assign) BOOL hasFamilyControls;              // com.apple.developer.family-controls
@property (nonatomic, assign) BOOL hasCommunicationNotifications;  // com.apple.developer.usernotifications.communication
@property (nonatomic, assign) BOOL hasGroupActivities;             // com.apple.developer.group-session

// Classification
@property (nonatomic, assign) BOOL isComplex;                      // Has any Apple service entitlements
@property (nonatomic, strong) NSArray<NSString *> *specialEntitlementKeys;
@property (nonatomic, strong) NSArray<NSString *> *allEntitlementKeys;

- (instancetype)initWithDictionary:(NSDictionary *)dict sourcePath:(NSString *)path;

// Pre-built entitlement sets for strategies
+ (NSDictionary *)genericJailbreakEntitlements;
+ (NSDictionary *)minimalEntitlements;
+ (NSDictionary *)emptyEntitlements;

- (NSDictionary *)dictionaryRepresentation;

@end
