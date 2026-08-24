#import "AppDelegate.h"
#import "PVFrontViewController.h"
#import "PVInitialSetupViewController.h"
#import "PVPasswordStore.h"

@implementation AppDelegate

- (void)showMainInterface {
    PVFrontViewController *rootVC = [[PVFrontViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:rootVC];
    self.window.rootViewController = nav;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    if ([[PVPasswordStore sharedStore] isConfigured]) {
        [self showMainInterface];
    } else {
        PVInitialSetupViewController *setupVC = [[PVInitialSetupViewController alloc] init];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:setupVC];
        self.window.rootViewController = nav;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initialSetupCompleted:) name:@"PVInitialSetupCompleted" object:nil];
    }

    [self.window makeKeyAndVisible];
    return YES;
}

- (void)initialSetupCompleted:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"PVInitialSetupCompleted" object:nil];
    [self showMainInterface];
}

@end
