#import "AppDelegate.h"
#import "UI/MainViewController.h"
#import "UI/IPAUnpackViewController.h"
#import "UI/InstalledAppsViewController.h"
#import "UI/SettingsViewController.h"
#import "Core/Logger.h"
#import "Core/JailbreakEnvironment.h"

@interface AppDelegate ()
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Initialize logger and environment (safe, no heavy blocking)
    [Logger sharedLogger];
    [JailbreakEnvironment sharedEnvironment];  // detectEnvironment is now called in init

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    UITabBarController *tabBarController = [[UITabBarController alloc] init];

    MainViewController *mainVC = [[MainViewController alloc] init];
    UINavigationController *mainNav = [[UINavigationController alloc] initWithRootViewController:mainVC];
    mainNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"ملفات IPA"
                                                         image:[UIImage systemImageNamed:@"doc.zipper"]
                                                 selectedImage:[UIImage systemImageNamed:@"doc.zipper"]];

    InstalledAppsViewController *installedVC = [[InstalledAppsViewController alloc] init];
    UINavigationController *installedNav = [[UINavigationController alloc] initWithRootViewController:installedVC];
    installedNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"التطبيقات"
                                                            image:[UIImage systemImageNamed:@"apps.iphone"]
                                                    selectedImage:[UIImage systemImageNamed:@"apps.iphone"]];

    IPAUnpackViewController *unpackVC = [[IPAUnpackViewController alloc] init];
    UINavigationController *unpackNav = [[UINavigationController alloc] initWithRootViewController:unpackVC];
    unpackNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"فك الحزمة"
                                                         image:[UIImage systemImageNamed:@"archivebox"]
                                                 selectedImage:[UIImage systemImageNamed:@"archivebox.fill"]];

    SettingsViewController *settingsVC = [[SettingsViewController alloc] init];
    UINavigationController *settingsNav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    settingsNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"الإعدادات"
                                                           image:[UIImage systemImageNamed:@"gearshape"]
                                                   selectedImage:[UIImage systemImageNamed:@"gearshape.fill"]];

    tabBarController.viewControllers = @[mainNav, installedNav, unpackNav, settingsNav];
    tabBarController.tabBar.tintColor = [UIColor colorWithRed:0.55 green:0.45 blue:0.95 alpha:1.0];
    tabBarController.tabBar.barTintColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.04 alpha:1.0];
    tabBarController.tabBar.unselectedItemTintColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    tabBarController.tabBar.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.08 alpha:1.0];

    for (UINavigationController *nav in tabBarController.viewControllers) {
        nav.navigationBar.prefersLargeTitles = YES;
        nav.navigationBar.barTintColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.04 alpha:1.0];
        nav.navigationBar.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.04 alpha:1.0];
        nav.navigationBar.translucent = NO;
        nav.navigationBar.tintColor = [UIColor whiteColor];
        [nav.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]}];
        [nav.navigationBar setLargeTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]}];
    }

    self.window.rootViewController = tabBarController;
    [self.window makeKeyAndVisible];
    return YES;
}

@end
