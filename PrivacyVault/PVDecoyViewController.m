#import "PVDecoyViewController.h"
#import "PVPassword1ViewController.h"

@interface PVDecoyViewController ()
@property (nonatomic, strong) UILabel *decoyLabel;
@end

@implementation PVDecoyViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
    }

    self.decoyLabel = [[UILabel alloc] init];
    self.decoyLabel.text = @"لا يوجد تحديث للبرامج";
    self.decoyLabel.textAlignment = NSTextAlignmentCenter;
    if (@available(iOS 13.0, *)) {
        self.decoyLabel.textColor = [UIColor labelColor];
    } else {
        self.decoyLabel.textColor = [UIColor blackColor];
    }
    self.decoyLabel.font = [UIFont systemFontOfSize:18];
    self.decoyLabel.numberOfLines = 0;
    self.decoyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.decoyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.decoyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.decoyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.decoyLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:40],
        [self.decoyLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-40]
    ]];

    UITapGestureRecognizer *tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTripleTap:)];
    tripleTap.numberOfTapsRequired = 3;
    [self.decoyLabel addGestureRecognizer:tripleTap];
    self.decoyLabel.userInteractionEnabled = YES;
}

- (void)handleTripleTap:(UITapGestureRecognizer *)gesture {
    PVPassword1ViewController *vc = [[PVPassword1ViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
