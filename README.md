# HelixPlayer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

HelixPlayer is a native, lightweight macOS host application specifically built to run the **Line 6 Helix Native** Audio Unit (AU) plugin. It is designed for low-latency live guitar playing, offering a direct physical guitar input route and separate output routing (e.g. guitar interface input and headphones/monitor output) with clock drift compensation.

---

## Key Features

- **Programmatic Aggregate Devices**: Dynamically creates CoreAudio aggregate devices under the hood when different physical input and output devices are selected, avoiding manual Audio MIDI Setup configuration.
- **Clock Drift Compensation**: Enables CoreAudio drift compensation automatically on the drift sub-device for stable multi-device setups.
- **Low Latency Options**: Allows tuning the CoreAudio buffer frame size (32, 64, 128, 256, 512 samples) to minimize latency without pops or clicks.
- **Real-time VU Meters**: Responsive input and output level meters calibrated to dB.
- **Helix Native Integration**: Dynamically scans for the Line 6 Helix Native component (`aumf/6HPA/LSIX`) and loads its custom graphical editor UI.
- **Graceful Fallback**: Automatically falls back to Apple's built-in Delay plugin (`aufx/dely/appl`) if Helix Native is not installed, so you can test the application setup out of the box.
- **Crash Recovery**: Automatically scans and cleans up orphaned aggregate devices on launch and shutdown to prevent system audio clutter.

---

## Prerequisites

- **macOS**: 12.0 or later
- **Xcode**: 13.0 or later (with command line tools)
- **Python**: Python 3.x (used to generate the Xcode project file)
- **Audio Plugin (Optional)**: Line 6 Helix Native (VST3/AU). If not present, the app will fall back to loading the default Apple `AUDelay` effect.

---

## Quick Start (Build & Run)

HelixPlayer does not track its complex `.xcodeproj` files in Git to avoid merge noise. Instead, it generates them programmatically on build.

To generate the project and run:

1. **Clone the repository**:
   ```bash
   git clone https://github.com/filiptepper/HelixPlayer.git
   cd HelixPlayer
   ```

2. **Generate the Xcode project**:
   ```bash
   make generate
   ```

3. **Build the Debug application**:
   ```bash
   make build
   ```

4. **Run the application**:
   ```bash
   make run
   ```

5. **Run the Unit Test Suite**:
   ```bash
   make test
   ```

---

## How It Works

HelixPlayer solves a common CoreAudio limitation: `AVAudioEngine` can only attach to a single hardware audio device ID at a time. If you want to use a guitar interface for input but your Mac's headphone jack for output, this requires creating an aggregate device.

When different input and output devices are selected:
1. HelixPlayer queries device parameters using CoreAudio HAL properties.
2. It constructs a virtual aggregate device named "HelixPlayer Aggregate".
3. It sets the clock master and enables drift compensation on the input/output interfaces.
4. It sets the virtual aggregate ID as the active device on `AVAudioEngine`'s output hardware node.
5. It instantiates the Helix Native AU plugin asynchronously and routes the selected mono input channel through the audio unit.

For more technical details, read the [HelixPlayer Design Specification](docs/superpowers/specs/2026-07-14-helix-player-design.md).

---

## Contributing

Contributions are very welcome! Please check out [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on code style, testing, and PR submissions.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
