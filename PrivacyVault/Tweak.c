// Absolute minimum — plain C, no Objective-C, no Logos, no NSLog
// Goal: Prove PrivacyVault.dylib loads in com.apple.Preferences without any crash

__attribute__((constructor))
static void init(void) {
    // Intentionally empty — do nothing
}
