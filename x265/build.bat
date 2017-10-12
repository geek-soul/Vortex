@echo off
cls
@echo ****************Start Building****************
cd android/jni
call ndk-build -j4 -e local_build=1 NDK_LOG=1
