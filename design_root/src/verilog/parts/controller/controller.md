
---

# 📘 Digital Phase Detector (DLL / PLL)

---

## Signal Flow

```
Phase Detector → Controller → Delay Line → Clock Output
```

* **Phase Detector (PD)**

  * compares `clk_in` and `clk_out`
  * generates `up/down`
  * tells **direction of error**

* **Controller**

  * converts direction into delay updates

* **DCDL**

  * applies **physical delay**

Together, they form a **closed feedback system** that converges to phase alignment.

---

## 1. Phase Detector System Context

The goal of a phase detector is to determine the **relative timing between two clocks**:

* `clk_in` → reference clock
* `clk_out` → feedback clock

The phase detector converts:

> **phase difference → directional control signal**

---

### Inputs

* `clk_in` → reference clock
* `clk_out` → feedback clock

---

### Outputs

* `up` → reference leads → **speed up loop**
* `down` → feedback leads → **slow down loop**

---

```
CLK_IN -------> +-------------------+      up, down       +-------------------+
                |   Phase Detector  | ------------------> |    Controller     |
CLK_OUT  <----- |   THIS SECTION    |                     |                   |
                +-------------------+                     +---------+---------+
                                                                  |
                                                                  v
                                                           Delay Line (DCDL)
                                                                  |
                                                                  v
                                                               CLK_OUT
```

---

### Core Behavior (Step-by-Step)

At each clock interaction:

1. **Observe edges**

   * detect rising edges of `clk_in` and `clk_out`

2. **Compare timing**

   * determine which edge arrived first

3. **Generate output**

   * `clk_in` first → `up = 1`
   * `clk_out` first → `down = 1`
   * simultaneous → no decision

---

### Intuition

* `up` → output clock is **late**
* `down` → output clock is **early**
* Only **direction** is provided (not magnitude)

---

### Mathematical View

```
e[k] ∈ { -1, 0, +1 }
```

* `+1` → up
* `-1` → down
* `0` → no decision

---

## 2. Phase Detector Design Space

### Why Phase Detector Design Matters

Phase detector behavior directly affects:

* **Loop stability**
* **Jitter near lock**
* **Lock correctness**
* **Frequency tracking ability**

---

### Key Trade-Offs

* Simplicity ↔ Accuracy
* Low area ↔ Robustness
* Fast response ↔ Clean steady-state

---

No single phase detector is optimal.

This project allows:

* Direct comparison of architectures
* Understanding real trade-offs
* Observing behavior near lock
* Connecting theory to implementation

---

### Implemented Detector Types

1. Behavioral Timestamp Detector
2. Edge-Order Detector
3. Single Flip-Flop Detector
4. Phase-Frequency Detector (PFD)
5. Sampled XOR Detector

---

## 3. Control Theory Background

Phase detectors behave as **binary decision elements** in a feedback loop.

They do **not measure magnitude**, only direction.

---

### Key Concepts

---

#### • Binary phase error (`up/down`)

* Only the **direction** matters

```
Late  → up = 1
Early → down = 1
```

---

#### • Bang-Bang behavior

* Output ∈ { +1, -1, 0 }
* Leads to **nonlinear system behavior**

---

#### • Digital (Quantized) detection

* No continuous phase measurement

```
Decision: up / down only
```

---

#### • Limit cycles (steady-state oscillation)

```
up → down → up → down
```

→ causes jitter

---

#### • Metastability & sampling

* Occurs when edges are very close
* Can produce ambiguous or incorrect decisions

---

#### • Stability dependency

* Clean detector → stable loop
* Noisy detector → jitter / drift

---

## 4. Phase Detector Behavior (Waveforms)

---

### Conceptual Behavior

```
clk_in:   ─┐ ─┐ ─┐ ─┐ ─┐
           └─┘ └─┘ └─┘ └─┘

clk_out:    ─┐ ─┐ ─┐ ─┐
             └─┘ └─┘ └─┘

up:        1   1   0   0
down:      0   0   1   1
```

---

### Near-Lock Behavior

```
up:     1 0 1 0 1 0
down:   0 1 0 1 0 1
```

✔ steady oscillation → jitter

---

## 5. Phase Detector Implementations

---

### Internal Architecture (Generic)

```
            +----------------------+
CLK_IN  --->|                      |
CLK_OUT --->|   Phase Detection    | ---> up
RST    --->|                      | ---> down
            +----------------------+
```

---

### 5.1 Behavioral Timestamp Detector

* Compares edge timestamps (`$time`)
* Ideal phase comparison

✔ Perfect reference
✖ Not synthesizable

---

#### Diagram

```
clk_in  ----> +---------------------+
              |                     |
clk_out ----> |  Time Compare       | ---> up / down
              +---------------------+
```

---

#### Waveform

```
up:   1       1
down: 0       0
```

---

### 5.2 Edge-Order Detector

* First edge wins
* Holds until opposite edge

✔ Simple
✖ Race conditions

---

#### Diagram

```
clk_in  ----> Edge Arbitration ---> up/down
clk_out ---->
```

---

#### Issue

```
up = 1, down = 1   (ambiguous)
```

---

### 5.3 Single Flip-Flop Detector

* Samples `clk_out` at `clk_in`

✔ Minimal hardware
✖ Biased near lock

---

#### Diagram

```
clk_out → DFF → up/down
clk_in  → CLK
```

---

### 5.4 Phase-Frequency Detector (PFD)

* Two flip-flops + reset

✔ Industry standard
✔ Detects frequency

---

#### Diagram

```
clk_in  → UP FF
clk_out → DN FF
           ↓
         reset
```

---

#### Waveform

```
UP:   ┌───┐
DOWN:    ┌───┐
```

---

### 5.5 Sampled XOR Detector

* XOR + sampling

✔ Simple
✖ Weak near lock

---

#### Diagram

```
clk_in ─┐
        XOR → sample → up/down
clk_out ┘
```

---

#### Failure Case

```
clk_in ≈ clk_out → no update
```

---

## 6. Design Trade-Off Matrix

| Detector Type | Accuracy | Complexity | Frequency Detection | Near-Lock | Use     |
| ------------- | -------- | ---------- | ------------------- | --------- | ------- |
| Behavioral    | Ideal    | Low        | Limited             | Perfect   | Sim     |
| Edge-Order    | Medium   | Low        | Limited             | Unstable  | Rare    |
| Single FF     | Low      | Very Low   | No                  | Biased    | Edu     |
| PFD           | High     | Medium     | Yes                 | Good      | Std     |
| XOR           | Medium   | Low        | No                  | Weak      | Limited |

---

## 7. Practical Considerations

* Clock alignment sensitivity
* Sampling edge choice
* Reset correctness

---

## 8. Non-Idealities

* Quantization → no fine resolution
* Limit cycles → jitter
* Metastability → uncertainty
* Ambiguous edges → errors

---

## 9. Verification Strategy

* Reset validation
* Direction correctness
* Stability near lock
* Alternating input robustness

---

## 10. Implementation Notes

* Edge-triggered logic
* Asynchronous reset
* Synthesizable (except behavioral)

---

## 11. Interaction with Controller

```
Phase Detector → Controller → Delay Line
```

* PD → **direction**
* Controller → **magnitude**

---

## 12. Selection Guide

| Use Case     | Detector   |
| ------------ | ---------- |
| Simulation   | Behavioral |
| Minimal HW   | Single FF  |
| Simple       | Edge-order |
| Production   | PFD        |
| Experimental | XOR        |

---

## 13. Industry Practices

* **PFD → standard**
* Coarse/fine + PFD → common
* XOR / FF → limited use

---

## 14. Limitations

* Jitter near lock
* Metastability
* Bias in simple detectors

---

## 15. Future Work

* Hybrid detectors
* Adaptive sampling
* Calibration methods

