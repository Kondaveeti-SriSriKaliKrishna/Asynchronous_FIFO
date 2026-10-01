# Asynchronous FIFO — RTL Design & Verification

## Overview

This project implements and verifies a **parameterized Asynchronous FIFO (First-In-First-Out)** using **Verilog**.

The FIFO uses separate clocks for the write and read operations, allowing data to be transferred between two different clock domains. The design uses **binary pointers, Gray-code pointers, and two-stage clock-domain synchronization** for safe pointer transfer.

The verification testbench checks normal operation, boundary conditions, error conditions, pointer wrap-around, simultaneous read/write operation, different clock speeds, and reset behavior.

---

## ⚙️ FIFO Features

- Parameterized FIFO depth and data width
- Separate write and read clock domains
- Binary read and write pointers
- Binary-to-Gray code conversion
- Gray-code pointer synchronization
- Two-flip-flop clock-domain synchronization
- FIFO full detection
- FIFO empty detection
- Write overflow detection
- Read underflow detection
- Pointer wrap-around
- Simultaneous read and write operation
- Different write and read clock speeds
- Reset operation
- Directed verification testbench
- Simple scoreboard for data checking
- Simulation logs and timing waveforms

---

## FIFO Configuration

The FIFO design is parameterized to make the depth and data width configurable.

| Parameter | Description | Simulation Value |
|-----------|-------------|------------------|
| `DEPTH` | Number of entries in the FIFO | `16` |
| `WIDTH` | Width of each FIFO data entry | `8` |
| `PTR_WIDTH` | Pointer width derived from FIFO depth | `$clog2(DEPTH)` |

Therefore, the FIFO used in this project can store **16 entries of 8-bit data**.

---

## 🔌 Interface Signals

### Write Side

| Signal | Direction | Description |
|--------|-----------|-------------|
| `wr_clk` | Input | Write clock |
| `wdata` | Input | Data to be written into the FIFO |
| `wr_en` | Input | Write request |
| `full` | Output | Indicates that the FIFO is full |
| `wr_error` | Output | Indicates a write attempt when the FIFO is full |

### Read Side

| Signal | Direction | Description |
|--------|-----------|-------------|
| `rd_clk` | Input | Read clock |
| `rd_en` | Input | Read request |
| `rdata` | Output | Data read from the FIFO |
| `empty` | Output | Indicates that the FIFO is empty |
| `rd_error` | Output | Indicates a read attempt when the FIFO is empty |

### Reset

| Signal | Direction | Description |
|--------|-----------|-------------|
| `rst` | Input | Reset signal |

---

## 🏗️ FIFO Operation

The asynchronous FIFO contains memory, separate read and write pointers, and synchronization logic between the two clock domains.

```text
                  ASYNCHRONOUS FIFO

 WRITE CLOCK DOMAIN                    READ CLOCK DOMAIN
        │                                      │
        ▼                                      ▼
   Write Pointer                           Read Pointer
        │                                      │
        ▼                                      ▼
 Binary → Gray                             Binary → Gray
        │                                      │
        │                                      │
        ▼                                      ▼
  2-FF Synchronizer                      2-FF Synchronizer
        │                                      │
        └──────────────┐        ┌──────────────┘
                       ▼        ▼
                    FIFO MEMORY
                       │
                       ▼
                  Read / Write Data
```

The FIFO follows the basic First-In-First-Out principle:

```text
Write:  Data A → Data B → Data C → Data D

Read:   Data A → Data B → Data C → Data D
```

The write and read operations can happen using different clocks.

---

## 1. Write Operation

A write occurs when:

```text
wr_en = 1
full  = 0
```

The input data is stored in FIFO memory using the lower bits of the write pointer.

```text
Write Enable
     │
     ▼
Check FULL
     │
     ├── Full → No Write
     │
     └── Not Full
            │
            ▼
        Write Data
            │
            ▼
      Update Write Pointer
```

The write pointer is maintained in binary and Gray-code form.

---

## 2. Read Operation

A read occurs when:

```text
rd_en = 1
empty = 0
```

The data is read from FIFO memory using the lower bits of the read pointer.

```text
Read Enable
     │
     ▼
Check EMPTY
     │
     ├── Empty → No Read
     │
     └── Not Empty
            │
            ▼
         Read Data
            │
            ▼
       Update Read Pointer
```

The read pointer is also maintained in binary and Gray-code form.

---

## 3. Binary Pointers

The design uses separate binary pointers for writing and reading.

```verilog
reg [PTR_WIDTH:0] wr_ptr_bin;
reg [PTR_WIDTH:0] rd_ptr_bin;
```

An extra pointer bit is used for wrap-around detection.

The lower pointer bits are used as the FIFO memory address.

```text
Pointer
   │
   ├── Extra MSB
   │      │
   │      └── Wrap-around / Full detection
   │
   └── Lower bits
          │
          └── FIFO memory address
```

---

## 4. Gray-Code Pointers

The binary pointers are converted to Gray code.

```verilog
bin_to_gray = (binary_value >> 1) ^ binary_value;
```

The design uses:

```text
wr_ptr_gray
rd_ptr_gray
```

Gray code is used for clock-domain crossing because only one bit changes between adjacent Gray-code values.

---

## 5. Clock-Domain Synchronization

The write and read clocks are independent.

Therefore, a pointer generated in one clock domain cannot be directly used in the other clock domain.

The design synchronizes the Gray-coded pointers using two flip-flop stages.

### Write Pointer → Read Clock Domain

```text
Write Clock Domain

wr_ptr_gray
     │
     ▼
┌───────────┐
│ Flip-Flop │
│    1      │
└─────┬─────┘
      │
      ▼
┌───────────┐
│ Flip-Flop │
│    2      │
└─────┬─────┘
      │
      ▼
Read Clock Domain
```

### Read Pointer → Write Clock Domain

```text
Read Clock Domain

rd_ptr_gray
     │
     ▼
┌───────────┐
│ Flip-Flop │
│    1      │
└─────┬─────┘
      │
      ▼
┌───────────┐
│ Flip-Flop │
│    2      │
└─────┬─────┘
      │
      ▼
Write Clock Domain
```

This allows the two clock domains to safely receive pointer information from each other.

---

## 6. Full Detection

The FIFO is considered full when the next write pointer reaches the corresponding full condition relative to the synchronized read pointer.

The design compares the next Gray-coded write pointer with the synchronized read pointer.

```verilog
assign full_next =
    (wr_ptr_gray_next ==
    {~rd_ptr_wr_clk[PTR_WIDTH:PTR_WIDTH-1],
      rd_ptr_wr_clk[PTR_WIDTH-2:0]});
```

When the FIFO becomes full:

```text
full = 1
```

A further write operation is blocked and `wr_error` indicates an invalid write attempt.

---

## 7. Empty Detection

The FIFO is empty when the next read pointer matches the synchronized write pointer.

```verilog
assign empty_next = (rd_ptr_gray_next == wr_ptr_rd_clk);
```

When the FIFO is empty:

```text
empty = 1
```

A further read operation is blocked and `rd_error` indicates an invalid read attempt.

---

## 8. Overflow Detection

A write overflow occurs when a write is attempted while the FIFO is full.

```verilog
assign wr_error = wr_en && full;
```

Expected condition:

```text
wr_en = 1
full  = 1
     ↓
wr_error = 1
```

---

## 9. Underflow Detection

A read underflow occurs when a read is attempted while the FIFO is empty.

```verilog
assign rd_error = rd_en && empty;
```

Expected condition:

```text
rd_en = 1
empty = 1
     ↓
rd_error = 1
```

---

# 🧪 Verification

The testbench uses directed test scenarios to verify important asynchronous FIFO operating conditions.

Eight testcases are implemented:

1. `basic`
2. `overflow`
3. `underflow`
4. `wrap`
5. `concurrent`
6. `write_fast`
7. `read_fast`
8. `reset`

The testbench also uses a simple scoreboard to store expected data and compare it with the data read from the FIFO.

---

## 1. `basic` — Basic FIFO Operation

### Objective

Verify normal write and read operation of the asynchronous FIFO.

### Test Operation

The testbench:

1. Writes 8 data values.
2. Waits for pointer synchronization.
3. Reads the stored data.
4. Compares the read data with the expected data.

```text
Write Data
    │
    ▼
FIFO
    │
    ▼
Read Data
    │
    ▼
Scoreboard Comparison
```

### Result

The test checks that data is transferred in the correct FIFO order.

---

## 2. `overflow` — Write Overflow

### Objective

Verify that the FIFO detects an attempt to write when the FIFO is full.

### Test Operation

The testbench writes:

```text
DEPTH + 1
```

values.

For this project:

```text
16 + 1 = 17 writes
```

After the FIFO becomes full, another write is attempted.

Expected condition:

```text
full     = 1
wr_error = 1
```

### Result

The test verifies the FIFO full condition and write overflow detection.

---

## 3. `underflow` — Read Underflow

### Objective

Verify that the FIFO detects an attempt to read when the FIFO is empty.

### Test Operation

A read operation is performed when there is no valid data available.

Expected condition:

```text
empty    = 1
rd_error = 1
```

### Result

The test verifies read underflow detection.

---

## 4. `wrap` — Pointer Wrap-Around

### Objective

Verify that the read and write pointers correctly wrap around after reaching the end of the FIFO memory.

### Test Operation

The FIFO is written and read for two complete FIFO cycles.

```text
Write DEPTH
Read  DEPTH

Write DEPTH
Read  DEPTH
```

For this project:

```text
Write 16
Read  16

Write 16
Read  16
```

### Result

The test verifies that pointer wrap-around works correctly.

---

## 5. `concurrent` — Simultaneous Read and Write

### Objective

Verify that read and write operations can occur concurrently.

### Test Operation

The testbench performs write and read operations in parallel.

```text
Write Process ───────────────►
                 FIFO
Read Process  ◄──────────────
```

The read data is compared with the expected data using the scoreboard.

### Result

The test verifies FIFO operation while read and write activities occur at the same time.

---

## 6. `write_fast` — Faster Write Clock

### Objective

Verify FIFO operation when the write clock is faster than the read clock.

### Clock Configuration

```text
Write Clock Period = 10 ns
Read Clock Period  = 20 ns
```

Therefore:

```text
Write Clock > Read Clock frequency
```

The test performs write and read operations concurrently and checks the returned data.

### Result

The test verifies FIFO operation when data is produced faster than it is consumed.

---

## 7. `read_fast` — Faster Read Clock

### Objective

Verify FIFO operation when the read clock is faster than the write clock.

### Clock Configuration

```text
Write Clock Period = 20 ns
Read Clock Period  = 10 ns
```

The test writes initial data, allows pointer synchronization, and then performs concurrent write and read operations.

### Result

The test verifies FIFO operation when data is consumed faster than it is produced.

---

## 8. `reset` — Reset Operation

### Objective

Verify that the FIFO returns to the correct initial state after reset.

### Test Operation

The testbench:

1. Writes data into the FIFO.
2. Applies reset.
3. Releases reset.
4. Checks the FIFO status.

Expected condition after reset:

```text
empty = 1
```

The read and write pointers are also reset.

### Result

The test verifies reset behavior and the return of the FIFO to an empty state.

---

# 📊 Verification Summary

| Testcase | Verification Scenario | Expected Result |
|----------|------------------------|-----------------|
| `basic` | Normal write/read operation | Data read correctly |
| `overflow` | Write when FIFO is full | `wr_error = 1` |
| `underflow` | Read when FIFO is empty | `rd_error = 1` |
| `wrap` | Pointer wrap-around | FIFO continues operation |
| `concurrent` | Simultaneous read/write | Data remains correct |
| `write_fast` | Write clock faster | FIFO operates correctly |
| `read_fast` | Read clock faster | FIFO operates correctly |
| `reset` | Reset during FIFO operation | `empty = 1` |

---

# 📈 Simulation Results

Simulation logs and timing waveforms are included in the repository for each verification scenario.

The simulation results are used to analyze:

- FIFO write operation
- FIFO read operation
- Full condition
- Empty condition
- Write overflow
- Read underflow
- Pointer wrap-around
- Concurrent read/write operation
- Different write/read clock speeds
- Reset behavior
- Read data compared with expected data

---

# 📁 Repository Structure

```text
Asynchronous_FIFO/
│
├── Design_code/
│   └── asynchronous_fifo.v
│
├── Testbench/
│   └── tb_asynchronous_fifo.v
│
├── Sim_log_files/
│   ├── basic.txt
│   ├── overflow.txt
│   ├── underflow.txt
│   ├── wrap.txt
│   ├── concurrent.txt
│   ├── write_fast.txt
│   ├── read_fast.txt
│   └── reset.txt
│
├── Timing_waves/
│   ├── basic.png
│   ├── overflow.png
│   ├── underflow.png
│   ├── wrap.png
│   ├── concurrent.png
│   ├── write_fast.png
│   ├── read_fast.png
│   └── reset.png
│
└── README.md
```

---

# 🛠️ Tools Used

- **Verilog** — RTL design and testbench development
- **QuestaSim** — RTL simulation and waveform analysis
- **Git/GitHub** — Version control and project documentation

---

# ▶️ Running the Simulation

The testbench supports testcase selection using the `testname` plusarg.

### Basic Operation

```text
+testname=basic
```

### Overflow

```text
+testname=overflow
```

### Underflow

```text
+testname=underflow
```

### Pointer Wrap-Around

```text
+testname=wrap
```

### Concurrent Read/Write

```text
+testname=concurrent
```

### Write Clock Faster

```text
+testname=write_fast
```

### Read Clock Faster

```text
+testname=read_fast
```

### Reset

```text
+testname=reset
```

The simulation transcript and timing waveform can then be used to analyze the FIFO behavior for each scenario.

---

# 🔍 Verification Approach

The current verification environment follows a **directed verification approach**.

The testbench targets:

```text
                    FIFO Verification
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
 Normal Operation     Boundary Tests     Error Tests
        │                  │                  │
     Basic Test       Full / Empty       Overflow
                                           Underflow
        │
        ▼
 Pointer / Clock Tests
        │
   ┌────┴─────┐
   │          │
  Wrap     Different
           Clock Speeds
        │
        ▼
 Concurrent Read + Write
        │
        ▼
      Reset
```

The testbench uses reusable tasks to generate write and read transactions, maintains expected data, and compares the actual read data with the expected data.

---

# 🚀 Future Improvements

The current project provides directed functional testing of the asynchronous FIFO. The verification environment can be extended further with:

- SystemVerilog Assertions (SVA)
- Functional coverage
- Constrained-random stimulus
- More advanced scoreboard
- Randomized read/write clock frequencies
- Additional corner-case scenarios
- Monitor and checker components
- UVM-based verification environment

These improvements can extend the project from a directed verification environment toward a more advanced reusable verification environment.

---

# 👨‍💻 Author

## Kondaveeti Sri Sri Kali Krishna

**Electronics and Communication Engineering | Design Verification | VLSI**

Interested in RTL Design, Verilog, Functional Verification, and VLSI Design Verification.

---

## ⭐ Project Highlights

This project demonstrates practical experience with:

- Asynchronous FIFO architecture
- Parameterized RTL design
- Verilog
- Binary and Gray-code pointers
- Clock-domain crossing
- Two-flop pointer synchronization
- FIFO full and empty detection
- Overflow and underflow detection
- Pointer wrap-around
- Concurrent read/write verification
- Different clock-domain speeds
- Directed testbench development
- Scoreboard-based data checking
- QuestaSim simulation
- Timing waveform analysis
- GitHub-based project documentation
