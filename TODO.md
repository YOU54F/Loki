# Building for MacOS Hosts

- [X] Convert `build.sh` to build on MacOS
- [X] Build for `freebsd`
- [X] Modify `build.sh` to build on MacOS (new) or Linux (old)
- [ ] Build Homebrew formula

## MacOS requirements

> More deps probably required, many programs installed on my current host

- Command line tools

    brew install texinfo

## compile errors

- https://github.com/AlwaysRightInstitute/swift-mac2arm-x-compile-toolchain/issues/1

```console
: error: expected expression : once_(PTHREAD_ONCE_INIT)
```

Problem was connected to using macOS

Problem is documented at: https://sourceware.org/bugzilla/show_bug.cgi?id=23424

### Solution 1

Solution is to patch the batch file (build_arm64v8_ubuntu_cross_compilation_toolchain) by adding:
`export CXXFLAGS="-std=c++11 -Wno-c++11-narrowing" (at line 18)`

### Solution 2

- https://www.jaredwolff.com/cross-compiling-on-mac-osx-for-raspberry-pi/#show1

In `gold/gold-threads.cc`

```patch
diff --git a/gold/gold-threads.cc b/gold/gold-threads.cc
index f4cf063..8497578 100644
--- a/gold/gold-threads.cc
+++ b/gold/gold-threads.cc
@@ -285,8 +285,7 @@ class Once_initialize
 {
  public:
   Once_initialize()
-    : once_(PTHREAD_ONCE_INIT)
-  { }
+  {once_.__sig = _PTHREAD_ONCE_SIG_init; once_.__opaque[0] = 0;}
 
   // Return a pointer to the pthread_once_t variable.
   pthread_once_t*
```


## logs

```console
Libraries have been installed in:
   /tmp/loki/x86_64-unknown-freebsd12.3/lib

If you ever happen to want to link against installed libraries
in a given directory, LIBDIR, you must either use libtool, and
specify the full pathname of the library, or use the `-LLIBDIR'
flag during linking and do at least one of the following:
   - add LIBDIR to the `LD_LIBRARY_PATH' environment variable
     during execution
   - add LIBDIR to the `LD_RUN_PATH' environment variable
     during linking
   - use the `-Wl,-rpath -Wl,LIBDIR' linker flag

See any operating system documentation about shared libraries for
more information, such as the ld(1) and ld.so(8) manual pages.
```


## error riscv intel

```console
echo timestamp > s-check
yes
checking for dlfcn.h... ../../gcc/config/riscv/genrvv-type-indexer.cc:118:30: error: no member named 'log2' in namespace 'std'; did you mean simply 'log2'?
    elmul_log2 = lmul_log2 - std::log2 (sew / eew);
                             ^~~~~~~~~
                             log2
/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/c++/v1/math.h:1463:1: note: 'log2' declared here
log2(_A1 __lcpp_x) _NOEXCEPT {return ::log2((double)__lcpp_x);}
^
../../gcc/config/riscv/genrvv-type-indexer.cc:120:30: error: no member named 'log2' in namespace 'std'; did you mean simply 'log2'?
    elmul_log2 = lmul_log2 + std::log2 (eew / sew);
                             ^~~~~~~~~
                             log2
/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/c++/v1/math.h:1463:1: note: 'log2' declared here
log2(_A1 __lcpp_x) _NOEXCEPT {return ::log2((double)__lcpp_x);}
^
```