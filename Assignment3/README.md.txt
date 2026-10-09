# COAL Assignment 3: Text Viewport Manager & Keyword Highlighter

**Name:** [Your Name Here]  
**Roll No:** [Your Roll No Here]  
**Course:** Computer Organization & Assembly Language (COAL)  
**Target Architecture:** 16-bit 8088 Assembly (NASM / DOSBox)  

---

## 📌 Description
This program implements a memory-mapped 16-bit text viewport manager in 8088 Assembly Language targeting video segment `0xB800`.

### Key Features:
1. **Double-Line Border Window:** Renders an outer frame from (Row 3, Col 8) to (Row 21, Col 72) using ASCII extended characters with a centered title banner.
2. **Multi-line Text Streaming:** Streams string buffers into memory bounded by custom margins using `LODSB` and `STOSW`.
3. **Bounded 2D Sub-Window Scrolling:** Shifts text upward strictly inside the viewport using `MOVSW` row-stride operations without corrupting double-line border frames.
4. **In-Memory Substring Search & Highlighter:** Traverses video memory with string primitives (`REPE CMPSB`), locating keywords (e.g., `"FAST"`) and dynamically modifying attribute bytes to `0xCE` (Blinking Yellow on Red).
5. **Status Bar:** Prints live match statistics on Row 23 using a stack-based integer conversion subroutine (`printNum`).

---

## 🛠️ Tools Used
* **NASM** (Netwide Assembler)
* **DOSBox v0.74-3** (x86 Emulator)

---

## 🚀 How to Assemble and Run

1. Open your terminal in the `Assignment3` directory.
2. Assemble using NASM:
   ```bash
   nasm -f bin viewport.asm -o viewport.com