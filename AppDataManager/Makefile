export TARGET = iphone:clang:latest:15.0
export ARCHS = arm64 arm64e

THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = AppDataManager

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = AppDataManager

AppDataManager_FILES = main.m AppDelegate.m MainViewController.m AppDetailViewController.m BackupManagerViewController.m SettingsViewController.m AppDataManager.m
AppDataManager_FRAMEWORKS = UIKit CoreGraphics
AppDataManager_PRIVATE_FRAMEWORKS = MobileCoreServices
AppDataManager_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable
AppDataManager_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

# Dopamine 3.0 / Rootless specific
after-install::
	install.exec "uicache -p /var/jb/Applications/AppDataManager.app || uicache -p /Applications/AppDataManager.app || true"

# Force dpkg-deb to use xz compression (lzma may not be supported on iOS dpkg)
export THEOS_PLATFORM_DEB_COMPRESSION_TYPE = xz
