TARGET = iphone:clang:9.3:6.0
ARCHS = armv7

INSTALL_TARGET_PROCESSES = Messenger

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MessengerFix
MessengerFix_FILES = Tweak.xm $(THEOS_PROJECT_DIR)/../../shared/LFEngine.m
MessengerFix_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/../../shared
MessengerFix_FRAMEWORKS = UIKit Security
MessengerFix_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk
