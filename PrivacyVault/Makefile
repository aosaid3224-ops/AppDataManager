export THEOS_PACKAGE_SCHEME = rootless
TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PrivacyVault

PrivacyVault_FILES = Tweak.c
PrivacyVault_CFLAGS =

include $(THEOS_MAKE_PATH)/tweak.mk
