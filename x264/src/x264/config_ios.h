#define X264_BIT_DEPTH  8

#ifdef __arm__
#define HAVE_ARMV6 1
#define HAVE_ARMV6T2 1
#define HAVE_NEON 1
#define ARCH_ARM 1
#define HAVE_VECTOREXT 1
#elif __arm64__
#define ARCH_AARCH64 1
#define HAVE_ARMV6 0
#define HAVE_ARMV6T2 0
#define HAVE_NEON 0
#define ARCH_ARM 0
#define HAVE_VECTOREXT 0
#else
#define HAVE_ARMV6 0
#define HAVE_ARMV6T2 0
#define HAVE_NEON 0
#define ARCH_ARM 0
#define HAVE_VECTOREXT 0
#endif


#define SYS_MACOSX 1
#define HAVE_POSIXTHREAD 1
#define HAVE_THREAD 1
#define HAVE_LOG2F 1
#define fseek fseeko
#define ftell ftello
#define HAVE_GPL 1
#define HAVE_INTERLACED 1
#define HAVE_MALLOC_H 0
#define HAVE_ALTIVEC 0
#define HAVE_ALTIVEC_H 0
#define HAVE_MMX 0
#define HAVE_BEOSTHREAD 0
#define HAVE_WIN32THREAD 0
#define HAVE_VISUALIZE 0
#define HAVE_SWSCALE 0
#define HAVE_LAVF 0
#define HAVE_FFMS 0
#define HAVE_GPAC 0
#define HAVE_GF_MALLOC 0
#define HAVE_AVS 0
#define PIC 1
#define IPHONE 1
#define PREFIX
