#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "PVEntryViewController.h"

@interface PSSpecifier : NSObject
+ (instancetype)preferenceSpecifierNamed:(NSString *)name
                                  target:(id)target
                                     set:(SEL)set
                                     get:(SEL)get
                                  detail:(Class)detail
                                    cell:(int)cell
                                    edit:(Class)edit;
@end

@interface PSListController : UIViewController
- (NSArray *)specifiers;
@end

@interface PSUIPrefsListController : PSListController
@end

%group iOS15Up
%hook PSUIPrefsListController
- (NSArray *)specifiers {
    NSArray *orig = %orig;
    NSMutableArray *mutable = orig ? [orig mutableCopy] : [NSMutableArray array];

    BOOL alreadyAdded = NO;
    for (id spec in mutable) {
        if ([spec isKindOfClass:%c(PSSpecifier)]) {
            NSString *name = nil;
            @try { name = [spec valueForKey:@"name"]; } @catch (NSException *e) {}
            if ([name isEqualToString:@"التشخيص"]) { alreadyAdded = YES; break; }
        }
    }

    if (!alreadyAdded) {
        PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:@"التشخيص"
                                                           target:self
                                                              set:NULL
                                                              get:NULL
                                                           detail:[PVEntryViewController class]
                                                             cell:1
                                                             edit:Nil];
        [mutable addObject:spec];
    }

    return mutable;
}
%end
%end

%group iOS14Down
%hook PSListController
- (NSArray *)specifiers {
    NSArray *orig = %orig;
    NSString *className = NSStringFromClass([self class]);
    if (![className isEqualToString:@"PSListController"] && ![className hasSuffix:@"RootController"]) {
        return orig;
    }

    NSMutableArray *mutable = orig ? [orig mutableCopy] : [NSMutableArray array];

    BOOL alreadyAdded = NO;
    for (id spec in mutable) {
        NSString *name = nil;
        @try { name = [spec valueForKey:@"name"]; } @catch (NSException *e) {}
        if ([name isEqualToString:@"التشخيص"]) { alreadyAdded = YES; break; }
    }

    if (!alreadyAdded) {
        PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:@"التشخيص"
                                                           target:self
                                                              set:NULL
                                                              get:NULL
                                                           detail:[PVEntryViewController class]
                                                             cell:1
                                                             edit:Nil];
        [mutable addObject:spec];
    }

    return mutable;
}
%end
%end

%ctor {
    if (%c(PSUIPrefsListController)) {
        %init(iOS15Up);
    } else {
        %init(iOS14Down);
    }
}
