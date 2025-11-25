# ColourSwift Security
<img src="https://github.com/user-attachments/assets/65938060-807c-4630-ba5a-ea7d35d51ed8" width="150" alt="logo">

ColourSwift Security is an open source antivirus client for Android. The client is written in Flutter and provides a complete UI for scanning files, managing results, and interacting with the ColourSwift ecosystem.

The scanning engine is not open source. It is a native Rust library that is shipped only in compiled form, and the client loads it at runtime through FFI. The engine is responsible for signature matching, bloom filter checks, ML scoring and file analysis. This repository contains the complete client source code, which can be built and inspected by anyone, while the engine and cloud backend remain private and separate.

## Features

• Full device scan

• APK analysis

• Basic file analysis

• Cloud assisted scanning

• Real time protection support in the private build

• Custom UI

• Local plugin integrations

• ColourSwift ecosystem compatibility

## Supported File Types (ColourSwift AV Engine)

The engine supports deep scanning of the following file types:

Binary formats

APK

EXE, DLL, MSI

DEX, JAR, COM, BIN

Shared libraries: SO (Android), ELF (Linux)

Archives

ZIP

APK (treated as ZIP)

Nested ZIP/APK (up to 2 levels deep)

Documents & Scripting

TXT, LOG, CFG, INI

JSON, XML, HTML, CSS, JS

MD, CSV, TSV, RTF, YAML

DOC, DOCX (scanned as binary)

BAT, PS1, VBS

APK internals

classes.dex

lib/*.so

assets/*

res/raw/*

Other embedded resources

Skipped File Types

Some formats are skipped to avoid false positives and unnecessary I/O:

RAR (not supported)

PNG, JPG, JPEG, GIF, WEBP

MP4, MKV, AVI, MP3, OGG

TTF, OTF, WOFF, WOFF2

PDF


## What is open source

- Flutter UI

• Android project files

• Settings pages

• Scan pages

• Quarantine UI

• All Dart code under lib


## What is not open source

• The Rust scanning engine

• VXPack signature data

• ML classifier internals

• Cloud backend and scoring logic

• Builder pipelines

• Hash ingestion and dataset tools

• Attestation and server logic

The engine is provided as prebuilt `.so` files inside the jniLibs folder.

## Building the client

Requirements

• Flutter SDK

• Android Studio or command line build tools

• Java 17

• Git

Steps

1. Clone the repository
2. Run `flutter pub get`
3. Run `flutter build apk --release` or `flutter build apk --split-per-abi`
4. The output APK will be created under `build/app/outputs/bundle/release` or `build/app/outputs/bundle/apk`

The app will build and run without cloud features.
Cloud features work only with the private backend.

## Repo structure

```
lib/                 Dart source code
android/             Android project wrapper
assets/              Static assets
plugins/             Local plugin sources
pubspec.yaml         Project definition
pubspec.lock         Version lock file
README.md            This file .-.
LICENSE              MPL 2.0

```

Folders not used for the public repo have been removed.

## Contributing

Contributions are welcome.
Please keep changes focused on the client interface.
Do not refactor or reorganize the project structure.
Do not submit changes to the engine loader or native bindings.
Do not submit requests related to the private backend.

Bug reports, minor fixes and documentation improvements are accepted.

## License

MPL 2.0

## Privacy and security

The client does not collect personal data.
Cloud assisted scanning sends only file hashes.
No IP addresses or identifiers are stored as Cloudflare tunnels hide incoming IPs from the server by design.

No user information is logged or retained.

## Community

You can join the official Discord for updates and support.
Links are provided in the app and Github page
