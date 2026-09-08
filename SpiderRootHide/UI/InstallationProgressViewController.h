#import <UIKit/UIKit.h>

@class InstallationResult;
typedef void (^IPADuplicateCompletionHandler)(BOOL success, InstallationResult *result);

@interface InstallationProgressViewController : UIViewController
@property (nonatomic, strong) NSString *ipaName;
@property (nonatomic, strong) NSString *ipaPath;
@property (nonatomic, assign) BOOL dismissOnDuplicateSuccess;
@property (nonatomic, copy) IPADuplicateCompletionHandler duplicateCompletionHandler;
@end
