#import "PVEntryViewController.h"
#import "PVPasswordViewController.h"

@implementation PVEntryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Diagnostics";

    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
    }

    UILabel *label = [[UILabel alloc] init];
    label.text = @"Device diagnostics are not available.";
    label.textAlignment = NSTextAlignmentCenter;
    if (@available(iOS 13.0, *)) {
        label.textColor = [UIColor secondaryLabelColor];
    } else {
        label.textColor = [UIColor grayColor];
    }
    label.numberOfLines = 0;
    label.font = [UIFont systemFontOfSize:16];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [label.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [label.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [label.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [label.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40]
    ]];

    UITapGestureRecognizer *tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                action:@selector(handleTripleTap:)];
    tripleTap.numberOfTapsRequired = 3;
    [self.view addGestureRecognizer:tripleTap];
}

- (void)handleTripleTap:(UITapGestureRecognizer *)gesture {
    PVPasswordViewController *vc = [[PVPasswordViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
