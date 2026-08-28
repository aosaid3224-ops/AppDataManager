#import <UIKit/UIKit.h>
#import "Core/IPAExtractor.h"

@interface IPAInstallViewController : UIViewController
@property (nonatomic, assign) BOOL launchedFromDuplicate;
@property (nonatomic, copy) void (^duplicateCompletionHandler)(BOOL success);
- (instancetype)initWithIPAInfo:(IPAExtractedInfo *)info;
@end
