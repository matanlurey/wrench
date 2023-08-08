# wrench

Some personal docs/tools for developing Impeller.

If any content in this repository is useful to you, feel free to use it. As I'm
super new, it's hard to understand if any of this is _generally_ useful, and if
it is I'll move it to a more appropriate place.

## Why Impeller

[Skia](https://skia.org/) is a 2D graphics library written in C++. It is used
by Flutter to render graphics on the screen. Skia is a very large library, and
supports many different platforms and use cases. Flutter uses a subset of Skia.

For example, Skia [generates shaders on the fly](https://crsrc.org/c/cc/paint/paint_shader.cc;l=83-105)
for gradients, generating their own `SkSl` (Skia Shader Language) code, and
(at runtime) translate that into the GPU-specific shader language, and only then
compile and link the shader.

The [equivalent code in Impeller](https://github.com/flutter/engine/blob/64e88e8870adf8fcdc8fd602a669fe6aea38d18b/impeller/entity/shaders/linear_gradient_fill.frag) is compiled ahead of time
for the target GPU.

## Building the engine

The engine is built using [`gn`](https://gn.googlesource.com/gn/), which is a
"meta-build system" that generates build files for the actual build system
(`ninja` in this case). The engine build is configured using `BUILD.gn` files.

This document assumes `gclient sync` has been run and the `src/flutter`
directory is present.

```bash
# Assumes you're in `$ENGINE/src`.
#
# Despite the name, this is not actually the gn binary. It's a wrapper script
# written in Python that invokes the gn binary, and sometimes the arguments are
# different (i.e. "enable_impeller_vulkan" versus "impeller_enable_vulkan").
./flutter/tools/gn
```

Common invocations:

```bash
# Assumes you're in `$ENGINE/src`.

# Build a host (i.e. on my Mac, a macOS binary) debug build.
#
# Note the "--mac-cpu arm64" is not required, but without it on M1 Macs the x64
# build is used, which is slower because it goes through Rosetta (the x86_64
# emulator).
./flutter/tools/gn --unopt --mac-cpu arm64

# Build an android debug build with Vulkan enabled and Vulkan validation layers.
./flutter/tools/gn --unopt --android --android-cpu=arm64 --enable-vulkan
```

Frequently used arguments:

| Name                   | GN Arg                            | Description                                              |
| ---------------------- | --------------------------------- | -------------------------------------------------------- |
| `android`              | `target_os=android`               | Build for Android.                                       |
| `android-cpu`          | -                                 | Build for a specific Android CPU. Defaults to `arm`.     |
| `enable-vulkan`        | `enable_vulkan`                   | Enable Vulkan.                                           |
| `enable-vulkan-layers` | `enable_vulkan_validation_layers` | Enable Vulkan validation layers.                         |
| `unoptimized`, `unopt` | `is_debug`                        | Set a bunch[^1] of flags you would want when developing. |

See also:

- [GN Quick Start Guide](https://gn.googlesource.com/gn/+/HEAD/docs/quick_start.md)
- [Setting up the Engine development environment](https://github.com/flutter/flutter/wiki/Setting-up-the-Engine-development-environment)
- [Compiling the engine](https://github.com/flutter/flutter/wiki/Compiling-the-engine)

[^1]:
    In practice, [this roughly covers](https://github.com/search?q=repo%3Aflutter%2Fengine%20is_debug&type=code):
    (1) enables asserts in Dart (`--enable_asserts`), (2) calls `glGetError`
    after each OpenGL call (in Impeller), (3) does not strip symbols from
    compiled C++ code (i.e. `.so` files produced by `clang`), and (4) disables
    link-time optimization (LTO).

### Enabling Impeller

Impeller is always compiled, but it's not always enabled. To enable it, you need
to either set a flag in `flutter run` (which will enable impeller for a single
session):

```bash
# Assumes you're in the path to a Flutter app, i.e. `flutter_gallery`.
fl run \
  --local-engine-src-path=$ENGINE \
  --local-engine=android_debug_unopt_arm64 \
  --enable-impeller
```

However, if you open the app again (i.e. on the phone), or want to use another
command or tool (i.e. Android GPU Inspector), the flag will not persist. For
that reason, it's better to set the flag in the `AndroidManifest.xml` file:

```xml
<!-- Assumes you're modifying $APP/android/app/src/main/AndroidManifest.xml -->
<manifest ...>
  <application ...>
    <meta-data
      android:name="io.flutter.embedding.android.EnableImpeller"
      android:value="true" />
  </application>
```

### Enabling Vulkan

Vulkan is disabled by default. To enable it, you need to pass the
`--enable-vulkan` flag to `gn` (see above).

```bash
# Assumes you're in `$ENGINE/src`.
./flutter/tools/gn --unopt --android --android-cpu=arm64 --enable-vulkan
```

It's worth noting to get proper IDE (i.e. VSCode) completion, i.e. for files
that directly or indirectly import Vulkan headers, you need your `clangd`'s
`compile-commands-dir` to point to a directory where Vulkan headers were
included:

```json
"clangd.arguments": [
  "--compile-commands-dir=/Users/%NAME%/Developer/engine/src/out/android_debug_unopt_arm64"
]
```

### Using Goma

[Goma](https://chromium.googlesource.com/infra/goma/client/) is a distributed
compiler that builds C/C++ code in the cloud. It's sometimes used by the Flutter
engine team to speed up builds (it's not required, and some do not use it at
all). Goma has to be setup and authenticated before it can be used.

```py
# In `.gclient`; e.g. `$HOME/engine/.gclient`, add the following.

solutions = [
  {
    "custom_vars": {
      "use_cipd_goma": True,
    },
  },
]
```

In `$ENGINE/buildtools/mac-x64/goma` (or similar), you should have `goma_ctl.py`:

```bash
$ ./buildtools/mac-x64/goma/goma_ctl.py status
Login as ***@***.***
Ready to use Goma service at https://goma.chromium.org

# If needed (i.e. above command fails), run:
$ ./buildtools/mac-x64/goma/goma_auth.py login
```

And then, on a reboot:

```bash
./buildtools/mac-x64/goma/goma_ctl.py ensure_start
```

### Running Demos

For example, Flutter gallery:

```bash
# Assumes "fl" is an alias for your local flutter (framework) checkout.
cd $FRAMEWORK/dev/integration_tests/flutter_gallery
fl run \
  --local-engine-src-path=$ENGINE \
  --local-engine=android_debug_unopt_arm64
```

### Using VSCode

Here is my `settings.json` (`$ENGINE/.vscode/settings.json`):

```json
{
  "C_Cpp.intelliSenseEngine": "disabled",
  "[cpp]": {
    "editor.defaultFormatter": "xaver.clang-format"
  },
  "[objective-cpp]": {
    "editor.defaultFormatter": "xaver.clang-format"
  },
  "search.followSymlinks": true,
  "search.quickOpen.includeHistory": true,
  "search.quickOpen.includeSymbols": false,
  "search.useIgnoreFiles": false,
  "search.exclude": {
    "out/**": true
  },
  "task.quickOpen.showAll": true,
  "task.quickOpen.skip": false,
  "clangd.path": "/Users/%NAME%/Developer/engine/src/buildtools/mac-arm64/clang/bin/clangd",
  "clangd.arguments": [
    "--compile-commands-dir=/Users/%NAME%/Developer/engine/src/out/android_debug_unopt_arm64"
  ],
  "clang-format.executable": "/Users/%NAME%/Developer/engine/src/buildtools/mac-arm64/clang/bin/clang-format",
  "dart.onlyAnalyzeProjectsWithOpenFiles": true,
  "[dart]": {
    "editor.tabSize": 2,
    "editor.insertSpaces": true,
    "editor.detectIndentation": false,
    "editor.suggest.insertMode": "replace",
    "editor.defaultFormatter": "Dart-Code.dart-code",
    "editor.inlayHints.enabled": "offUnlessPressed",
    "editor.formatOnSave": false,
    "editor.formatOnType": false
  }
}
```

## Contributing

### Playground tests

Impeller has a "playground", or a utility for interactive experimenting with
the Impeller rendering subsystem, with a focus on iterating on rendering
behavior before writing tests.

The playground is _not_ a Flutter app, and is minimal compared to Flutter.

See also:

- [Impeller: Frequently Asked Questions](https://github.com/flutter/engine/blob/main/impeller/docs/faq.md)
- [The Impeller Playground](https://github.com/flutter/engine/blob/0713d91c2e6485062555c20bcdee04d2e1b4fad4/impeller/playground/README.md)

### Running the playground

```bash
# Build the playground.
ninja -C out/host_debug_unopt_arm64 impeller_unittests

# Run Impeller's unit tests, pausing on playground tests.
$ $ENGINE/out/host_debug_unopt_arm64/impeller_unittests --enable_playground
```

![Screenshot 2023-07-27 at 5 40 51 PM](https://github.com/flutter/flutter/assets/168174/ffd033b0-f8ff-4f90-9e1f-eec548af2a6d)

Note this will run _every_ Impeller test, which at the time of this writing is
LOTS. Use [the `--gtest_filter` flag](https://google.github.io/googletest/advanced.html)
to filter tests.

```bash
$ $ENGINE/out/host_debug_unopt_arm64/impeller_unittests \
  --enable_playground \
  --gtest_filter="*Gradient*"
```

## Tips

### Change Open File Limit on Mac

When I was first [using Goma](#using-goma), I ran into the following error:

```bash
# Do not use autoninja (from depot_tools), as it doesn't work with our build.
$ ninja -j1000 -C out/host_debug
ninja: Entering directory `out/host_debug'
[0/5712] CXX obj/third_party/benchmark/src/libbenchmark.string_util.oninja: fatal: pipe: Too many open files
```

To check your limits:

```bash
launchctl limit maxfiles
ulimit -a
```

To adjust your limits (tested on OSX Ventura):

1. Reboot the system and enter recovery mode - keep cmd (⌘) + R pressed
1. Disable system integrity check from terminal, by typing `csrutil disable`
1. Reboot
1. Create the files below
1. Reboot
1. Enable system integrity check, by typing `csrutil enable`
1. Reboot the system to complete the changes

```xml
<!-- /Library/LaunchDaemons/limit.maxfiles.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
      <string>limit.maxfiles</string>
    <key>ProgramArguments</key>
      <array>
        <string>sudo</string>
        <string>launchctl</string>
        <string>limit</string>
        <string>maxfiles</string>
        <string>200000</string>
        <string>200000</string>
      </array>
    <key>RunAtLoad</key>
      <true/>
    <key>ServiceIPC</key>
      <false/>
  </dict>
</plist>
```

```xml
<!-- /Library/LaunchDaemons/limit.maxproc.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple/DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
    <dict>
      <key>Label</key>
        <string>limit.maxproc</string>
      <key>ProgramArguments</key>
        <array>
          <string>sudo</string>
          <string>launchctl</string>
          <string>limit</string>
          <string>maxproc</string>
          <string>2048</string>
          <string>2048</string>
        </array>
      <key>RunAtLoad</key>
        <true />
      <key>ServiceIPC</key>
        <false />
    </dict>
  </plist>
```

Then change the owners and load these settings:

```bash
sudo chown root:wheel /Library/LaunchDaemons/limit.maxfiles.plist
sudo chown root:wheel /Library/LaunchDaemons/limit.maxproc.plist
sudo launchctl load -w /Library/LaunchDaemons/limit.maxfiles.plist
sudo launchctl load -w /Library/LaunchDaemons/limit.maxproc.plist
```

### Disable Spotlight on Mac

See [Change Spotlight preferences on Mac](https://support.apple.com/guide/mac-help/change-spotlight-preferences-mchlp2811/10.14/mac/10.14).

I disabled `Developer`, which is where I keep all my code:

![Disabled on `Developer`](https://github.com/flutter/flutter/assets/168174/e51fac53-894a-453b-a547-35b163c3d2e8)

### Useful `.zshrc` addendums

I put this in `$HOME/Developer/.zshrc.local` and added this to `$HOME/.zshrc`:

```bash
# Load local zshrc if it exists.
if [ -f $HOME/Developer/.zshrc.local ]; then
  source $HOME/Developer/.zshrc.local
fi
```

```bash
# Addendum .zshrc for my work development environment.

# Raise limits.
ulimit -n 200000
ulimit -u 2048

# GClient on PATH.
export PATH="$HOME/Developer/depot_tools:$PATH"

# The engine src is always in $HOME/Developer/engine/src.
export ENGINE="$HOME/Developer/engine/src"

# The framework src is always in $HOME/Developer/flutter.
export FRAMEWORK="$HOME/Developer/flutter"

# Create a local version of the flutter tool that uses the local framework src.
alias fl="$FRAMEWORK/bin/flutter"
```

### Handling Engine <> Tool Misalignment

Typically, the engine and framework are kept in sync. However, sometimes they
get out of sync. This is usually because the engine is ahead of the framework
(i.e. a Dart SDK roll), or because the framework was pinned to an older engine
([example](https://github.com/flutter/flutter/commit/948900979050838b1f91701d24d89a7ce4d3fbf7)).

For example, I tried `fl run` and got this error:

```bash
$ fl run \
  --local-engine-src-path=$ENGINE \
  --local-engine=android_debug_unopt_arm64 \
  --enable-impeller

Unhandled exception:
Unexpected Kernel Format Version 107 (expected 106)
#0      BinaryBuilder.readComponent.<anonymous closure>
```

To handle this, there are 3 options:

1. Interactive rebase `$ENGINE` to the commit im `$FRAMEWORK/bin/internal/engine.version`.
1. Checkout `$FRAMEWORK` to a different commit with a compatible engine.
1. **Hack**: Update `$FRAMEWORK/bin/internal/engine.version` to point to the
   commit in `$ENGINE` you want to use.
