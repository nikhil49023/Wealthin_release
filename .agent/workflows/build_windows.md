---
description: Build the WealthIn application for Windows with Python Sidecar
---

How to build a production-ready Windows executable (.exe) for WealthIn.

### 1. Prerequisites (On Windows)
- [Flutter SDK](https://docs.flutter.dev/get-started/install/windows) installed.
- [Python 3.10+](https://www.python.org/downloads/windows/) installed.
- [Visual Studio 2022](https://visualstudio.microsoft.com/downloads/) with "Desktop development with C++" workload.

### 2. Compile the Python Backend
First, we compile the Python sidecar into a standalone `.exe`.

open terminal in `wealthin_v2/backend`:

```powershell
# Install dependencies
pip install -r requirements.txt
pip install pyinstaller

# Build the executable (Single file, Console hidden)
pyinstaller --onefile --name=wealthin_server main.py
```

*Output*: You will find `wealthin_server.exe` in the `dist/` folder.

### 3. Build the Flutter App
Now build the main desktop application.

open terminal in `wealthin_v2/frontend/wealthin_flutter`:

```powershell
flutter build windows --release
```

*Output*: The build will be in `build\windows\runner\Release`.

### 4. Bundle and Run
Combine them into a single folder.

1. Go to `build\windows\runner\Release`.
2. Copy `wealthin_v2\backend\dist\wealthin_server.exe` into this folder.
3. (Optional) Create a `config.json` if needed in `assets/`.

**Run**: Double-click `wealthin_flutter.exe`.
*It will automatically launch `wealthin_server.exe` in the background.*
