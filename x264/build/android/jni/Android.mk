LOCAL_PATH:=$(call my-dir)
ROOT_PATH := $(LOCAL_PATH)
#include $(CLEAR_VARS)
APP_STL := stlport_static
LOCAL_CFLAGS += -O3
include $(CLEAR_VARS)
X264_PATH = ../../../src/x264
X264_HEADER_PATH := $(LOCAL_PATH)/../../../src/x264
LOCAL_C_INCLUDES += $(X264_HEADER_PATH) $(X264_HEADER_PATH)/common
LOCAL_SRC_FILES := \
    $(X264_PATH)/common/mc.c \
    $(X264_PATH)/common/predict.c \
    $(X264_PATH)/common/pixel.c \
    $(X264_PATH)/common/macroblock.c \
    $(X264_PATH)/common/frame.c \
    $(X264_PATH)/common/dct.c \
    $(X264_PATH)/common/cpu.c \
    $(X264_PATH)/common/cabac.c \
    $(X264_PATH)/common/common.c \
    $(X264_PATH)/common/osdep.c \
    $(X264_PATH)/common/rectangle.c \
    $(X264_PATH)/common/set.c \
    $(X264_PATH)/common/quant.c \
    $(X264_PATH)/common/deblock.c \
    $(X264_PATH)/common/vlc.c \
    $(X264_PATH)/common/mvpred.c \
    $(X264_PATH)/common/bitstream.c \
    $(X264_PATH)/encoder/analyse.c \
    $(X264_PATH)/encoder/me.c \
    $(X264_PATH)/encoder/ratecontrol.c \
    $(X264_PATH)/encoder/set.c \
    $(X264_PATH)/encoder/macroblock.c \
    $(X264_PATH)/encoder/cabac.c \
    $(X264_PATH)/encoder/cavlc.c \
    $(X264_PATH)/encoder/encoder.c \
    $(X264_PATH)/encoder/lookahead.c \
    $(X264_PATH)/common/threadpool.c \
    $(X264_PATH)/common/arm/asm.S \
    $(X264_PATH)/common/arm/bitstream-a.S \
    $(X264_PATH)/common/arm/cpu-a.S \
    $(X264_PATH)/common/arm/dct-a.S \
    $(X264_PATH)/common/arm/deblock-a.S \
    $(X264_PATH)/common/arm/mc-c.c \
    $(X264_PATH)/common/arm/mc-a.S \
    $(X264_PATH)/common/arm/pixel-a.S \
    $(X264_PATH)/common/arm/predict-a.S \
    $(X264_PATH)/common/arm/predict-c.c \
    $(X264_PATH)/common/arm/quant-a.S
    
LOCAL_ARM_MODE := arm
LOCAL_ARM_NEON := true
LOCAL_CFLAGS += -DHAVE_NEON=1 -DARCH_ARM=1 -DHAVE_ARMV6T=1 -DHAVE_ARMV6=1 -pie
LOCAL_CFLAGS += $(GLOBAL_CFLAGS)
LOCAL_CFLAGS += -O3 -fPIC -std=gnu99 -DHIGH_BIT_DEPTH=0 -DPIC=1 -Wdeprecated-declarations -mfloat-abi=softfp -mfpu=neon
LOCAL_LDFLAGS += -O3 -fPIE
LOCAL_DISABLE_FATAL_LINKER_WARNINGS := true
LOCAL_MODULE := libx264
include $(BUILD_SHARED_LIBRARY)

