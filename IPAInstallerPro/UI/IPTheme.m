#import "IPTheme.h"

@implementation IPTheme
+ (UIColor *)backgroundColor { return [UIColor colorWithRed:.025 green:.026 blue:.030 alpha:1]; }
+ (UIColor *)cardColor { return [UIColor colorWithRed:.058 green:.059 blue:.064 alpha:1]; }
+ (UIColor *)secondaryCardColor { return [UIColor colorWithRed:.070 green:.071 blue:.078 alpha:1]; }
+ (UIColor *)accentColor { return [UIColor colorWithRed:1 green:.20 blue:.17 alpha:1]; }
+ (UIColor *)mutedTextColor { return [UIColor colorWithWhite:.70 alpha:1]; }
+ (UIColor *)subtleBorderColor { return [UIColor colorWithWhite:.20 alpha:.58]; }
+ (UIColor *)dividerColor { return [UIColor colorWithWhite:1 alpha:.08]; }
+ (UIFont *)titleFont { return [UIFont systemFontOfSize:27 weight:UIFontWeightBold]; }
+ (UIFont *)sectionFont { return [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]; }
+ (UIFont *)bodyFont { return [UIFont systemFontOfSize:12 weight:UIFontWeightMedium]; }
+ (void)applyToNavigationController:(UINavigationController *)navigationController {
    navigationController.navigationBar.tintColor = [self accentColor];
    navigationController.navigationBar.barStyle = UIBarStyleBlack;
    navigationController.navigationBar.prefersLargeTitles = NO;
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithOpaqueBackground]; appearance.backgroundColor = [self backgroundColor]; appearance.shadowColor = [self dividerColor];
    appearance.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor, NSFontAttributeName: [self sectionFont]};
    navigationController.navigationBar.standardAppearance = appearance; navigationController.navigationBar.scrollEdgeAppearance = appearance; navigationController.navigationBar.compactAppearance = appearance;
}
+ (void)applyGlobalAppearance {
    UITableView.appearance.backgroundColor = [self backgroundColor];
    UITableViewCell.appearance.backgroundColor = UIColor.clearColor;
    UISwitch.appearance.onTintColor = [self accentColor];
    UISegmentedControl.appearance.tintColor = [self accentColor];
    UISearchBar.appearance.tintColor = [self accentColor];
}
@end
