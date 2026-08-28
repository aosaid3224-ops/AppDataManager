#import "GlassIPACell.h"
#import "Core/IPAExtractor.h"

@interface GlassIPACell ()
@property (nonatomic, strong) UIVisualEffectView *glassView;
@property (nonatomic, strong) UIView *accentView;
@property (nonatomic, strong) UIImageView *ipaIconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *metadataLabel;
@property (nonatomic, strong) UIImageView *chevronView;
@end

@implementation GlassIPACell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.contentView.backgroundColor = UIColor.clearColor;
        [self buildGlassLayout];
    }
    return self;
}

- (void)buildGlassLayout {
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
    self.glassView = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.glassView.translatesAutoresizingMaskIntoConstraints = NO;
    self.glassView.layer.cornerRadius = 24.0;
    self.glassView.layer.masksToBounds = YES;
    self.glassView.layer.borderWidth = 0.0;
    [self.contentView addSubview:self.glassView];

    self.accentView = [[UIView alloc] init];
    self.accentView.translatesAutoresizingMaskIntoConstraints = NO;
    self.accentView.backgroundColor = [UIColor colorWithRed:0.82 green:0.10 blue:0.13 alpha:0.90];
    self.accentView.layer.cornerRadius = 2.5;
    [self.glassView.contentView addSubview:self.accentView];

    self.ipaIconView = [[UIImageView alloc] init];
    self.ipaIconView.translatesAutoresizingMaskIntoConstraints = NO;
    self.ipaIconView.contentMode = UIViewContentModeScaleAspectFill;
    self.ipaIconView.clipsToBounds = YES;
    self.ipaIconView.layer.cornerRadius = 15;
    self.ipaIconView.backgroundColor = [UIColor colorWithRed:0.60 green:0.06 blue:0.09 alpha:0.16];
    [self.glassView.contentView addSubview:self.ipaIconView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    self.titleLabel.textColor = UIColor.whiteColor;
    self.titleLabel.textAlignment = NSTextAlignmentNatural;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.82;
    [self.glassView.contentView addSubview:self.titleLabel];

    self.metadataLabel = [[UILabel alloc] init];
    self.metadataLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.metadataLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightMedium];
    self.metadataLabel.textColor = [UIColor colorWithRed:0.78 green:0.79 blue:0.82 alpha:0.82];
    self.metadataLabel.textAlignment = NSTextAlignmentNatural;
    self.metadataLabel.numberOfLines = 2;
    [self.glassView.contentView addSubview:self.metadataLabel];

    self.chevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.forward"]];
    self.chevronView.translatesAutoresizingMaskIntoConstraints = NO;
    self.chevronView.tintColor = [UIColor colorWithRed:0.82 green:0.16 blue:0.19 alpha:0.72];
    self.chevronView.contentMode = UIViewContentModeScaleAspectFit;
    [self.glassView.contentView addSubview:self.chevronView];

    [NSLayoutConstraint activateConstraints:@[
        [self.glassView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:4],
        [self.glassView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.glassView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [self.glassView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-4],
        [self.accentView.leadingAnchor constraintEqualToAnchor:self.glassView.contentView.leadingAnchor],
        [self.accentView.topAnchor constraintEqualToAnchor:self.glassView.contentView.topAnchor constant:18],
        [self.accentView.bottomAnchor constraintEqualToAnchor:self.glassView.contentView.bottomAnchor constant:-18],
        [self.accentView.widthAnchor constraintEqualToConstant:4],
        [self.ipaIconView.leadingAnchor constraintEqualToAnchor:self.glassView.contentView.leadingAnchor constant:20],
        [self.ipaIconView.centerYAnchor constraintEqualToAnchor:self.glassView.contentView.centerYAnchor],
        [self.ipaIconView.widthAnchor constraintEqualToConstant:58],
        [self.ipaIconView.heightAnchor constraintEqualToConstant:58],
        [self.chevronView.trailingAnchor constraintEqualToAnchor:self.glassView.contentView.trailingAnchor constant:-17],
        [self.chevronView.centerYAnchor constraintEqualToAnchor:self.glassView.contentView.centerYAnchor],
        [self.chevronView.widthAnchor constraintEqualToConstant:13],
        [self.chevronView.heightAnchor constraintEqualToConstant:18],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.ipaIconView.trailingAnchor constant:14],
        [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.chevronView.leadingAnchor constant:-12],
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.glassView.contentView.topAnchor constant:15],
        [self.metadataLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [self.metadataLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.chevronView.leadingAnchor constant:-12],
        [self.metadataLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:3],
        [self.metadataLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.glassView.contentView.bottomAnchor constant:-13]
    ]];
}

- (void)configureWithIPAInfo:(IPAExtractedInfo *)info {
    self.titleLabel.text = info.displayName ?: info.name ?: [info.filePath lastPathComponent];
    self.metadataLabel.text = [NSString stringWithFormat:@"%@  •  %@\n%@", info.version ?: @"غير معروف", info.bundleID ?: @"غير معروف", info.formattedSize ?: @"غير معروف"];
    self.ipaIconView.image = info.icon ?: [[UIImage systemImageNamed:@"doc.zipper"] imageWithTintColor:[UIColor colorWithWhite:1.0 alpha:0.70]];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    void (^changes)(void) = ^{
        self.glassView.transform = highlighted ? CGAffineTransformMakeScale(0.975, 0.975) : CGAffineTransformIdentity;
        self.glassView.alpha = highlighted ? 0.72 : 1.0;
    };
    if (animated) {
        [UIView animateWithDuration:0.26 delay:0 usingSpringWithDamping:0.72 initialSpringVelocity:0.2 options:UIViewAnimationOptionAllowUserInteraction animations:changes completion:nil];
    } else { changes(); }
}

- (void)playEntranceAnimationWithDelay:(NSTimeInterval)delay {
    self.glassView.alpha = 0.0;
    self.glassView.transform = CGAffineTransformMakeTranslation(0, 18);
    [UIView animateWithDuration:0.58 delay:delay usingSpringWithDamping:0.82 initialSpringVelocity:0.25 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self.glassView.alpha = 1.0;
        self.glassView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end
