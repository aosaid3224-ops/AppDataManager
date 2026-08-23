#import "AppDelegate.h"
#import "MainViewController.h"
#import "BackupManagerViewController.h"
#import "SettingsViewController.h"

static UIColor *ADMAppBackground(void) { return [UIColor colorWithRed:0.025 green:0.027 blue:0.035 alpha:1.0]; }
static UIColor *ADMAppAccent(void) { return [UIColor colorWithRed:0.43 green:0.56 blue:0.92 alpha:1.0]; }

@interface AppDelegate ()
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    UITabBarController *tabBarController = [[UITabBarController alloc] init];
    tabBarController.view.backgroundColor = ADMAppBackground();

    MainViewController *mainVC = [[MainViewController alloc] init];
    UINavigationController *mainNav = [[UINavigationController alloc] initWithRootViewController:mainVC];
    mainNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"التطبيقات" image:[UIImage systemImageNamed:@"square.grid.2x2"] selectedImage:[UIImage systemImageNamed:@"square.grid.2x2.fill"]];

    BackupManagerViewController *backupVC = [[BackupManagerViewController alloc] init];
    UINavigationController *backupNav = [[UINavigationController alloc] initWithRootViewController:backupVC];
    backupNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"النسخ" image:[UIImage systemImageNamed:@"clock.arrow.circlepath"] selectedImage:[UIImage systemImageNamed:@"clock.arrow.circlepath"]];

    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    UINavigationController *settingsNav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    settingsNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"الإعدادات" image:[UIImage systemImageNamed:@"gearshape"] selectedImage:[UIImage systemImageNamed:@"gearshape.fill"]];

    tabBarController.viewControllers = @[mainNav, backupNav, settingsNav];
    tabBarController.tabBar.tintColor = ADMAppAccent();
    tabBarController.tabBar.unselectedItemTintColor = [UIColor colorWithWhite:0.64 alpha:1.0];
    tabBarController.tabBar.backgroundColor = ADMAppBackground();
    tabBarController.tabBar.barTintColor = ADMAppBackground();

    if (@available(iOS 13.0, *)) {
        UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = ADMAppBackground();
        appearance.shadowColor = [UIColor colorWithWhite:0.12 alpha:0.85];
        appearance.stackedLayoutAppearance.normal.iconColor = [UIColor colorWithWhite:0.64 alpha:1.0];
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.90 alpha:1.0], NSFontAttributeName: [UIFont systemFontOfSize:10 weight:UIFontWeightMedium]};
        appearance.stackedLayoutAppearance.selected.iconColor = ADMAppAccent();
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor, NSFontAttributeName: [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold]};
        tabBarController.tabBar.standardAppearance = appearance;
        if (@available(iOS 15.0, *)) tabBarController.tabBar.scrollEdgeAppearance = appearance;
    }

    for (UINavigationController *nav in tabBarController.viewControllers) {
        nav.view.backgroundColor = ADMAppBackground();
        nav.navigationBar.barTintColor = ADMAppBackground();
        nav.navigationBar.backgroundColor = ADMAppBackground();
        nav.navigationBar.tintColor = UIColor.whiteColor;
        nav.navigationBar.translucent = NO;
        if (@available(iOS 13.0, *)) {
            UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
            [appearance configureWithOpaqueBackground];
            appearance.backgroundColor = ADMAppBackground();
            appearance.shadowColor = UIColor.clearColor;
            appearance.titleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor};
            appearance.largeTitleTextAttributes = @{NSForegroundColorAttributeName: UIColor.whiteColor};
            nav.navigationBar.standardAppearance = appearance;
            if (@available(iOS 15.0, *)) nav.navigationBar.scrollEdgeAppearance = appearance;
        }
    }

    self.window.rootViewController = tabBarController;
    [self.window makeKeyAndVisible];
    [self showWelcomeIfNeeded];
    return YES;
}

- (void)showWelcomeIfNeeded {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:@"HasLaunchedBefore"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSString *message = @"AppData Manager v1.0.2\n\n"
                @"مجانية بالكامل — لا تُباع ولا تتطلب أي رسوم.\n\n"
                @"إذا حاول أي شخص بيع الأداة أو طلب مبلغ مقابل الحصول عليها، فهذا غير رسمي.\n\n"
                @"للإبلاغ عن أي حالة بيع أو استغلال للأداة:\n"
                @"X: @Zainqkvd\n\n"
                @"المطور: ZAIN";
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"حول AppData Manager" message:message preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_) {
                [defaults setBool:YES forKey:@"HasLaunchedBefore"];
                [defaults synchronize];
            }];
            [alert addAction:okAction];
            UIViewController *topVC = self.window.rootViewController;
            while (topVC.presentedViewController) topVC = topVC.presentedViewController;
            [topVC presentViewController:alert animated:YES completion:nil];
        });
    }
}

@end
