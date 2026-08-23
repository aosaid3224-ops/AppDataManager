TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PrivacyVault

PrivacyVault_FILES = Tweak.xm PVEntryViewController.m PVPasswordViewController.m PVDummyViewController.m
PrivacyVault_CFLAGS = -fobjc-arc
PrivacyVault_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/tweak.mk
