export PACKAGE_VERSION := 5.1.2
export ARCHS := arm64 arm64e
export TARGET := iphone:clang:16.5:14.0

INSTALL_TARGET_PROCESSES := backboardd druid pasted

SUBPROJECTS += Core
SUBPROJECTS += Helper
SUBPROJECTS += Preferences
SUBPROJECTS += Updater
SUBPROJECTS += ScriptRunner

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

before-package::
	$(ECHO_NOTHING)sed 's|@KAYOKO_INSTALL_PREFIX@|$(THEOS_PACKAGE_INSTALL_PREFIX)|g' "$(THEOS_LAYOUT_DIR)/DEBIAN/postinst" > "$(THEOS_STAGING_DIR)/DEBIAN/postinst"$(ECHO_END)
	$(ECHO_NOTHING)chmod 755 "$(THEOS_STAGING_DIR)/DEBIAN/postinst"$(ECHO_END)
