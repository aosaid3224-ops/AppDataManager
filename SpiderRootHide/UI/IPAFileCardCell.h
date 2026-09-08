#import <UIKit/UIKit.h>

@interface IPAFileCardCell : UITableViewCell
@property (nonatomic, strong, readonly) UIImageView *ipaIconView;
@property (nonatomic, strong, readonly) UILabel *titleLabel;
@property (nonatomic, strong, readonly) UILabel *subtitleLabel;
@property (nonatomic, strong, readonly) UILabel *metaLabel;
@property (nonatomic, strong, readonly) UIButton *moreButton;
@property (nonatomic, assign) BOOL showsChildIndent;
- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle meta:(NSString *)meta icon:(UIImage *)icon statusColor:(UIColor *)statusColor isChild:(BOOL)isChild;
@end
