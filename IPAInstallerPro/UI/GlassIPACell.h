#import <UIKit/UIKit.h>

@class IPAExtractedInfo;

@interface GlassIPACell : UITableViewCell
- (void)configureWithIPAInfo:(IPAExtractedInfo *)info;
- (void)playEntranceAnimationWithDelay:(NSTimeInterval)delay;
@end
