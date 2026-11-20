# rhwp (HWP → PDF converter)

Daylight PDF converts HWP / HWPX / HML with the command-line tool of
[rhwp](https://github.com/edwardkim/rhwp) (MIT). The binary is **not committed**; each platform's
build goes in its own folder here and is copied next to the app by the build (`windows/CMakeLists.txt`).

```
third_party/rhwp/windows-x64/rhwp.exe   (+ LICENSE, THIRD_PARTY_LICENSES.md)
```

The app starts `<app dir>/rhwp/rhwp[.exe]`. For development you can point at any build with the
`DAYLIGHT_RHWP` environment variable (full path to the executable).

## Where the shipped binaries come from

Release builds do not build rhwp themselves (it takes ~25 minutes). The **Build rhwp** workflow
(`.github/workflows/build-rhwp.yml`, run by hand) builds it from the crates.io source for Windows, Linux and
macOS (arm64 + x64 merged with `lipo`) and publishes the result as the **prerelease** `rhwp-v<version>-b<build>`
(a prerelease with a non-semver tag, so it is never taken for an app release).

1. Run the workflow with the rhwp version and a build number.
2. Paste the SHA-256 lines from its summary into `rhwp.lock` (next to this file) and commit.
3. The Release workflow runs `tool/fetch_rhwp.sh <platform>`: it downloads exactly that build, checks the hash
   **before** unpacking and stops on an empty or different hash.

To use the pinned build locally: `tool/fetch_rhwp.sh windows-x64` (needs `gh`). Layout in the app: Windows and
Linux `<app dir>/rhwp/rhwp[.exe]`, macOS `Daylight PDF.app/Contents/Helpers/rhwp`.

## Building the binary by hand (what was tested: rhwp 0.9.1, Windows x64)

Fonts are not bundled and not downloaded (the app runs rhwp offline and uses the OS fonts), and PDF import
and Skia are not needed, so build the minimal CLI:

```sh
cargo install rhwp --version 0.9.1 --locked --no-default-features --features wasm-api --bin rhwp
# or from the crate source:  cargo build --release --bin rhwp --no-default-features --features wasm-api
```

Result: about 46 MB (about 17 MB zipped); the PDF output was byte-identical to the official release build on the
files compared. The build takes ~25 minutes. The official release binaries (77 MB) also work.
