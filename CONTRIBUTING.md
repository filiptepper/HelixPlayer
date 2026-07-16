# Contributing to HelixPlayer

First off, thank you for considering contributing to HelixPlayer! It's people like you who make the open-source community such an amazing place to learn, inspire, and create.

---

## Code of Conduct

Please maintain a friendly, welcoming, and professional attitude in all interactions (Issues, Pull Requests, discussions).

---

## How to Report Bugs

When submitting a bug report or issue, please include as much detail as possible to help us reproduce the issue:
1. **macOS Version** (e.g. macOS 14.5 Sonoma)
2. **Audio Hardware** (e.g. Scarlett 2i2 USB interface, built-in Mac speakers)
3. **Step-by-step instructions** to reproduce the problem.
4. **Expected behavior** vs. **actual behavior**.
5. **App logs** from standard output if you ran it via terminal or Xcode.

---

## How to Propose Changes (Pull Requests)

Please follow these steps to make a contribution:

1. **Fork** the repository and create your branch from `main`:
   ```bash
   git checkout -b feat/your-awesome-feature
   ```
2. **Implement your changes**. 
3. **Handle New Files**: If you add any new source files to the project, you **must** update the `generate_xcodeproj.py` script. The Xcode project is fully generated and is not tracked in Git. Adding files in Xcode will modify the temporary project file, but those changes will be lost next time the generator runs. Add the file to the file lists and PBX groups inside `generate_xcodeproj.py`.
4. **Run Tests**:
   Before submitting, ensure all unit tests compile and pass:
   ```bash
   make test
   ```
5. **Commit your changes**. Write clear, concise commit messages.
6. **Submit a Pull Request** describing what the changes do and why they are necessary.

---

## Coding Standards

- **Encapsulate C APIs**: Keep all low-level CoreAudio C API bridging and unsafe pointers confined to [CoreAudioHelper.swift](HelixPlayer/CoreAudioHelper.swift). The rest of the app should interact with clean Swift structs, enums, and properties.
- **Thread Safety**: Never write to `@Published` properties from the real-time audio thread or background threads. Always dispatch UI updates to the main thread.
- **SwiftUI Idioms**: Use modern SwiftUI architectures. Prefer simple views and pass state down using `@Binding` or environment objects where appropriate.
- **Self-Documenting Code**: Document public classes, structs, and methods using Swift's standard Triple-Slash (`///`) doc comment syntax.

---

Thank you again for contributing!
