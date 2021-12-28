TARGET := iphone:clang:latest:13.0
INSTALL_TARGET_PROCESSES = SpringBoard


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = senzuBeans

senzuBeans_FILES = Tweak.xm
senzuBeans_CFLAGS = -fobjc-arc

senzuBeans_PRIVATE_FRAMEWORKS = BatteryCenter
senzuBeans_FRAMEWORKS = IOKit
include $(THEOS_MAKE_PATH)/tweak.mk
