#import "PVDummyViewController.h"
#import "PVPassword2ViewController.h"

@interface PVDummyViewController ()
@property (nonatomic, strong) UILabel *dummyLabel;
@end

@implementation PVDummyViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"المستودع";

    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
    }

    self.dummyLabel = [[UILabel alloc] init];
    self.dummyLabel.text = @"لا توجد بيانات لعرضها هنا";
    self.dummyLabel.textAlignment = NSTextAlignmentCenter;
    if (@available(iOS 13.0, *)) {
        self.dummyLabel.textColor = [UIColor labelColor];
    } else {
        self.dummyLabel.textColor = [UIColor blackColor];
    }
    self.dummyLabel.font = [UIFont systemFontOfSize:18];
    self.dummyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.dummyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [self.dummyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.dummyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];

    UITapGestureRecognizer *quadTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleQuadTap:)];
    quadTap.numberOfTapsRequired = 4;
    [self.dummyLabel addGestureRecognizer:quadTap];
    self.dummyLabel.userInteractionEnabled = YES;
}

- (void)handleQuadTap:(UITapGestureRecognizer *)gesture {
    PVPassword2ViewController *vc = [[PVPassword2ViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
