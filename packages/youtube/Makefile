TARGET = iphone:clang:9.3:6.0
ARCHS = armv7

INSTALL_TARGET_PROCESSES = YouTube

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YouTubeFix
YouTubeFix_FILES = Tweak.xm $(THEOS_PROJECT_DIR)/../../shared/LFEngine.m
YouTubeFix_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/../../shared
YouTubeFix_FRAMEWORKS = UIKit Security
YouTubeFix_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk
