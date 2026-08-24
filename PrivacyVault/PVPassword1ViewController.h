#import <UIKit/UIKit.h>

@interface PVPassword1ViewController : UIViewController
@property (nonatomic, copy) void (^authenticationSuccess)(void);
@property (nonatomic, copy) void (^authenticationFailure)(void);
@end
