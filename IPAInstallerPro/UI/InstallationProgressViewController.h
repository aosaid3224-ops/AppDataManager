#import <UIKit/UIKit.h>

@interface InstallationProgressViewController : UIViewController
@property (nonatomic, strong) NSString *ipaName;
@property (nonatomic, strong) NSString *ipaPath;
// Called after the user finishes viewing the result, allowing the caller to
// return to its IPA library without terminating the app.
@property (nonatomic, copy) void (^onFinished)(void);
@end
