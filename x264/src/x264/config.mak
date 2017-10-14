SRCPATH=.
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
LDFLAGS=-m32   -Wl,--large-address-aware -Wl,--nxcompat -Wl,--dynamicbase
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
default: cli
install: install-cli
SONAME=libx264-138.dll
IMPLIBNAME=libx264.dll.a
SOFLAGS=-shared -Wl,--out-implib,$(IMPLIBNAME) -Wl,--enable-auto-image-base 
default: lib-shared
install: install-lib-shared
LDFLAGSCLI =  -lshell32
CLI_LIBX264 = $(LIBX264)
