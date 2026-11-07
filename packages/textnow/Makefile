TARGET = iphone:clang:9.3:7.0
ARCHS = armv7

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TextNowLegacy

TextNowLegacy_FILES = \
	main.m \
	TNAppDelegate.m \
	TNRootViewController.m \
	TNClient.m \
	TNKeychain.m \
	TNModels.m \
	TNLoginViewController.m \
	TNConversationsViewController.m \
	TNThreadViewController.m \
	TNSettingsViewController.m \
	TNConversationCell.m \
	TNMessageCell.m

TextNowLegacy_FRAMEWORKS = UIKit Foundation Security QuartzCore
TextNowLegacy_CFLAGS = -fobjc-arc -Wall -Wno-deprecated-declarations
TextNowLegacy_INSTALL_PATH = /Applications
TextNowLegacy_CODESIGN_FLAGS = -S$(THEOS_PROJECT_DIR)/TextNowLegacy.entitlements

include $(THEOS_MAKE_PATH)/application.mk
