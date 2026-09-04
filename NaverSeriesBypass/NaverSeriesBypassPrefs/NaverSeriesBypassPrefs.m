#import <Preferences/Preferences.h>

@interface NaverSeriesBypassPrefsListController : PSListController
@end

@implementation NaverSeriesBypassPrefsListController
- (id)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}
@end
