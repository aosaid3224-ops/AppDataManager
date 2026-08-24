#import "PVEntryViewController.h"
#import "PVPassword1ViewController.h"
#import "PVPassword2ViewController.h"
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
        PVPassword2ViewController *password2 = [[PVPassword2ViewController alloc] init];
        password2.authenticationFailure = ^{
            [strongNavigationController popToRootViewControllerAnimated:YES];
        };
        password2.authenticationSuccess = ^{
            UINavigationController *finalNavigationController = weakNavigationController;
            if (!finalNavigationController) return;
            PVVaultViewController *vault = [[PVVaultViewController alloc] init];
            [finalNavigationController pushViewController:vault animated:YES];
        };
        [strongNavigationController pushViewController:password2 animated:YES];
    };
    [navigationController pushViewController:password1 animated:YES];
}

@end
