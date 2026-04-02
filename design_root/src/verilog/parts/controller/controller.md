---

# Digital Delay Locked Loop (DLL) Controller

---

## Signal Flow

```
Phase Detector → Controller → Delay Line → Clock Output
```

* **Phase Detector (PD)**
   * generates `up/down` signals
   * tells **direction**
* **Controller**
  * integrates error into a control word
  * decides **how much to adjust**
* **DCDL**
  * adjusts delay accordingly
  *  applies **physical delay**


Together, they form a **closed feedback system** that converges to phase alignment.

---



## 1. Controller System Context

The goal of a Delay Locked Loop (DLL) is to align the phase of an output clock with a reference clock. It does so by adjusting the delay through a digitally controlled delay line (DCDL). The controller forms the bridge that translates phase error into delay control updates. 

The controller converts **phase error → delay adjustment**

#### Inputs

* `up` → output clock is **late** → increase delay
* `down` → output clock is **early** → decrease delay

#### Output

* `ctrl[N-1:0]` → sets delay of DCDL



```
CLK_IN -------> +-------------------+      up[1:0], down[1:0]       +-------------------+
                |   Phase Detector  | ----------------------------> |    Controller     |
CLK_OUT  <----- |                   |                               |   THIS SECTION    |
                +-------------------+                               +---------+---------+
                                                                          |
                                                                          | ctrl[N-1:0]   
                                                                          v
                                                                   +-----------------------+
                                                                   |   Delay Line (DCDL)   |
                                                                   |                       |
                                                                   +-----------+-----------+
                                                                          |
                                                                          v
                                                                       CLK_OUT

                               Simple Delay Locked Loop Diagram
                                                                        
                                                                        
```



#### Core Behavior (Step-by-Step)

At every clock cycle:

1. **Read phase detector output**

   * `(up, down) ∈ { (1,0), (0,1), (0,0), (1,1) }`

2. **Interpret phase error**

   * `(1,0)` → output clock is **late** → increase delay
   * `(0,1)` → output clock is **early** → decrease delay
   * `(0,0)` or `(1,1)` → no valid correction → hold

3. **Update control word**

   The controller behaves like a simple digital accumulator (a counter):

   ` ctrl[k+1] = ctrl[k] + up - down `

   Equivalent interpretation:

   * `+1` when `up = 1`
   * `-1` when `down = 1`
   * `0` when both are equal

4. **Apply limits (saturation)**

  ` 0 ≤ ctrl ≤ 2N−1 `

---

#### Intuition

* `up` pushes the delay **forward**
* `down` pulls the delay **backward**
* The controller **accumulates corrections over time** until phase alignment is reached

---

#### Mathematical View 

The controller behaves like a **digital accumulator**:

` ctrl[k+1] = ctrl[k] + K * e[k] `

Where:

* ` e[k] ∈ {-1, 0, +1} ` from `up/down`
* ` K ` = step size (loop gain)

---

## 2. Controller Design Space

#### Why Controller Design Matters

Controller behavior determines:

* **Lock Time**

  * How fast the system converges

* **Stability**

  * Avoid oscillations or overshoot

* **Jitter**

  * Small fluctuations near lock

---

##### Key Trade-Offs

Different controllers optimize different goals:

* Fast acquisition  ↔  Low jitter
* Simple logic      ↔  Adaptive behavior
* Robustness        ↔  Responsiveness

---
No single controller is optimal.

This project allows:

* Direct comparison of architectures
* Understanding trade-offs in practice
* Testing under identical conditions
* Building intuition for real DLL design

This project explores **5 controller types**:

### 🔹 1. Saturating Controller

* Fixed ±1 step
* Simple and robust

### 🔹 2. Filtered Controller

* Updates only after repeated requests
* Reduces noise / chatter

### 🔹 3. Acquire / Track Controller

* Large steps → fast lock
* Small steps → low jitter

### 🔹 4. Coarse / Fine Controller

* Split control word:

  * Coarse → large jumps
  * Fine → precision tuning

### 🔹 5. Variable-Step Controller

* Step size increases with repeated error
* Adaptive behavior

---


## 3. Control Theory Background

DLL controllers behave as **discrete-time integrators** driven by a bang-bang phase detector. It is essentially a counter that keeps adjusting until the clocks line up. The feedback loop helps with the self correcting behavior. The latency that it takes to converge depends heavily on the granularity and the features of the controller. The corrections are constantly accumulated until the error is small enough. 

### Key Concepts 

This is already strong — I just cleaned it up for **flow, clarity, and consistency**, and added **simple sketches where they actually help learning**.

---

### Key Concepts

---

#### • Binary phase error (`up/down`)

* Only the **direction** of error matters, not the amount
* Implemented using a **bang-bang phase detector**

```id="a1"
Late  → up = 1 → increase delay
Early → down = 1 → decrease delay
```

---

#### • Loop gain (set by step size)

* **Step size** = how big each correction is
* **Loop gain** = how strongly the system reacts to error

> “If the clock is wrong, how big of a correction do we make?”

* Large step size:

  * Faster correction
  * More overshoot / jitter

* Small step size:

  * Slower correction
  * Smoother behavior

```id="a2"
High gain:   32 → 36 → 40 → overshoot
Low gain:    32 → 33 → 34 → smooth approach
```

---

#### • Digital (Quantized) control

* Everything is **digital**
* `ctrl` changes in **discrete steps** (no continuous values)
* Updates happen **once per clock cycle**

```id="a3"
ctrl: 32 → 33 → 34 → 35   (step-by-step)
```

---

#### • Limit cycles (steady-state oscillation)

* The system **never becomes perfectly still**
* Near lock, it keeps correcting back and forth

```id="a4"
ctrl: 32 ↔ 33 ↔ 32 ↔ 33
```

* These small oscillations appear as **jitter**

---

#### • Stability depends on update behavior

* Large / frequent updates:

  * Fast response
  * More oscillation

* Small / infrequent updates:

  * Slower response
  * More stable

```id="a5"
Fast:   big jumps → oscillation
Slow:   small steps → stable
```

---



## 4. Controller Design Space

Different controller architectures trade off:

* Speed vs stability
* Resolution vs complexity
* Noise immunity vs responsiveness

### Categories

* Fixed-step (baseline)
* Filtered (noise suppression)
* Multi-mode (coarse/fine or acquire/track)
* Adaptive (variable step)

---

## 5. Controller Implementations

This project implements five controller architectures:

#### Internal Controller Architecture (Generic)

```
           +-----------------------+
UP  -----> |                       |
DOWN ----> |   Control Logic       | ---> ctrl[N-1:0]
           | (state / arithmetic)  |
CLK ------>|                       |
RST ------>|                       |
           +-----------------------+
```

---

### 5.1 Saturating Up/Down Controller

**Baseline implementation**

* ±1 step per cycle
* Hard saturation at bounds
* Simple and robust

✔ Industry baseline
✖ Slow convergence near lock

---

### 5.2 Filtered Controller

* Requires repeated requests before update
* Reduces jitter and chatter

✔ Stable near lock
✖ Slower response

---

### 5.3 Acquire / Track Controller

* Dual-mode operation:

  * **Acquire**: large steps (fast lock)
  * **Track**: small steps (low jitter)

✔ Widely used in industry
✔ Balanced performance

---

### 5.4 Coarse / Fine Controller

* Splits control word:

  * Coarse bits → large adjustments
  * Fine bits → precise tuning

✔ High resolution
✔ Efficient hardware scaling

---

### 5.5 Variable-Step Controller

* Step size adapts based on persistence of error
* Nonlinear control behavior

✔ Fast convergence
✖ Requires careful tuning

---

## 6. Design Trade-Off Matrix

| Controller Type | Lock Speed | Jitter   | Complexity | Industry Use |
| --------------- | ---------- | -------- | ---------- | ------------ |
| Saturating      | Low        | Medium   | Low        | Common       |
| Filtered        | Low        | Low      | Medium     | Moderate     |
| Acquire/Track   | High       | Low      | Medium     | Very Common  |
| Coarse/Fine     | High       | Very Low | High       | Very Common  |
| Variable-Step   | Very High  | Medium   | High       | Specialized  |

---

## 7. Mode Switching & State Behavior

Many controllers rely on **state transitions**:


### Mechanisms

* Quiet-cycle detection
* Threshold-based switching
* Implicit vs explicit FSM

### Risks

* Premature switching
* Oscillation between modes

---

## 8. Parameterization & Tuning

Key parameters across implementations:

* `CTRL_BITS` → resolution
* `INIT_CTRL` → startup bias
* Step sizes → loop gain
* Thresholds → switching sensitivity
* Filter length → noise immunity

---

## 9. Numerical Effects & Non-Idealities

Due to digital control:

* Quantization introduces limit cycles
* Bang-bang control creates oscillations
* Metastability from PD affects correctness 

---

## 10. Boundary Conditions & Saturation

Controllers enforce:

* No overflow above max control value
* No underflow below zero
* Stable behavior at boundaries
* Recovery from extremes

---

## 11. Verification Strategy

A **unified testbench** validates all controller types.

### 11.1 Philosophy

* Behavior-based validation
* Architecture-independent

### 11.2 Test Coverage

Key behaviors tested:

* Reset correctness
* Monotonic up/down behavior
* Saturation limits
* Stability under idle conditions
* Recovery from boundaries
* Alternating input robustness

Example guarantees:

* No overflow/underflow
* No runaway behavior
* Correct response to persistent inputs

✔ Reusable across all designs 

---

## 12. Timing & Implementation Considerations

* Fully synchronous operation
* Asynchronous reset support
* One-cycle update latency
* Synthesizable RTL

---

## 13. Integration with DCDL

Controller output drives delay line:

* Control word → delay mapping
* Resolution must match DCDL granularity
* Coarse/fine improves dynamic range

---

## 14. Stability & Loop Behavior

Observed behaviors:

* Fast-lock controllers → potential overshoot
* Fine-step controllers → reduced jitter
* Trade-off defines loop bandwidth

---

## 15. Controller Selection Guide

| Use Case               | Recommended Controller |
| ---------------------- | ---------------------- |
| Simple system          | Saturating             |
| Low jitter requirement | Filtered               |
| Balanced design        | Acquire/Track          |
| High resolution        | Coarse/Fine            |
| Fastest lock possible  | Variable-Step          |

---

## 16. Industry Practices

Common real-world approaches:

* **Acquire + Track** → standard in ASICs
* **Coarse + Fine** → used in high-resolution DLLs
* Hybrid designs → combine multiple strategies

Rare:

* Pure variable-step (research / optimization-heavy)

---

## 17. Limitations & Failure Modes

* Limit-cycle oscillation near lock
* Slow convergence (filtered designs)
* Sensitivity to noisy phase detector
* Incorrect parameter tuning

---

## 18. Future Extensions

* Hybrid controllers (filtered + adaptive)
* Dynamic threshold tuning
* Calibration-assisted control

---

## 19. References

* Digital Delay Lock Techniques (textbook) 
* Unified controller testbench 

---

## ✅ Summary

This controller suite explores the **full design spectrum of digital DLL control**, from simple baseline designs to advanced adaptive architectures, with a unified verification framework and strong grounding in both theory and practice.

---






---

# 🔷 3. Controller-Specific Block Diagrams

---

## 3.1 Saturating Controller

```
          +------------------+
UP -----> |                  |
DOWN ---> |  +1 / -1 Logic   |
          |  (Adder/Sub)     |
          +--------+---------+
                   |
                   v
            +-------------+
            | Saturation  |
            |  Clamp      |
            +------+------+ 
                   |
                   v
                 ctrl
```

✔ Simple accumulator + bounds checking

---

## 3.2 Filtered Controller

```
UP -----> +-------------+         +------------------+
          | UP Counter  |-------> |                  |
          +-------------+         |                  |
                                 |   Update Logic   | ---> ctrl
DOWN ---> +-------------+         | (only on threshold)
          | DOWN Counter|-------> |                  |
          +-------------+         +------------------+
```

✔ Temporal filtering before applying control updates

---

## 3.3 Acquire / Track Controller

```
                +----------------------+
UP/DOWN ------> |   Step Selection     |
                | (Acquire / Track)    |
                +----------+-----------+
                           |
                           v
                     +-----------+
                     | Adder     |
                     | (+/- step)|
                     +-----+-----+
                           |
                           v
                         ctrl

          +------------------------------+
          | Quiet Counter (mode switch)  |
          +------------------------------+
```

✔ Mode-dependent step size

---

## 3.4 Coarse / Fine Controller

```
                 +-------------------+
UP/DOWN -------> |   Mode Select     |
                 | (Coarse / Fine)   |
                 +----+---------+----+
                      |         |
                      v         v
                +---------+  +---------+
                | Coarse  |  |  Fine   |
                | Counter |  | Counter |
                +----+----+  +----+----+
                     \          /
                      \        /
                       v      v
                    {coarse, fine}
                          |
                          v
                        ctrl
```

✔ Bit-partitioned control word

---

## 3.5 Variable-Step Controller

```
UP/DOWN -----> +----------------------+
               | Direction Tracker    |
               +----------+-----------+
                          |
                          v
               +----------------------+
               | Step Size Generator  |
               | (based on history)   |
               +----------+-----------+
                          |
                          v
                    +-----------+
                    | Adder     |
                    | (+/- step)|
                    +-----+-----+
                          |
                          v
                        ctrl
```

✔ Nonlinear adaptive gain


### Conceptual Waveform

```
clk_in:   ─┐ ─┐ ─┐ ─┐ ─┐ ─┐ ─┐
           └─┘ └─┘ └─┘ └─┘ └─┘

up:        1   1   1   0   0
down:      0   0   0   1   1

ctrl:     32  33  34  34  33  32
```

---

## 4.2 Saturation Behavior

```
ctrl:   ... 60 61 62 63 63 63 63
                 ↑  ↑
              saturates at MAX
```

---

## 4.3 Filtered Controller Behavior

```
up:        1 1 1 1    0
counter:   1 2 3 4 -> trigger
ctrl:     32      33
```

✔ Update only after threshold reached

---

## 4.4 Acquire → Track Transition

```
mode:     A   A   A   A   T   T   T
step:     4   4   4   4   1   1   1

ctrl:    32 36 40 44 45 46 47
```

✔ Large jumps → fine tuning

---

## 4.5 Coarse / Fine Behavior

```
coarse:   3   4   5   5   5
fine:     0   0   0   1   2

ctrl:    24  32  40  41  42
```

✔ Two-stage resolution

---

## 4.6 Variable-Step Behavior

```
same_dir_count: 1 2 3 4 5 6
step size:      1 1 2 2 4 4

ctrl:          32 33 34 36 38 42
```

✔ Adaptive acceleration

---

## 4.7 Alternating Inputs (Stability Check)

```
up:     1 0 1 0 1 0
down:   0 1 0 1 0 1

ctrl:  32 33 32 33 32 33
```

✔ No drift → stable loop


