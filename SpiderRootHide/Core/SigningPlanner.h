//
// SigningPlanner.h
// IPAInstallerPro — Phase 2/3: Smart Signing System
//
// The brain of the signing system.
// Analyzes an IPA's structural profile and produces a complete SigningPlan.
//

#import <Foundation/Foundation.h>
@class IPAStructuralResult;
@class SigningPlan;

@interface SigningPlanner : NSObject

+ (instancetype)sharedPlanner;

/// Creates a complete signing plan for the given IPA structural profile.
/// This is a synchronous blocking call — run on background thread.
- (SigningPlan *)createPlanForStructuralResult:(IPAStructuralResult *)result;

@end
