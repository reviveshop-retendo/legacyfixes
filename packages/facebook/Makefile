TARGET = iphone:clang:9.3:6.0
ARCHS = armv7

INSTALL_TARGET_PROCESSES = Facebook

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FacebookFix FacebookSystemFix

FacebookFix_FILES = Tweak.xm $(THEOS_PROJECT_DIR)/../../shared/LFEngine.m
FacebookFix_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/../../shared
FacebookFix_FRAMEWORKS = UIKit Security
FacebookFix_LIBRARIES = substrate

FacebookSystemFix_FILES = FBSystemFix.xm
FacebookSystemFix_FRAMEWORKS = Foundation
FacebookSystemFix_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk
