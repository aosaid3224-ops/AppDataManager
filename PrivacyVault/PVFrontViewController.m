#import <UIKit/UIKit.h>
#import "PVSettingsViewController.h"
#import "PVEntryViewController.h"

@interface PVFrontViewController : UIViewController
@end

@interface PVFrontViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *entryTitleLabel;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@end

@implementation PVFrontViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"نظرة عامة";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    UIBarButtonItem *settingsItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape"] style:UIBarButtonItemStylePlain target:self action:@selector(settingsTapped:)];
    self.navigationItem.rightBarButtonItem = settingsItem;

    [self buildInterface];
    [self installEntryGesture];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self refreshFrontStateAnimated:NO];
}

- (void)buildInterface {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.scrollView];

    self.contentStack = [[UIStackView alloc] init];
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.spacing = 18.0;
    self.contentStack.alignment = UIStackViewAlignmentFill;
    self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.contentStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.contentStack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:18.0],
        [self.contentStack.leadingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.leadingAnchor constant:20.0],
        [self.contentStack.trailingAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.trailingAnchor constant:-20.0],
        [self.contentStack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-28.0]
    ]];

    UIView *header = [self makeHeaderView];
    UIView *statusCard = [self makeStatusCard];
    UIView *quickActions = [self makeQuickActionsCard];
    UIView *activityCard = [self makeActivityCard];

    [self.contentStack addArrangedSubview:header];
    [self.contentStack addArrangedSubview:statusCard];
    [self.contentStack addArrangedSubview:quickActions];
    [self.contentStack addArrangedSubview:activityCard];
}

- (UIView *)makeHeaderView {
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;

    self.entryTitleLabel = [[UILabel alloc] init];
    self.entryTitleLabel.text = @"المساحة الشخصية";
    self.entryTitleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle2];
    self.entryTitleLabel.textColor = [UIColor labelColor];
    self.entryTitleLabel.textAlignment = NSTextAlignmentRight;
    self.entryTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.entryTitleLabel.userInteractionEnabled = YES;
    [container addSubview:self.entryTitleLabel];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.text = @"أدواتك وإعداداتك في مكان واحد";
    subtitle.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    subtitle.textColor = [UIColor secondaryLabelColor];
    subtitle.textAlignment = NSTextAlignmentRight;
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:subtitle];

    [NSLayoutConstraint activateConstraints:@[
        [container.heightAnchor constraintGreaterThanOrEqualToConstant:64.0],
        [self.entryTitleLabel.topAnchor constraintEqualToAnchor:container.topAnchor],
        [self.entryTitleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.entryTitleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:self.entryTitleLabel.bottomAnchor constant:5.0],
        [subtitle.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [subtitle.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [subtitle.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];
    return container;
}

- (UIView *)makeStatusCard {
    UIView *card = [self cardView];

    UILabel *title = [self labelWithText:@"حالة المساحة" font:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline] color:[UIColor labelColor]];
    title.textAlignment = NSTextAlignmentRight;

    UIView *statusDot = [[UIView alloc] init];
    statusDot.backgroundColor = [UIColor systemGreenColor];
    statusDot.layer.cornerRadius = 5.0;
    statusDot.translatesAutoresizingMaskIntoConstraints = NO;

    self.statusLabel = [self labelWithText:@"جاهزة للاستخدام" font:[UIFont preferredFontForTextStyle:UIFontTextStyleBody] color:[UIColor secondaryLabelColor]];
    self.statusLabel.textAlignment = NSTextAlignmentRight;

    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.activityIndicator.hidesWhenStopped = YES;
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *statusLine = [[UIStackView alloc] initWithArrangedSubviews:@[self.statusLabel, statusDot, self.activityIndicator]];
    statusLine.axis = UILayoutConstraintAxisHorizontal;
    statusLine.alignment = UIStackViewAlignmentCenter;
    statusLine.spacing = 8.0;
    statusLine.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    statusLine.translatesAutoresizingMaskIntoConstraints = NO;

    [card addSubview:title];
    [card addSubview:statusLine];
    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:card.topAnchor constant:18.0],
        [title.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [title.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
        [statusLine.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:12.0],
        [statusLine.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [statusLine.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
        [statusLine.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18.0],
        [statusDot.widthAnchor constraintEqualToConstant:10.0],
        [statusDot.heightAnchor constraintEqualToConstant:10.0]
    ]];
    return card;
}

- (UIView *)makeQuickActionsCard {
    UIView *card = [self cardView];
    UILabel *title = [self labelWithText:@"الوصول السريع" font:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline] color:[UIColor labelColor]];
    title.textAlignment = NSTextAlignmentRight;
    [card addSubview:title];

    UIButton *settingsButton = [self actionButtonWithTitle:@"الإعدادات" imageName:@"gearshape" action:@selector(settingsTapped:)];
    UIButton *detailsButton = [self actionButtonWithTitle:@"تفاصيل التطبيق" imageName:@"info.circle" action:@selector(detailsTapped:)];
    UIStackView *actions = [[UIStackView alloc] initWithArrangedSubviews:@[settingsButton, detailsButton]];
    actions.axis = UILayoutConstraintAxisHorizontal;
    actions.distribution = UIStackViewDistributionFillEqually;
    actions.spacing = 12.0;
    actions.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    actions.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:actions];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:card.topAnchor constant:18.0],
        [title.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [title.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
        [actions.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:14.0],
        [actions.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [actions.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
        [actions.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18.0],
        [actions.heightAnchor constraintEqualToConstant:48.0]
    ]];
    return card;
}

- (UIView *)makeActivityCard {
    UIView *card = [self cardView];
    UILabel *title = [self labelWithText:@"النشاط" font:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline] color:[UIColor labelColor]];
    title.textAlignment = NSTextAlignmentRight;
    UILabel *message = [self labelWithText:@"لا توجد إجراءات مطلوبة الآن" font:[UIFont preferredFontForTextStyle:UIFontTextStyleBody] color:[UIColor secondaryLabelColor]];
    message.textAlignment = NSTextAlignmentRight;
    message.numberOfLines = 0;
    self.timeLabel = [self labelWithText:@"آخر تحديث: الآن" font:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote] color:[UIColor tertiaryLabelColor]];
    self.timeLabel.textAlignment = NSTextAlignmentRight;

    [card addSubview:title];
    [card addSubview:message];
    [card addSubview:self.timeLabel];
    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:card.topAnchor constant:18.0],
        [title.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [title.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
        [message.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:12.0],
        [message.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [message.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
        [self.timeLabel.topAnchor constraintEqualToAnchor:message.bottomAnchor constant:10.0],
        [self.timeLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [self.timeLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
        [self.timeLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-18.0]
    ]];
    return card;
}

- (UIView *)cardView {
    UIView *card = [[UIView alloc] init];
    card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 18.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    return card;
}

- (UILabel *)labelWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

- (UIButton *)actionButtonWithTitle:(NSString *)title imageName:(NSString *)imageName action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
    button.imageEdgeInsets = UIEdgeInsetsMake(0.0, 0.0, 0.0, 7.0);
    button.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)installEntryGesture {
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleEntryGesture:)];
    longPress.minimumPressDuration = 1.5;
    longPress.allowableMovement = 12.0;
    [self.entryTitleLabel addGestureRecognizer:longPress];
}

- (void)handleEntryGesture:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [feedback impactOccurred];
    }
    PVEntryViewController *entry = [[PVEntryViewController alloc] init];
    [entry beginAuthenticationFromNavigationController:self.navigationController];
}

- (void)settingsTapped:(id)sender {
    PVSettingsViewController *settings = [[PVSettingsViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    [self.navigationController pushViewController:settings animated:YES];
}

- (void)detailsTapped:(id)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تفاصيل التطبيق" message:@"تطبيق بسيط لإدارة إعداداتك ومساحتك الشخصية بأمان." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"حسنًا" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)refreshFrontStateAnimated:(BOOL)animated {
    void (^update)(void) = ^{
        [self.activityIndicator stopAnimating];
        self.statusLabel.text = @"جاهزة للاستخدام";
        self.timeLabel.text = @"آخر تحديث: الآن";
    };
    [self.activityIndicator startAnimating];
    if (animated) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.18 * NSEC_PER_SEC)), dispatch_get_main_queue(), update);
    } else {
        update();
    }
}

@end
