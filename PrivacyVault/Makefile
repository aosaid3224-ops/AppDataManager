export THEOS_PACKAGE_SCHEME = rootless
TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = PrivacyVault

PrivacyVault_FILES = main.m AppDelegate.m PVDecoyViewController.m PVPassword1ViewController.m PVDummyViewController.m PVPassword2ViewController.m PVVaultViewController.m PVInitialSetupViewController.m PVPasswordStore.m PVSettingsViewController.m PVChangePasswordsViewController.m PVMediaVaultStore.m PVMediaLibraryViewController.m
PrivacyVault_CFLAGS = -fobjc-arc
PrivacyVault_FRAMEWORKS = UIKit Security Photos PhotosUI
PrivacyVault_BUNDLE_RESOURCE_DIRS = Resources
PrivacyVault_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
