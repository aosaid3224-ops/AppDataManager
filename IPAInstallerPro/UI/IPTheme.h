#import <UIKit/UIKit.h>

@interface IPTheme : NSObject
+ (UIColor *)backgroundColor;
+ (UIColor *)cardColor;
+ (UIColor *)secondaryCardColor;
+ (UIColor *)accentColor;
+ (UIColor *)mutedTextColor;
+ (UIColor *)subtleBorderColor;
+ (UIColor *)dividerColor;
+ (UIFont *)titleFont;
+ (UIFont *)sectionFont;
+ (UIFont *)bodyFont;
+ (void)applyToNavigationController:(UINavigationController *)navigationController;
+ (void)applyGlobalAppearance;
@end
