#import <UIKit/UIKit.h>

@interface IPAExportProgressView : UIView
@property (nonatomic, strong, readonly) UILabel *stageLabel;
@property (nonatomic, strong, readonly) UILabel *detailLabel;
@property (nonatomic, strong, readonly) UILabel *statsLabel;
@property (nonatomic, strong, readonly) UIProgressView *progressBar;
@property (nonatomic, strong, readonly) UIImageView *appIconView;
@property (nonatomic, strong, readonly) UILabel *appNameLabel;
@property (nonatomic, strong, readonly) UIButton *closeButton;
@property (nonatomic, strong, readonly) UIView *cardView;

- (void)showInView:(UIView *)view animated:(BOOL)animated;
- (void)dismissWithCompletion:(void (^)(void))completion;
- (void)setStage:(NSString *)stage detail:(NSString *)detail progress:(CGFloat)progress;
- (void)setStats:(NSString *)stats;
- (void)setAppIcon:(UIImage *)icon name:(NSString *)name;
@end
