#import <UIKit/UIKit.h>

@class IPAExtractedInfo;

@interface GlassIPACell : UITableViewCell
- (void)configureWithIPAInfo:(IPAExtractedInfo *)info;
- (void)setIconImage:(UIImage *)icon animated:(BOOL)animated;
- (void)playEntranceAnimationWithDelay:(NSTimeInterval)delay;
@end
