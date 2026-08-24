export THEOS_PACKAGE_SCHEME = rootless
TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = PrivacyVault

PrivacyVault_FILES = main.m AppDelegate.m PVDecoyViewController.m PVPassword1ViewController.m PVDummyViewController.m PVPassword2ViewController.m PVVaultViewController.m PVInitialSetupViewController.m PVPasswordStore.m
PrivacyVault_CFLAGS = -fobjc-arc
PrivacyVault_FRAMEWORKS = UIKit Security
PrivacyVault_BUNDLE_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/application.mk
