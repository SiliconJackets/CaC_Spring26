Here’s a **clean, corrected version** of your README that properly reflects the **DLL-based TDC architecture (not standalone TDC)** and aligns with your RTL.

---

# 📏 DLL-Based Time-to-Digital Converter (TDC)

## 🧠 Overview

A **Time-to-Digital Converter (TDC)** measures the time difference between two events and converts it into a digital value.

This design implements a **DLL-based TDC**, where a **Delay-Locked Loop (DLL)** continuously calibrates a delay line, and a TDC block uses that calibrated delay line to perform high-resolution time measurements.

Unlike a standalone delay-line TDC, this architecture ensures that the time resolution remains **stable across process, voltage, and temperature (PVT) variations**.

---

## 🧩 Architecture

```
                ┌──────────────────────┐
                │      DLL LOOP        │
                │                      │
clk_ref ──► PD ─► Controller ─► DCDL ──┼──► clk_out
                ▲                     │
                └─────────────────────┘
                          │
                          ▼
                    taps (multiphase)
                          │
                ┌─────────▼─────────┐
                │       TDC         │
                │ (sampling + enc)  │
                └───────────────────┘
```

### Key Idea

> The **DLL calibrates the delay line**, and the **TDC measures time using that calibrated delay line**.

---

## 🔧 Mapping to This Design

This implementation reuses the DLL components and adds a TDC stage:

### 🔹 DLL Components

* **Phase Detector (`phase_detector`)**

  * Compares `clk_ref` and delayed clock (`clk_out`)

* **Controller (`controller`)**

  * Adjusts control word `ctrl`

* **Delay Line (`nand_dcdl_top`)**

  * Generates:

    * `clk_out` (for feedback)
    * `taps` (multiphase outputs)

The DLL ensures:

```
Total delay of delay line = 1 clock period
```

---

### 🔹 TDC Components (Added)

* **Taps (`clk_phases`)**

  * Provide multiple time-shifted versions of the signal

* **Sampler**

```verilog
always @(posedge stop_clk)
    sampled <= taps;
```

* **Thermometer Encoder**

  * Converts sampled taps into a digital value

---

## ⚙️ How It Works

### 1. DLL Calibration (Continuous)

The DLL runs continuously and enforces:

```
Total delay = Tclk
```

This means:

```
Delay per stage ≈ Tclk / N
```

👉 The delay line becomes a **calibrated time ruler**

---

### 2. Launch Event (START)

A signal is injected into the delay line:

```
START → propagates through delay chain
```

As time progresses, the signal moves forward through taps.

---

### 3. Sample Event (STOP)

At a specific time (`stop_clk` edge), all taps are sampled:

```verilog
sampled <= taps;
```

---

### 4. Thermometer Code

Example captured value:

```
111111000000
```

* `1` → signal has reached this stage
* `0` → signal has not reached this stage

---

### 5. Digital Output

The thermometer code is converted to a number:

```
111111000000 → 6
```

This represents how far the signal propagated.

---

## 🧮 Time Resolution

Since the DLL enforces:

```
Total delay = Tclk
```

Each stage has delay:

```
Tstage = Tclk / N
```

Example:

* `Tclk = 1 ns`
* `N = 16`

```
Resolution = 62.5 ps
```

Measured value:

```
6 → 6 × 62.5 ps = 375 ps
```

---

## 🔁 Why Use a DLL?

Without a DLL:

```
Delay per stage = unpredictable
```

With a DLL:

```
Delay per stage = Tclk / N (stable)
```

### Benefits:

* Automatic calibration
* PVT robustness
* Consistent measurement accuracy

👉 The DLL transforms the delay line into a **self-calibrating timing reference**

---

## ⚠️ Practical Considerations

### 1. Bubble Errors

Example:

```
111101111000
```

Mitigation:

* Bubble correction logic
* Priority encoding

---

### 2. Metastability

Occurs when sampling near signal transitions.

Mitigation:

* Careful clocking
* Optional re-timing stages

---

### 3. Resolution vs Cost

* More stages → finer resolution
* Tradeoffs:

  * Area
  * Power
  * Jitter accumulation

---

## 🚀 Applications

### 📏 High-Resolution Time Measurement

* Picosecond-level timing
* Event timestamping

---

### 🔄 All-Digital PLLs (ADPLL)

* TDC replaces analog phase detector
* Enables fully digital clocking systems

---

### 📡 LiDAR / Time-of-Flight (ToF)

* Measures light travel time
* Used in depth sensing and imaging

---

### ⚡ Jitter Measurement

* Measures clock edge variation
* Useful for clock quality analysis

---

## 🧠 Key Insight

> The DLL provides a **calibrated delay line**, and the TDC measures time by observing how far a signal propagates through that delay line at a given instant.

---

## 🔑 Summary

This design demonstrates how a single DLL infrastructure can be extended into multiple applications:

* ✅ Zero-Delay Buffer (ZDB)
* ✅ Multiphase Clock Generator
* ✅ DLL-Based TDC (this implementation)

👉 The DLL acts as a **calibration backbone**, while different front-end logic enables different functionalities.

---

If you want, I can next:

* Add a **small RTL snippet section** (so the README ties directly to your code)
* Or make a **clean block diagram tailored exactly to your module names**
