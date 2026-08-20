//
// SigningPlanReportViewController.m
//

#import "SigningPlanReportViewController.h"
#import "SigningPlan.h"
#import "SigningTarget.h"
#import "EntitlementSet.h"

@interface SigningPlanReportViewController ()
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UISegmentedControl *segmentControl;
@property (nonatomic, copy) NSString *reportText;
@property (nonatomic, copy) NSString *jsonText;
@end

@implementation SigningPlanReportViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"📋 خطة التوقيع";
    self.view.backgroundColor = [UIColor colorWithRed:0.02 green:0.02 blue:0.04 alpha:1.0];

    CGFloat w = self.view.bounds.size.width;
    CGFloat h = self.view.bounds.size.height;
    CGFloat safeTop = 0;
    if (@available(iOS 11.0, *)) {
        safeTop = self.view.safeAreaInsets.top;
    }

    // Segment
    self.segmentControl = [[UISegmentedControl alloc] initWithItems:@[@"📄 Report", @"🧾 JSON"]];
    self.segmentControl.frame = CGRectMake(16, safeTop + 8, w - 32, 32);
    self.segmentControl.selectedSegmentIndex = 0;
    self.segmentControl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    if (@available(iOS 13.0, *)) {
        self.segmentControl.selectedSegmentTintColor = [UIColor systemBlueColor];
        [self.segmentControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateNormal];
        [self.segmentControl setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateSelected];
    } else {
        self.segmentControl.tintColor = [UIColor systemBlueColor];
    }
    [self.segmentControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.segmentControl];

    // TextView
    self.textView = [[UITextView alloc] initWithFrame:CGRectMake(8, safeTop + 48, w - 16, h - safeTop - 100)];
    self.textView.backgroundColor = [UIColor colorWithWhite:0.06 alpha:1.0];
    self.textView.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    self.textView.font = [UIFont fontWithName:@"Menlo" size:10] ?: [UIFont systemFontOfSize:10];
    self.textView.editable = NO;
    self.textView.selectable = YES;
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.textView];

    // Close button
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(16, h - 44, w - 32, 36);
    closeBtn.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    [closeBtn setTitle:@"❌ إغلاق" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    closeBtn.layer.cornerRadius = 8;
    closeBtn.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [closeBtn addTarget:self action:@selector(closeTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeBtn];

    // Build texts
    if (self.signingPlan) {
        self.reportText = [self.signingPlan detailedReport];
        self.jsonText = [[NSString alloc] initWithData:
            [NSJSONSerialization dataWithJSONObject:[self.signingPlan dictionaryRepresentation]
                                            options:NSJSONWritingPrettyPrinted
                                              error:nil]
                                              encoding:NSUTF8StringEncoding] ?: @"{}";
        self.textView.text = self.reportText;
    } else {
        self.textView.text = @"No signing plan available.";
    }
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    self.textView.text = (sender.selectedSegmentIndex == 0) ? self.reportText : self.jsonText;
}

- (void)closeTapped:(UIButton *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
