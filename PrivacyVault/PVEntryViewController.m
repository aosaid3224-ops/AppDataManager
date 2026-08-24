#import "PVEntryViewController.h"
#import "PVPassword1ViewController.h"
#import "PVPassword2ViewController.h"
#import "PVDecoy2ViewController.h"
#import "PVVaultViewController.h"

@implementation PVEntryViewController

- (void)beginAuthenticationFromNavigationController:(UINavigationController *)navigationController {
    if (!navigationController) return;

    __weak UINavigationController *weakNavigationController = navigationController;
    PVPassword1ViewController *password1 = [[PVPassword1ViewController alloc] init];
    password1.authenticationFailure = ^{
        [weakNavigationController popToRootViewControllerAnimated:YES];
    };
    password1.authenticationSuccess = ^{
        UINavigationController *strongNavigationController = weakNavigationController;
        if (!strongNavigationController) return;
        PVDecoy2ViewController *decoy = [[PVDecoy2ViewController alloc] init];
        [strongNavigationController pushViewController:decoy animated:YES];
    };
    [navigationController pushViewController:password1 animated:YES];
}

@end
