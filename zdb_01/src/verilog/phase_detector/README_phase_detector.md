# Phase Detector Implementations

## Steps to run tb with synopsys

- Switch to C-shell for using the tool: `tcsh
- Go to the src/verilog/phase_detector/phase_detector.include : and add the file names for the test
    - Pick the testbench (phase_detector.tb for a common test)
    - Pick the implementation
- Go to src/Makefiles/Makefile_sim_presyn and change top module to 'phase_detector' (line1)
- Use this directory to run the synopsys tools. This contains soft links to all of the verilog files in source: `cd sim/behav
- Clean up the directory: `make wipe
- Add all the verilog files: `make link_src
- Run the simulation: `make vcs
- Clean up the directory before pushing the change to avoid massive log files on the main repo: `make wipe



## Overall Module Purpose

All of these modules implement a phase detector for a DLL/PLL-style feedback system. This section explores multiple implementations of a bang-bang phase detector.

A bang-bang phase detector does not output a numeric phase error. Instead, it produces a binary control decision:
- UP = 1: the reference clock clk_in is leading, so the controlled clock should speed up.
- DOWN = 1: the feedback clock clk_out is leading, so the controlled clock should slow down.

These implementations differ in how they detect phase lead/lag, whether they are synthesizable, and whether they behave well near zero phase error or under frequency mismatch. 

Additionally, the synthesized circuit differs in the gates(digital circuit) that are used to implement this.


The implementations studied here are:

1. Behavioral timestamp-based detector
2. Single flip-flop detector
3. Two flip-flop detector with auto-reset
4. Phase-frequency detector
5. XOR-based detector with sampled direction
6. Edge-based XOR/binary detector

These versions trade off between:

- simulation simplicity
- post synthesis digital circuit (implementation in silicon)
- lock behavior near zero phase error
- sensitivity to frequency difference


# Comparison summary (CHECK: TO BE FIXED)


# Comparison Summary

| Implementation       | Synthesizable | Direction Output | Handles Frequency Difference | Behavior Near Lock | Notes                                     |
| -------------------- | ------------- | ---------------- | ---------------------------- | ------------------ | ----------------------------------------- |
| Behavioral Timestamp | No            | Yes              | Limited                      | Idealized          | Reference model for simulation            |
| Single FF            | Yes           | Yes              | Poor                         | Biased             | Very simple but inaccurate near lock      |
| Two-FF PFD           | Yes           | Yes              | Yes                          | Good               | Standard PLL/DLL phase-frequency detector |
| Sampled XOR          | Yes           | Approximate      | Poor                         | Weak               | XOR detects phase mismatch only           |
| Edge-Order           | Yes           | Yes              | Limited                      | Moderate           | Uses edge arrival ordering                |

---

# Per-Implementation Documentation

## 1. Behavioral Timestamp Phase Detector

`timestamp_phase_detector`

### Description

This implementation compares the **simulation timestamps of the most recent rising edges** of `clk_in` and `clk_out`. It is a **behavioral simulation model** that directly uses `$time` to determine which clock edge occurred more recently.

### Operation

* On each rising edge of `clk_in`, the current simulation time is stored in `last_clk_in`
* On each rising edge of `clk_out`, the current simulation time is stored in `last_clk_out`
* A combinational block compares the timestamps:

| Condition                    | Output           |
| ---------------------------- | ---------------- |
| `last_clk_in > last_clk_out` | `UP = 1`         |
| `last_clk_out > last_clk_in` | `DOWN = 1`       |
| equal                        | both outputs `0` |

### Advantages

* Very easy to understand
* Ideal for **reference behavior in testbenches**
* Directly represents the conceptual definition of phase lead/lag

### Limitations

* **Not synthesizable** because it depends on `$time`
* Ignores real hardware timing constraints
* Produces ideal decisions rather than pulse-width phase error signals

### Best Use

Golden behavioral model for simulation verification.

---

# 2. Single Flip-Flop Phase Detector

`single_ff_phase_detector`

### Description

This is the **simplest synthesizable phase detector**. It samples the logic level of the feedback clock `clk_out` on the rising edge of the reference clock `clk_in`.

### Operation

At each `posedge clk_in`:

| Condition      | Interpretation                     | Output     |
| -------------- | ---------------------------------- | ---------- |
| `clk_out == 0` | feedback edge has not occurred yet | `UP = 1`   |
| `clk_out == 1` | feedback edge already occurred     | `DOWN = 1` |

This creates a **binary decision** based on the instantaneous level of the feedback clock.

### Advantages

* Extremely small hardware cost
* Fully synthesizable
* Simple and easy to understand

### Limitations

* Sensitive to **duty cycle of `clk_out`**
* Can misclassify edges near lock
* **Biased around zero phase error**
* Does not handle frequency mismatch well

### Best Use

Educational example of a minimal phase detector or simple digital experiments.

---

# 3. Two-Flip-Flop Phase-Frequency Detector

`two_ff_pfd`

### Description

This is the **classical phase-frequency detector architecture** widely used in PLL and DLL designs.

Two flip-flops independently capture the rising edges of the reference and feedback clocks.

### Operation

| Event             | Action                     |
| ----------------- | -------------------------- |
| `posedge clk_in`  | set `UP`                   |
| `posedge clk_out` | set `DOWN`                 |
| both high         | internal reset clears both |

The reset condition is:

```
clr = rst | (up_ff & down_ff)
```

### Behavior

This produces **UP and DOWN pulses whose widths are proportional to the phase difference**.

### Advantages

* Fully synthesizable
* Robust phase detection
* Detects **frequency mismatch**
* Standard structure used in real silicon PLL/DLL systems

### Limitations

* Asynchronous reset path must be handled carefully in physical implementations
* Reset race behavior depends on gate delays

### Best Use

Primary implementation for real clock synchronization loops.

---

# 4. Sampled XOR Phase Detector

`sampled_xor_phase_detector`

### Description

This detector uses an **XOR gate to detect phase mismatch** and then samples the feedback clock to infer direction.

### Operation

```
phase_error = clk_in ^ clk_out
```

At `posedge clk_in`:

| Condition                             | Interpretation  | Output          |
| ------------------------------------- | --------------- | --------------- |
| `phase_error == 1` and `clk_out == 0` | reference leads | `UP = 1`        |
| `phase_error == 1` and `clk_out == 1` | feedback leads  | `DOWN = 1`      |
| `phase_error == 0`                    | clocks match    | outputs cleared |

### Advantages

* Simple logic structure
* Fully synthesizable
* Uses XOR as a direct phase mismatch indicator

### Limitations

* XOR only indicates **phase difference magnitude**
* Direction is inferred indirectly
* Sensitive to duty cycle differences
* Poor performance near lock
* Cannot detect frequency mismatch

### Best Use

Demonstrating the limitations of XOR-based phase detection.

---

# 5. Edge-Order Phase Detector

`edge_order_phase_detector`

### Description

This implementation determines **which clock edge arrives first** by detecting rising edges of both clocks.

Delayed versions of the clocks are used to generate edge detection signals.

### Operation

```
rise_in  = clk_in  & ~clk_in_d
rise_out = clk_out & ~clk_out_d
```

Decision logic:

| Condition        | Output     |
| ---------------- | ---------- |
| `rise_in` first  | `UP = 1`   |
| `rise_out` first | `DOWN = 1` |

### Advantages

* Fully synthesizable
* Explicitly detects edge ordering
* More intuitive than level-sampling detectors

### Limitations

* No automatic reset of outputs
* Ambiguity if edges occur simultaneously
* Less robust than the two-FF PFD

### Best Use

Experimental binary phase detection based on edge arrival order.

---

# Overall Design Insights

The different implementations highlight how **phase detectors trade off complexity, robustness, and hardware cost**.

| Detector Type | Strength                        | Weakness              |
| ------------- | ------------------------------- | --------------------- |
| Behavioral    | Perfect conceptual model        | Not synthesizable     |
| Single-FF     | Minimal hardware                | Poor near lock        |
| XOR Sampled   | Simple phase mismatch detection | Direction ambiguity   |
| Edge-Order    | Clear edge comparison           | No reset mechanism    |
| Two-FF PFD    | Robust and practical            | Slightly more complex |

Among these designs, the **two-flip-flop phase-frequency detector (`two_ff_pfd`) is the most suitable for real hardware clock synchronization**, while the other implementations serve as useful demonstrations of different phase detection techniques.
