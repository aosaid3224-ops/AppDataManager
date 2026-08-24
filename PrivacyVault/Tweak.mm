// PHASE 1: Minimal — empty tweak, no classes, no hooks
// Goal: Prove PrivacyVault.dylib loads inside Preferences without PAC trap

#import <UIKit/UIKit.h>

__attribute__((constructor))
static void PVInitialize(void) {
    NSLog(@"[PrivacyVault] Phase 1: dylib loaded successfully");
}
