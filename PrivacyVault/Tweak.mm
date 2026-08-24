// PHASE 1: Minimal — empty tweak, no classes, no hooks
// Goal: Prove PrivacyVault.dylib loads inside Preferences without PAC trap

#import <UIKit/UIKit.h>

%ctor {
    // Empty constructor — just proves dylib loads
    NSLog(@"[PrivacyVault] Phase 1: dylib loaded successfully");
}
