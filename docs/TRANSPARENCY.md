**Users should be able to verify what the app does, even if the core engine remains closed source.**

This document explains the complete transparency model, data flows, and how developers and security researchers can independently audit the app’s behaviour.

---

# **1. Client is Fully Open Source**

The Android client (Flutter code) is open and includes:

- UI
- Permission handling
- File access logic
- Cloud-assisted scan requests
- Real-time protection logic
- All network operations
- All FFI calls to the native engine

Anyone can inspect the full behaviour of the app.

---

# **2. Native Engine is Closed, but Fully Sandbox-Bound**

The Rust engine (native `.so`) remains closed source to protect:

- detection logic
- byte signatures
- heuristics
- ML weights
- anti-tamper strategies
- signature parsing code

However, the engine is fully sandboxed and **cannot** perform operations that are not explicitly exposed through the FFI bridge.

The engine:

- cannot upload files
- cannot perform network operations
- cannot modify files
- cannot request permissions
- cannot perform hidden scans

It only performs the exact functions made visible through the FFI.

---

# **3. FFI Bridge Defines Everything the Engine Can Do**

If a function does not appear in the FFI bridge, the engine cannot call it.

FFI bridge source code:

**[FFI Bridge](../lib/widgets/antivirus_bridge.dart)**

Through FFI, researchers can audit every native function used:

- which functions exist
- what arguments are passed
- what data is returned
- when the engine is invoked
- how APK scanning works
- how VXPack is loaded
- how Bloom and signatures are initialized

---

# **4. Real-Time Engine Logs Are Left Visible for Auditing**

During scans, the engine prints structured debug logs to logcat:

- how many signatures loaded
- ML model status
- which scanning phases run
- metadata decisions
- byte and hash scan flow
- final detection verdict

Security researchers can attach Android Studio and watch the engine work in real time.

This proves:

- no hidden behaviour
- no background data extraction
- no silent uploads
- no file modification

---

# **5. No Private Data Ever Leaves the Device**

Even with cloud-assisted scanning enabled:

- only hashes
- file metadata

are transmitted. Files, device id and IP addresses are never uploaded.


