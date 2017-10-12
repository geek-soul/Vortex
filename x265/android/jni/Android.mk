LOCAL_PATH := $(call my-dir)

#---------- static module ----------#

COMMON_CPP_SRCS := \
    $(LOCAL_PATH)/../../common/cpu.cpp \
    $(LOCAL_PATH)/../../common/ipfilter.cpp \
    $(LOCAL_PATH)/../../common/threadpool.cpp \
    $(LOCAL_PATH)/../../common/param.cpp \
    $(LOCAL_PATH)/../../common/picyuv.cpp \
    $(LOCAL_PATH)/../../common/framedata.cpp \
    $(LOCAL_PATH)/../../common/bitstream.cpp \
    $(LOCAL_PATH)/../../common/pixel.cpp \
    $(LOCAL_PATH)/../../common/predict.cpp \
    $(LOCAL_PATH)/../../common/quant.cpp \
    $(LOCAL_PATH)/../../common/constants.cpp \
    $(LOCAL_PATH)/../../common/md5.cpp \
    $(LOCAL_PATH)/../../common/dct.cpp \
    $(LOCAL_PATH)/../../common/loopfilter.cpp \
    $(LOCAL_PATH)/../../common/primitives.cpp \
    $(LOCAL_PATH)/../../common/scalinglist.cpp \
    $(LOCAL_PATH)/../../common/piclist.cpp \
    $(LOCAL_PATH)/../../common/frame.cpp \
    $(LOCAL_PATH)/../../common/slice.cpp \
    $(LOCAL_PATH)/../../common/common.cpp \
    $(LOCAL_PATH)/../../common/threading.cpp \
    $(LOCAL_PATH)/../../common/lowres.cpp \
    $(LOCAL_PATH)/../../common/intrapred.cpp \
    $(LOCAL_PATH)/../../common/wavefront.cpp \
    $(LOCAL_PATH)/../../common/winxp.cpp \
    $(LOCAL_PATH)/../../common/shortyuv.cpp \
    $(LOCAL_PATH)/../../common/yuv.cpp \
    $(LOCAL_PATH)/../../common/deblock.cpp \
    $(LOCAL_PATH)/../../common/cudata.cpp \
    $(LOCAL_PATH)/../../common/version.cpp
    
COMMON_ARM_SRCS := \
    $(LOCAL_PATH)/../../common/arm/asm-primitives.cpp \
    $(LOCAL_PATH)/../../common/arm/asm.S \
    $(LOCAL_PATH)/../../common/arm/blockcopy8.S \
    $(LOCAL_PATH)/../../common/arm/cpu-a.S \
    $(LOCAL_PATH)/../../common/arm/dct-a.S \
    $(LOCAL_PATH)/../../common/arm/ipfilter8.S \
    $(LOCAL_PATH)/../../common/arm/mc-a.S \
    $(LOCAL_PATH)/../../common/arm/pixel-util.S \
    $(LOCAL_PATH)/../../common/arm/sad-a.S \
    $(LOCAL_PATH)/../../common/arm/ssd-a.S
    
COMMON_X86_SRCS := \
    $(LOCAL_PATH)/../../common/x86/blockcopy8.asm \
    $(LOCAL_PATH)/../../common/x86/const-a.asm \
    $(LOCAL_PATH)/../../common/x86/cpu-a.asm \
    $(LOCAL_PATH)/../../common/x86/dct8.asm \
    $(LOCAL_PATH)/../../common/x86/intrapred16.asm \
    $(LOCAL_PATH)/../../common/x86/intrapred8_allangs.asm \
    $(LOCAL_PATH)/../../common/x86/intrapred8.asm \
    $(LOCAL_PATH)/../../common/x86/ipfilter16.asm \
    $(LOCAL_PATH)/../../common/x86/ipfilter8.asm \
    $(LOCAL_PATH)/../../common/x86/loopfilter.asm \
    $(LOCAL_PATH)/../../common/x86/mc-a2.asm \
    $(LOCAL_PATH)/../../common/x86/mc-a.asm \
    $(LOCAL_PATH)/../../common/x86/pixel-32.asm \
    $(LOCAL_PATH)/../../common/x86/pixel-a.asm \
    $(LOCAL_PATH)/../../common/x86/pixeladd8.asm \
    $(LOCAL_PATH)/../../common/x86/pixel-util8.asm \
    $(LOCAL_PATH)/../../common/x86/sad16-a.asm \
    $(LOCAL_PATH)/../../common/x86/sad-a.asm \
    $(LOCAL_PATH)/../../common/x86/ssd-a.asm \
    $(LOCAL_PATH)/../../common/x86/x86inc.asm \
    $(LOCAL_PATH)/../../common/x86/x86util.asm
    
ENCODER_CPP_SRCS := \
    $(LOCAL_PATH)/../../encoder/analysis.cpp \
    $(LOCAL_PATH)/../../encoder/api.cpp \
    $(LOCAL_PATH)/../../encoder/bitcost.cpp \
    $(LOCAL_PATH)/../../encoder/dpb.cpp \
    $(LOCAL_PATH)/../../encoder/encoder.cpp \
    $(LOCAL_PATH)/../../encoder/entropy.cpp \
    $(LOCAL_PATH)/../../encoder/frameencoder.cpp \
    $(LOCAL_PATH)/../../encoder/framefilter.cpp \
    $(LOCAL_PATH)/../../encoder/level.cpp \
    $(LOCAL_PATH)/../../encoder/motion.cpp \
    $(LOCAL_PATH)/../../encoder/nal.cpp \
    $(LOCAL_PATH)/../../encoder/ratecontrol.cpp \
    $(LOCAL_PATH)/../../encoder/reference.cpp \
    $(LOCAL_PATH)/../../encoder/sao.cpp \
    $(LOCAL_PATH)/../../encoder/search.cpp \
    $(LOCAL_PATH)/../../encoder/sei.cpp \
    $(LOCAL_PATH)/../../encoder/slicetype.cpp \
    $(LOCAL_PATH)/../../encoder/weightPrediction.cpp \
    
COMMON_CPPFLAGS := \
    -frtti \
    -fexceptions

#---------- static module ----------#
include $(CLEAR_VARS)
LOCAL_MODULE     := common
LOCAL_ARM_MODULE := arm
    
LOCAL_CFLAGS     := -Wall -Wextra -Wshadow -std=gnu++11 -fPIC -Wno-array-bounds -ffast-math -fno-exceptions -fpermissive -frtti -Wno-maybe-uninitialized
LOCAL_CFLAGS     += -DEXPORT_C_API=1 -DHAVE_INT_TYPES_H=1 -DHIGH_BIT_DEPTH=0 -DX265_DEPTH=8 -DX265_NS=x265 -D__STDC_LIMIT_MACROS=1 -DHAVE_STRTOK_R
LOCAL_EXPORT_CFLAGS := $(LOCAL_CFLAGS)
LOCAL_SRC_FILES := $(COMMON_CPP_SRCS)
LOCAL_CPPFLAGS := $(COMMON_CPPFLAGS) -g

LOCAL_CFLAGS    += -DHAVE_NEON -DX265_ARCH_ARM
LOCAL_SRC_FILES += $(COMMON_ARM_SRCS)

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../../ $(LOCAL_PATH)/../../common $(LOCAL_PATH)/../../encoder
LOCAL_EXPORT_C_INCLUDES := $(LOCAL_C_INCLUDES)
include $(BUILD_STATIC_LIBRARY)
    
    
#---------- static module ----------#
    
include $(CLEAR_VARS)
LOCAL_MODULE     := encoder
LOCAL_ARM_MODULE := arm
LOCAL_SRC_FILES  := $(ENCODER_CPP_SRCS) $(LOCAL_PATH)/../../x265-extras.cpp
LOCAL_STATIC_LIBRARIES := common
include $(BUILD_STATIC_LIBRARY)
    
    
#---------- static module ----------#
    
include $(CLEAR_VARS)
LOCAL_MODULE     := input
LOCAL_ARM_MODULE := arm
LOCAL_SRC_FILES := \
    $(LOCAL_PATH)/../../input/input.cpp \
    $(LOCAL_PATH)/../../input/y4m.cpp \
    $(LOCAL_PATH)/../../input/yuv.cpp
    
LOCAL_C_INCLUDES := $(LOCAL_PATH)
LOCAL_STATIC_LIBRARIES := common
include $(BUILD_STATIC_LIBRARY)
    
    
#---------- static module ----------#
    
include $(CLEAR_VARS)
LOCAL_MODULE     := output
LOCAL_ARM_MODULE := arm
    
LOCAL_SRC_FILES := \
    $(LOCAL_PATH)/../../output/reconplay.cpp \
    $(LOCAL_PATH)/../../output/raw.cpp \
    $(LOCAL_PATH)/../../output/y4m.cpp \
    $(LOCAL_PATH)/../../output/yuv.cpp \
    $(LOCAL_PATH)/../../output/output.cpp
    
LOCAL_C_INCLUDES := $(LOCAL_PATH)/../../
LOCAL_STATIC_LIBRARIES := common
include $(BUILD_SHARED_LIBRARY)
    
#---------- shared module ----------#    
include $(CLEAR_VARS)
LOCAL_MODULE     := x265
LOCAL_ARM_MODULE := arm
LOCAL_WHOLE_STATIC_LIBRARIES := encoder input output
include $(BUILD_SHARED_LIBRARY)

#---------- binary module ----------#
#    
#include $(CLEAR_VARS)
#LOCAL_MODULE     := x265_test
#LOCAL_ARM_MODULE := arm
#LOCAL_SRC_FILES  := $(LOCAL_PATH)/../../x265-extras.cpp $(LOCAL_PATH)/../../x265.cpp
#LOCAL_C_INCLUDES := $(LOCAL_PATH)/../../
#LOCAL_STATIC_LIBRARIES := encoder input output
#include $(BUILD_EXECUTABLE)