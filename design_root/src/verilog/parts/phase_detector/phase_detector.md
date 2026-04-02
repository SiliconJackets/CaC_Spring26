---

# Digital Delay Locked Loop (DLL) Phase Detector

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

## 1. Phase Detector System Context

We have chosen to implement the bang-bang style phase detector. 
