# Makefile
#include config.mak
SRCPATH=../../../video/x264
prefix=/usr/local
exec_prefix=${prefix}
bindir=${exec_prefix}/bin
libdir=${exec_prefix}/lib
includedir=${prefix}/include
ARCH=X86
SYS=WINDOWS
CC=gcc
CFLAGS=-Wshadow -O3 -ffast-math -m32  -Wall -I. -I$(SRCPATH) -march=i686 -mfpmath=sse -msse -std=gnu99 -mpreferred-stack-boundary=5 -fomit-frame-pointer -fno-tree-vectorize -fno-zero-initialized-in-bss
DEPMM=-MM -g0
DEPMT=-MT
LD=gcc -o 
LDFLAGS=-m32 -Wl,--large-address-aware -Wl,--nxcompat -Wl,--dynamicbase
LIBX264=libx264.a
AR=ar rc 
RANLIB=ranlib
STRIP=strip
AS=yasm
ASFLAGS= -O2 -f win32 -DPREFIX -DHAVE_ALIGNED_STACK=1 -DHIGH_BIT_DEPTH=0 -DBIT_DEPTH=8
RC=windres
RCFLAGS=--target=pe-i386  -I. -o 
EXE=.exe
HAVE_GETOPT_LONG=1
DEVNULL=NUL
PROF_GEN_CC=-fprofile-generate
PROF_GEN_LD=-fprofile-generate
PROF_USE_CC=-fprofile-use
PROF_USE_LD=-fprofile-use
HAVE_OPENCL=no
default: lib-shared
install: install-lib-shared
SONAME=libx264-138.dll
IMPLIBNAME=libx264.dll.a
SOFLAGS=-shared -Wl,--out-implib,$(IMPLIBNAME) -Wl,--enable-auto-image-base 
default: lib-shared
install: install-lib-shared
LDFLAGSCLI =  -lshell32
CLI_LIBX264 = $(LIBX264)

vpath %.c $(SRCPATH)
vpath %.h $(SRCPATH)
vpath %.S $(SRCPATH)
vpath %.asm $(SRCPATH)
vpath %.rc $(SRCPATH)

GENERATED =

all: default
default:

SRCS = common/mc.c common/predict.c common/pixel.c common/macroblock.c \
       common/frame.c common/dct.c common/cpu.c common/cabac.c \
       common/common.c common/osdep.c common/rectangle.c \
       common/set.c common/quant.c common/deblock.c common/vlc.c \
       common/mvpred.c common/bitstream.c common/win32thread.c common/threadpool.c \
       encoder/analyse.c encoder/me.c encoder/ratecontrol.c \
       encoder/set.c encoder/macroblock.c encoder/cabac.c \
       encoder/cavlc.c encoder/encoder.c encoder/lookahead.c
       
SRCSO =
OBJS =
OBJSO =
OBJCLI =

OBJCHK = tools/checkasm.o

CONFIG := $(shell cat $(SRCPATH)/win_config.h)

# MMX/SSE optims
ifneq ($(AS),)
X86SRC0 = const-a.asm cabac-a.asm dct-a.asm deblock-a.asm mc-a.asm \
          mc-a2.asm pixel-a.asm predict-a.asm quant-a.asm \
          cpu-a.asm dct-32.asm bitstream-a.asm
ifneq ($(findstring HIGH_BIT_DEPTH, $(CONFIG)),)
X86SRC0 += sad16-a.asm
else
X86SRC0 += sad-a.asm
endif
X86SRC = $(X86SRC0:%=common/x86/%)

ifeq ($(ARCH),X86)
ARCH_X86 = yes
ASMSRC   = $(X86SRC) common/x86/pixel-32.asm
ASFLAGS += -DARCH_X86_64=0
endif

ifeq ($(ARCH),X86_64)
ARCH_X86 = yes
ASMSRC   = $(X86SRC:-32.asm=-64.asm) common/x86/trellis-64.asm
ASFLAGS += -DARCH_X86_64=1
endif

ifdef ARCH_X86
ASFLAGS += -I$(SRCPATH)/common/x86/
SRCS   += common/x86/mc-c.c common/x86/predict-c.c
OBJASM  = $(ASMSRC:%.asm=%.o)
$(OBJASM): common/x86/x86inc.asm common/x86/x86util.asm
OBJCHK += tools/checkasm-a.o
endif
endif

ifeq ($(SYS),WINDOWS)
OBJCLI += $(if $(RC), x264res.o)
ifneq ($(SONAME),)
SRCSO  += x264dll.c
OBJSO  += $(if $(RC), x264res.dll.o)
endif
endif

OBJS   += $(SRCS:%.c=%.o)
#OBJCLI += $(SRCCLI:%.c=%.o)
OBJSO  += $(SRCSO:%.c=%.o)

.PHONY: all default fprofiled clean distclean install uninstall lib-static lib-shared cli install-lib-dev install-lib-static install-lib-shared install-cli

cli: x264$(EXE)
lib-static: $(LIBX264)
lib-shared: $(SONAME)

$(LIBX264): $(GENERATED) .depend $(OBJS) $(OBJASM)
	rm -f $(LIBX264)
	$(AR)$@ $(OBJS) $(OBJASM)
	$(if $(RANLIB), $(RANLIB) $@)

$(SONAME): $(GENERATED) .depend $(OBJS) $(OBJASM) $(OBJSO)
	$(LD)$@ $(OBJS) $(OBJASM) $(OBJSO) $(SOFLAGS) $(LDFLAGS)

ifneq ($(EXE),)
.PHONY: x264 checkasm
x264: x264$(EXE)
checkasm: checkasm$(EXE)
endif

x264$(EXE): $(GENERATED) .depend $(OBJCLI) $(CLI_LIBX264)
	$(LD)$@ $(OBJCLI) $(CLI_LIBX264) $(LDFLAGSCLI) $(LDFLAGS)

checkasm$(EXE): $(GENERATED) .depend $(OBJCHK) $(LIBX264)
	$(LD)$@ $(OBJCHK) $(LIBX264) $(LDFLAGS)

$(OBJS) $(OBJASM) $(OBJSO) $(OBJCLI) $(OBJCHK): .depend

%.o: %.asm
	$(AS) $(ASFLAGS) -o $@ $<
	-@ $(if $(STRIP), $(STRIP) -x $@) # delete local/anonymous symbols, so they don't show up in oprofile

%.o: %.S
	$(AS) $(ASFLAGS) -o $@ $<
	-@ $(if $(STRIP), $(STRIP) -x $@) # delete local/anonymous symbols, so they don't show up in oprofile

%.dll.o: %.rc x264.h
	$(RC) $(RCFLAGS)$@ -DDLL $<

%.o: %.rc x264.h
	$(RC) $(RCFLAGS)$@ $<

.depend: config.mak
	@rm -f .depend
	@$(foreach SRC, $(addprefix $(SRCPATH)/, $(SRCS) $(SRCCLI) $(SRCSO)), $(CC) $(CFLAGS) $(SRC) $(DEPMT) $(SRC:$(SRCPATH)/%.c=%.o) $(DEPMM) 1>> .depend;)

config.mak:
	./configure

depend: .depend
ifneq ($(wildcard .depend),)
include .depend
endif

SRC2 = $(SRCS) $(SRCCLI)
# These should cover most of the important codepaths
OPT0 = --crf 30 -b1 -m1 -r1 --me dia --no-cabac --direct temporal --ssim --no-weightb
OPT1 = --crf 16 -b2 -m3 -r3 --me hex --no-8x8dct --direct spatial --no-dct-decimate -t0  --slice-max-mbs 50
OPT2 = --crf 26 -b4 -m5 -r2 --me hex --cqm jvt --nr 100 --psnr --no-mixed-refs --b-adapt 2 --slice-max-size 1500
OPT3 = --crf 18 -b3 -m9 -r5 --me umh -t1 -A all --b-pyramid normal --direct auto --no-fast-pskip --no-mbtree
OPT4 = --crf 22 -b3 -m7 -r4 --me esa -t2 -A all --psy-rd 1.0:1.0 --slices 4
OPT5 = --frames 50 --crf 24 -b3 -m10 -r3 --me tesa -t2
OPT6 = --frames 50 -q0 -m9 -r2 --me hex -Aall
OPT7 = --frames 50 -q0 -m2 -r1 --me hex --no-cabac

ifeq (,$(VIDS))
fprofiled:
	@echo 'usage: make fprofiled VIDS="infile1 infile2 ..."'
	@echo 'where infiles are anything that x264 understands,'
	@echo 'i.e. YUV with resolution in the filename, y4m, or avisynth.'
else
fprofiled:
	$(MAKE) clean
	$(MAKE) x264$(EXE) CFLAGS="$(CFLAGS) $(PROF_GEN_CC)" LDFLAGS="$(LDFLAGS) $(PROF_GEN_LD)"
	$(foreach V, $(VIDS), $(foreach I, 0 1 2 3 4 5 6 7, ./x264$(EXE) $(OPT$I) --threads 1 $(V) -o $(DEVNULL) ;))
	rm -f $(SRC2:%.c=%.o)
	$(MAKE) CFLAGS="$(CFLAGS) $(PROF_USE_CC)" LDFLAGS="$(LDFLAGS) $(PROF_USE_LD)"
	rm -f $(SRC2:%.c=%.gcda) $(SRC2:%.c=%.gcno) *.dyn pgopti.dpi pgopti.dpi.lock
endif

clean:
	rm -f $(OBJS) $(OBJASM) $(OBJCLI) $(OBJSO) $(SONAME) *.a *.lib *.exp *.pdb x264 x264.exe .depend TAGS
	rm -f checkasm checkasm.exe $(OBJCHK) $(GENERATED) x264_lookahead.clbin
	rm -f $(SRC2:%.c=%.gcda) $(SRC2:%.c=%.gcno) *.dyn pgopti.dpi pgopti.dpi.lock

distclean: clean
	rm -f config.mak x264_config.h config.h config.log x264.pc x264.def

install-cli: cli
	install -d $(DESTDIR)$(bindir)
	install x264$(EXE) $(DESTDIR)$(bindir)

install-lib-dev:
	install -d $(DESTDIR)$(includedir)
	install -d $(DESTDIR)$(libdir)
	install -d $(DESTDIR)$(libdir)/pkgconfig
	install -m 644 $(SRCPATH)/x264.h $(DESTDIR)$(includedir)
	install -m 644 x264_config.h $(DESTDIR)$(includedir)
	install -m 644 x264.pc $(DESTDIR)$(libdir)/pkgconfig

install-lib-static: lib-static install-lib-dev
	install -m 644 $(LIBX264) $(DESTDIR)$(libdir)
	$(if $(RANLIB), $(RANLIB) $(DESTDIR)$(libdir)/$(LIBX264))

install-lib-shared: lib-shared install-lib-dev
ifneq ($(IMPLIBNAME),)
	install -d $(DESTDIR)$(bindir)
	install -m 755 $(SONAME) $(DESTDIR)$(bindir)
	install -m 644 $(IMPLIBNAME) $(DESTDIR)$(libdir)
else ifneq ($(SONAME),)
	ln -f -s $(SONAME) $(DESTDIR)$(libdir)/libx264.$(SOSUFFIX)
	install -m 755 $(SONAME) $(DESTDIR)$(libdir)
endif

uninstall:
	rm -f $(DESTDIR)$(includedir)/x264.h $(DESTDIR)$(includedir)/x264_config.h $(DESTDIR)$(libdir)/libx264.a
	rm -f $(DESTDIR)$(bindir)/x264$(EXE) $(DESTDIR)$(libdir)/pkgconfig/x264.pc
ifneq ($(IMPLIBNAME),)
	rm -f $(DESTDIR)$(bindir)/$(SONAME) $(DESTDIR)$(libdir)/$(IMPLIBNAME)
else ifneq ($(SONAME),)
	rm -f $(DESTDIR)$(libdir)/$(SONAME) $(DESTDIR)$(libdir)/libx264.$(SOSUFFIX)
endif

etags: TAGS

TAGS:
	etags $(SRCS)