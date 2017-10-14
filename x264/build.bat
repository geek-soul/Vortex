@if "%1"=="clean" goto clean
@if "%1"=="all" goto build
@if "%1"=="" goto build
:clean
cmd /C rmdir /S /Q obj
cmd /C rmdir /S /Q libs
@goto end

:build
@cmd /C rmdir /S /Q obj
@cmd /C rmdir /S /Q libs
cd build
cd android
ndk-build.cmd NDK_APPLICATION_MK=jni/Application.mk -j16
cd ..
cd ..
:end