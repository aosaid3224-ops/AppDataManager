export THEOS_PACKAGE_SCHEME = rootless
TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = PrivacyVault

PrivacyVault_FILES = main.m AppDelegate.m PVDecoyViewController.m PVPassword1ViewController.m PVDummyViewController.m PVPassword2ViewController.m PVVaultViewController.m
PrivacyVault_CFLAGS = -fobjc-arc
PrivacyVault_FRAMEWORKS = UIKit
PrivacyVault_INFOPLIST_FILE = Info.plist

include $(THEOS_MAKE_PATH)/application.mk
