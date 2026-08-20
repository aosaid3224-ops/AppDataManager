//
// SigningPlanReportViewController.h
// IPAInstallerPro — Phase 2/3: Smart Signing System
//
// Debug UI for viewing the generated signing plan.
//

#import <UIKit/UIKit.h>
@class SigningPlan;

@interface SigningPlanReportViewController : UIViewController
@property (nonatomic, strong) SigningPlan *signingPlan;
@end
