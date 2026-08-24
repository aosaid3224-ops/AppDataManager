#import <UIKit/UIKit.h>

@interface PVPassword2ViewController : UIViewController
@property (nonatomic, copy) void (^authenticationSuccess)(void);
@property (nonatomic, copy) void (^authenticationFailure)(void);
@end
