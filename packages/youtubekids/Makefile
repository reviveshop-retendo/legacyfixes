TARGET = iphone:clang:9.3:6.0
ARCHS = armv7

INSTALL_TARGET_PROCESSES = YouTubeKids

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YouTubeKidsFix
YouTubeKidsFix_FILES = Tweak.xm $(THEOS_PROJECT_DIR)/../../shared/LFEngine.m
YouTubeKidsFix_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/../../shared
YouTubeKidsFix_FRAMEWORKS = UIKit Security
YouTubeKidsFix_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk
