THEOS_PACKAGE_SCHEME = rootless
TARGET := iphone:clang:latest:15.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = IPAInstallerPro

IPAInstallerPro_FILES = AppDelegate.m main.m UI/MainViewController.m UI/AppDetailsViewController.m UI/IPAFileBrowserViewController.m UI/IPAInstallViewController.m UI/InstallationProgressViewController.m UI/InstalledAppsViewController.m UI/SettingsViewController.m Core/DirectInstallationProvider.m Core/InstallationEngine.m Core/InstallationProvider.m Core/ApplicationManager.m Core/DependencyManager.m Core/IPAValidator.m Core/IPAExtractor.m Core/CapabilityManager.m Core/RootlessManager.m Core/JailbreakEnvironment.m Core/VerificationEngine.m Core/Logger.m Core/OperationLog.m Core/OperationRecord.m Core/RuntimeDiagnostics.m Core/MachOAnalyzer.m Core/IPAStructuralResult.m Core/IPAStructuralAnalyzer.m

IPAInstallerPro_FRAMEWORKS = UIKit Foundation CoreGraphics
IPAInstallerPro_PRIVATE_FRAMEWORKS = MobileCoreServices
IPAInstallerPro_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -I./Core -fno-autolink
IPAInstallerPro_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

TOOL_NAME = ipainstallerpro_helper

ipainstallerpro_helper_FILES = helper.c
ipainstallerpro_helper_CFLAGS = -fobjc-arc
ipainstallerpro_helper_CODESIGN_FLAGS = -Sentitlements.plist
ipainstallerpro_helper_INSTALL_PATH = /usr/bin

include $(THEOS_MAKE_PATH)/tool.mk
