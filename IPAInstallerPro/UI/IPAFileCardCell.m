#import "IPAFileCardCell.h"

@interface IPAFileCardCell ()
@property (nonatomic, strong, readwrite) UIImageView *ipaIconView;
@property (nonatomic, strong, readwrite) UILabel *titleLabel;
@property (nonatomic, strong, readwrite) UILabel *subtitleLabel;
@property (nonatomic, strong, readwrite) UILabel *metaLabel;
@property (nonatomic, strong, readwrite) UIButton *moreButton;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *statusDot;
@end

@implementation IPAFileCardCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (!self) return nil;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    self.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    self.contentView.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;

    _cardView = [[UIView alloc] init];
    _cardView.backgroundColor = [UIColor colorWithRed:0.095 green:0.105 blue:0.135 alpha:1.0];
    _cardView.layer.cornerRadius = 18.0;
    _cardView.layer.masksToBounds = YES;
    [self.contentView addSubview:_cardView];

    _ipaIconView = [[UIImageView alloc] init];
    _ipaIconView.contentMode = UIViewContentModeScaleAspectFit;
    _ipaIconView.translatesAutoresizingMaskIntoConstraints = NO;
    [_cardView addSubview:_ipaIconView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    _titleLabel.textColor = UIColor.whiteColor;
    _titleLabel.textAlignment = NSTextAlignmentRight;
    _titleLabel.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    _titleLabel.adjustsFontSizeToFitWidth = NO;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_cardView addSubview:_titleLabel];

    _subtitleLabel = [[UILabel alloc] init];
    _subtitleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    _subtitleLabel.textColor = [UIColor colorWithWhite:0.72 alpha:1.0];
    _subtitleLabel.textAlignment = NSTextAlignmentRight;
    _subtitleLabel.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    _subtitleLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_cardView addSubview:_subtitleLabel];

    _metaLabel = [[UILabel alloc] init];
    _metaLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    _metaLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
    _metaLabel.textAlignment = NSTextAlignmentRight;
    _metaLabel.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    _metaLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    _metaLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_cardView addSubview:_metaLabel];

    _statusDot = [[UIView alloc] init];
    _statusDot.layer.cornerRadius = 4.0;
    _statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    [_cardView addSubview:_statusDot];

    _moreButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_moreButton setTitle:@"•••" forState:UIControlStateNormal];
    _moreButton.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    _moreButton.tintColor = [UIColor colorWithWhite:0.86 alpha:1.0];
    _moreButton.accessibilityLabel = @"إجراءات العنصر";
    _moreButton.accessibilityHint = @"فتح قائمة الإجراءات";
    _moreButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_cardView addSubview:_moreButton];

    [NSLayoutConstraint activateConstraints:@[
        [_cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6.0],
        [_cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6.0],
        [_cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16.0],
        [_cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16.0],
        [_ipaIconView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-16.0],
        [_ipaIconView.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],
        [_ipaIconView.widthAnchor constraintEqualToConstant:48.0],
        [_ipaIconView.heightAnchor constraintEqualToConstant:48.0],
        [_moreButton.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:8.0],
        [_moreButton.centerYAnchor constraintEqualToAnchor:_cardView.centerYAnchor],
        [_moreButton.widthAnchor constraintEqualToConstant:44.0],
        [_moreButton.heightAnchor constraintEqualToConstant:44.0],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:_ipaIconView.leadingAnchor constant:-12.0],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_statusDot.trailingAnchor constant:8.0],
        [_titleLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:15.0],
        [_titleLabel.heightAnchor constraintEqualToConstant:22.0],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:1.0],
        [_subtitleLabel.heightAnchor constraintEqualToConstant:18.0],
        [_metaLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
        [_metaLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_metaLabel.topAnchor constraintEqualToAnchor:_subtitleLabel.bottomAnchor constant:1.0],
        [_metaLabel.heightAnchor constraintEqualToConstant:17.0],
        [_statusDot.leadingAnchor constraintEqualToAnchor:_moreButton.trailingAnchor constant:8.0],
        [_statusDot.centerYAnchor constraintEqualToAnchor:_metaLabel.centerYAnchor],
        [_statusDot.widthAnchor constraintEqualToConstant:8.0],
        [_statusDot.heightAnchor constraintEqualToConstant:8.0]
    ]];
    return self;
}

- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle meta:(NSString *)meta icon:(UIImage *)icon statusColor:(UIColor *)statusColor isChild:(BOOL)isChild {
    self.titleLabel.text = title ?: @"";
    self.subtitleLabel.text = subtitle ?: @"";
    self.metaLabel.text = meta ?: @"";
    self.ipaIconView.image = icon;
    self.statusDot.backgroundColor = statusColor ?: [UIColor colorWithWhite:0.45 alpha:1.0];
    self.showsChildIndent = isChild;
    self.cardView.backgroundColor = isChild
        ? [UIColor colorWithRed:0.075 green:0.085 blue:0.11 alpha:1.0]
        : [UIColor colorWithRed:0.105 green:0.115 blue:0.145 alpha:1.0];
    self.titleLabel.font = [UIFont systemFontOfSize:isChild ? 15 : 17 weight:isChild ? UIFontWeightMedium : UIFontWeightSemibold];
    self.ipaIconView.alpha = isChild ? 0.9 : 1.0;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    [UIView animateWithDuration:0.15 animations:^{
        self.cardView.backgroundColor = selected
            ? [UIColor colorWithRed:0.16 green:0.18 blue:0.24 alpha:1.0]
            : (self.showsChildIndent ? [UIColor colorWithRed:0.075 green:0.085 blue:0.11 alpha:1.0] : [UIColor colorWithRed:0.105 green:0.115 blue:0.145 alpha:1.0]);
    }];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.titleLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.metaLabel.text = nil;
    self.ipaIconView.image = nil;
    self.moreButton.tag = 0;
    self.showsChildIndent = NO;
}

@end
