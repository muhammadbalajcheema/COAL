; ============================================================================
; Program: Text Viewport Manager with Bounded Scrolling & Keyword Highlighter
; Target Architecture: 16-bit 8088 / NASM / DOS COM File
; Segment Mapping: Video Memory at 0xB800
; ============================================================================

[org 0x0100]

jmp start

; ============================================================================
; DATA SECTION
; ============================================================================

title_str       db ' TEXT VIEWPORT MANAGER ', 0
status_lbl1     db 'Total Matches Found: ', 0
status_lbl2     db ' | Viewport Status: ACTIVE', 0
search_kw       db 'FAST', 0                      ; Keyword to highlight

; Sample multi-line text buffer (lines terminated with 0)
text_line1      db 'Welcome to the FAST-NU Text Viewport Engine for 8088 Assembly.', 0
text_line2      db 'FAST students learn low-level architecture and video memory manipulation.', 0
text_line3      db 'Building a windowed viewport requires bounded 2D block movement.', 0
text_line4      db 'Keywords such as FAST will be automatically located and highlighted.', 0
text_line5      db 'Scrolling shifts text within boundaries without damaging border frames.', 0
text_line6      db 'The FAST highlighter traverses ES:DI and updates attribute bytes.', 0
text_line7      db 'End of initial document buffer. Press any key to scroll up.', 0
text_line8      db 'FAST viewport status remains ACTIVE across all dynamic updates.', 0

; Array of line pointers
text_buffer     dw text_line1, text_line2, text_line3, text_line4
                dw text_line5, text_line6, text_line7, text_line8
LINE_COUNT      equ 8

; Constants
ATTR_BORDER     equ 0x1F    ; Bright White on Blue
ATTR_TITLE      equ 0x1E    ; Bright Yellow on Blue
ATTR_TEXT       equ 0x07    ; Light Gray on Black
ATTR_HIGHLIGHT  equ 0xCE    ; Blinking Yellow on Red (0xC0 | 0x0E)
ATTR_STATUS     equ 0x70    ; Black on Light Gray

; Viewport Coordinates (0-indexed)
VP_TOP          equ 3
VP_BOTTOM       equ 21
VP_LEFT         equ 8
VP_RIGHT        equ 72

; Text Margins (Inside border)
TXT_LEFT        equ 10      ; VP_LEFT + 2
TXT_RIGHT       equ 70      ; VP_RIGHT - 2
TXT_TOP         equ 4       ; VP_TOP + 1
TXT_BOTTOM      equ 20      ; VP_BOTTOM - 1

; ============================================================================
; MAIN ENTRY POINT
; ============================================================================
start:
    ; 1. Clear Screen
    push word ATTR_TEXT
    call clear_screen

    ; 2. Draw Frame Window (Top:3, Left:8, Bottom:21, Right:72, Attr:0x1F)
    push word VP_TOP
    push word VP_LEFT
    push word VP_BOTTOM
    push word VP_RIGHT
    push word ATTR_BORDER
    call draw_window

    ; 3. Draw Title Banner
    push word title_str
    push word VP_TOP
    push word ATTR_TITLE
    call draw_title

    ; 4. Stream Initial Document Buffer into Viewport
    call render_initial_buffer

    ; 5. Perform Initial Substring Search & Highlight
    push word search_kw
    push word ATTR_HIGHLIGHT
    call find_and_highlight    ; Returns match count in AX

    ; 6. Update Status Bar on Row 23
    push ax                    ; Push Match Count
    call update_status_bar

    ; Wait for keypress before demonstrating bounded scrolling
    mov ah, 0x00
    int 0x16

    ; 7. Demonstrate Bounded Window Scroll Up (Scroll by 2 lines)
    push word TXT_TOP
    push word TXT_LEFT
    push word TXT_BOTTOM
    push word TXT_RIGHT
    push word 2                ; N = 2 lines to scroll
    call scroll_window_up

    ; 8. Re-run Search and Update Status Bar
    push word search_kw
    push word ATTR_HIGHLIGHT
    call find_and_highlight

    push ax
    call update_status_bar

    ; Terminate program
    mov ax, 0x4C00
    int 0x21

; ============================================================================
; SUBROUTINE: clear_screen
; Clear full 80x25 screen using string primitives (STOSW)
; Parameters: [bp + 4] = Fill Attribute
; ============================================================================
clear_screen:
    push bp
    mov bp, sp
    push ax
    push cx
    push di
    push es

    mov ax, 0xB800
    mov es, ax
    xor di, di
    mov cx, 2000               ; 80 * 25 cells

    mov ah, [bp + 4]           ; Attribute
    mov al, ' '                ; Blank character
    cld
    rep stosw                  ; Fill video memory

    pop es
    pop di
    pop cx
    pop ax
    pop bp
    ret 2

; ============================================================================
; SUBROUTINE: draw_window
; Constructs double-line border (0xC9, 0xBB, 0xBA, 0xCD, 0xC8, 0xBC)
; Parameters: [bp + 12] = Top Row
;             [bp + 10] = Left Col
;             [bp + 8]  = Bottom Row
;             [bp + 6]  = Right Col
;             [bp + 4]  = Attribute
; ============================================================================
draw_window:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push di
    push es

    mov ax, 0xB800
    mov es, ax
    mov bh, [bp + 4]           ; Attribute byte

    ; --- Top Border Line ---
    ; DI = (Top * 80 + Left) * 2
    mov ax, [bp + 12]
    mov cx, 80
    mul cx
    add ax, [bp + 10]
    shl ax, 1
    mov di, ax

    ; Top-Left Corner ╔ (0xC9)
    mov al, 0xC9
    mov ah, bh
    stosw

    ; Top Horizontal Line ═ (0xCD)
    mov cx, [bp + 6]
    sub cx, [bp + 10]
    dec cx                     ; Width - 1
    mov al, 0xCD
    rep stosw

    ; Top-Right Corner ╗ (0xBB)
    mov al, 0xBB
    stosw

    ; --- Side Vertical Borders ║ (0xBA) ---
    mov dx, [bp + 12]
    inc dx                     ; Row = Top + 1

.side_loop:
    cmp dx, [bp + 8]
    jge .draw_bottom

    ; Left Vertical Border
    mov ax, dx
    mov cx, 80
    mul cx
    add ax, [bp + 10]
    shl ax, 1
    mov di, ax
    mov al, 0xBA
    mov ah, bh
    stosw

    ; Right Vertical Border
    mov ax, dx
    mov cx, 80
    mul cx
    add ax, [bp + 6]
    shl ax, 1
    mov di, ax
    mov al, 0xBA
    mov ah, bh
    stosw

    inc dx
    jmp .side_loop

.draw_bottom:
    ; --- Bottom Border Line ---
    mov ax, [bp + 8]
    mov cx, 80
    mul cx
    add ax, [bp + 10]
    shl ax, 1
    mov di, ax

    ; Bottom-Left Corner ╚ (0xC8)
    mov al, 0xC8
    mov ah, bh
    stosw

    ; Bottom Horizontal Line ═ (0xCD)
    mov cx, [bp + 6]
    sub cx, [bp + 10]
    dec cx
    mov al, 0xCD
    rep stosw

    ; Bottom-Right Corner ╝ (0xBC)
    mov al, 0xBC
    stosw

    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 10

; ============================================================================
; SUBROUTINE: draw_title
; Draws centered title banner at top row of window
; Parameters: [bp + 8] = String Offset
;             [bp + 6] = Row
;             [bp + 4] = Attribute
; ============================================================================
draw_title:
    push bp
    mov bp, sp
    push ax
    push cx
    push si
    push di
    push es

    ; Calculate string length
    mov si, [bp + 8]
    xor cx, cx
.len_loop:
    cmp byte [si], 0
    je .len_done
    inc cx
    inc si
    jmp .len_loop
.len_done:

    ; Calculate Centered Column: Col = (80 - Length) / 2
    mov ax, 80
    sub ax, cx
    shr ax, 1

    ; Video Offset DI = (Row * 80 + Col) * 2
    mov bx, ax                 ; Col
    mov ax, [bp + 6]           ; Row
    mov dx, 80
    mul dx
    add ax, bx
    shl ax, 1
    mov di, ax

    mov ax, 0xB800
    mov es, ax
    mov si, [bp + 8]
    mov ah, [bp + 4]           ; Attribute
    cld

.print_loop:
    lodsb
    cmp al, 0
    je .done
    stosw
    jmp .print_loop

.done:
    pop es
    pop di
    pop si
    pop cx
    pop ax
    pop bp
    ret 6

; ============================================================================
; SUBROUTINE: render_initial_buffer
; Streams text buffer lines into inner viewport window boundaries
; ============================================================================
render_initial_buffer:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov ax, 0xB800
    mov es, ax

    mov bx, 0                  ; Line index
    mov dx, TXT_TOP            ; Starting Row

.line_loop:
    cmp bx, LINE_COUNT
    jge .done
    cmp dx, TXT_BOTTOM
    jg .done

    ; Calculate DI = (Row * 80 + TXT_LEFT) * 2
    mov ax, dx
    mov cx, 80
    mul cx
    add ax, TXT_LEFT
    shl ax, 1
    mov di, ax

    ; Get string pointer from array
    mov si, bx                  ; Copy line index into SI
shl si, 1                   ; Multiply by 2 (2 bytes per word pointer)
mov si, [text_buffer + si]   ; Load string offset from pointer array
    mov ah, ATTR_TEXT
    cld

.char_loop:
    lodsb
    cmp al, 0
    je .next_line

    ; Ensure text does not overflow right margin
    ; Max bytes allowed per line = (TXT_RIGHT - TXT_LEFT + 1) * 2
    stosw
    jmp .char_loop

.next_line:
    inc bx
    inc dx
    jmp .line_loop

.done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret

; ============================================================================
; SUBROUTINE: scroll_window_up
; 2D Bounded Window Scroll Up using MOVSW and STOSW
; Parameters: [bp + 12] = Top Row
;             [bp + 10] = Left Col
;             [bp + 8]  = Bottom Row
;             [bp + 6]  = Right Col
;             [bp + 4]  = Lines N
; ============================================================================
scroll_window_up:
    push bp
    mov bp, sp
    sub sp, 2                  ; [bp - 2] = Width in Words (Width = Right - Left + 1)

    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    ; Set DS = ES = Video Segment (0xB800) for screen-to-screen block copy
    mov ax, 0xB800
    mov ds, ax
    mov es, ax

    ; Calculate Width in Words
    mov ax, [bp + 6]
    sub ax, [bp + 10]
    inc ax
    mov [bp - 2], ax           ; Store in local variable

    ; Curr_Row = Top Row
    mov dx, [bp + 12]

.row_loop:
    ; Target_Row = Curr_Row + N
    mov ax, dx
    add ax, [bp + 4]

    cmp ax, [bp + 8]           ; Is Target_Row > Bottom Row?
    jg .clear_bottom_lines

    ; --- COPY LINE: Move line at Target_Row to Curr_Row ---
    ; Calculate Destination DI = (Curr_Row * 80 + Left) * 2
    push ax                    ; Save Target_Row
    mov ax, dx                 ; Curr_Row
    mov cx, 80
    mul cx
    add ax, [bp + 10]
    shl ax, 1
    mov di, ax                 ; ES:DI = Destination

    ; Calculate Source SI = (Target_Row * 80 + Left) * 2
    pop ax                     ; Restore Target_Row
    mov cx, 80
    mul cx
    add ax, [bp + 10]
    shl ax, 1
    mov si, ax                 ; DS:SI = Source

    mov cx, [bp - 2]           ; Width in words
    cld
    rep movsw                  ; Shift row up

    inc dx
    jmp .row_loop

.clear_bottom_lines:
    ; --- BLANK OUT VACATED BOTTOM LINES ---
    ; Clear rows from dx up to Bottom Row
.blank_loop:
    cmp dx, [bp + 8]
    jg .finished

    ; DI = (Row * 80 + Left) * 2
    mov ax, dx
    mov cx, 80
    mul cx
    add ax, [bp + 10]
    shl ax, 1
    mov di, ax

    mov cx, [bp - 2]
    mov al, ' '
    mov ah, ATTR_TEXT
    cld
    rep stosw                  ; Fill vacated line with blanks

    inc dx
    jmp .blank_loop

.finished:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax

    mov sp, bp                 ; Deallocate local variables
    pop bp
    ret 10

; ============================================================================
; SUBROUTINE: find_and_highlight
; In-Memory Substring Search & Dynamic Video Attribute Updater
; Parameters: [bp + 6] = Search Keyword Offset
;             [bp + 4] = Highlight Attribute
; Returns:    AX = Total Matches Found
; ============================================================================
find_and_highlight:
    push bp
    mov bp, sp
    sub sp, 6                  ; Stack Locals:
                               ; [bp - 2] = Substring Length
                               ; [bp - 4] = Match Count Counter
                               ; [bp - 6] = Current Screen Row

    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    ; Setup DS = CS (for keyword), ES = 0xB800 (for screen)
    mov ax, cs
    mov ds, ax
    mov ax, 0xB800
    mov es, ax

    ; 1. Calculate Keyword Length
    mov si, [bp + 6]
    xor cx, cx
.kw_len:
    cmp byte [si], 0
    je .kw_len_done
    inc cx
    inc si
    jmp .kw_len
.kw_len_done:
    mov [bp - 2], cx           ; Store Keyword Length
    mov word [bp - 4], 0       ; Initialize Match Count = 0

    ; 2. Traverse Active Viewport (TXT_TOP to TXT_BOTTOM)
    mov word [bp - 6], TXT_TOP

.row_search:
    mov ax, [bp - 6]
    cmp ax, TXT_BOTTOM
    jg .search_complete

    mov bx, TXT_LEFT           ; Column Index

.col_search:
    mov ax, TXT_RIGHT
    sub ax, [bp - 2]
    inc ax                     ; Max starting col = TXT_RIGHT - Len + 1
    cmp bx, ax
    jg .next_row

    ; Calculate Video Memory DI = (Row * 80 + Col) * 2
    mov ax, [bp - 6]
    mov cx, 80
    mul cx
    add ax, bx
    shl ax, 1
    mov di, ax

    ; Compare string at ES:DI against DS:SI
    mov si, [bp + 6]           ; Keyword offset
    mov cx, [bp - 2]           ; Keyword length
    push di                    ; Save DI starting offset for highlighting

.cmp_loop:
    mov al, [es:di]            ; Character from video memory
    mov dl, [ds:si]            ; Character from keyword
    cmp al, dl
    jne .no_match

    add di, 2                  ; Move to next screen char cell (skip attribute)
    inc si
    loop .cmp_loop

    ; --- MATCH FOUND ---
    pop di                     ; Restore original DI
    inc word [bp - 4]          ; Increment Match Count

    ; Overwrite attributes for matched character cells
    mov cx, [bp - 2]
    mov al, [bp + 4]           ; Highlight Attribute
.apply_hl:
    mov [es:di + 1], al        ; Update attribute byte (odd byte offset)
    add di, 2
    loop .apply_hl

    ; Advance column by match length
    add bx, [bp - 2]
    jmp .col_search

.no_match:
    pop di                     ; Clean up saved DI from stack
    inc bx                     ; Move to next column
    jmp .col_search

.next_row:
    inc word [bp - 6]
    jmp .row_search

.search_complete:
    mov ax, [bp - 4]           ; Return match count in AX

    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx

    mov sp, bp                 ; Free local stack frame
    pop bp
    ret 4

; ============================================================================
; SUBROUTINE: update_status_bar
; Displays summary bar at Row 23 with Stack-Based Decimal Number Output
; Parameters: [bp + 4] = Match Count
; ============================================================================
update_status_bar:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov ax, 0xB800
    mov es, ax

    ; DI = (23 * 80 + 0) * 2 = 3680
    mov di, 3680
    mov ah, ATTR_STATUS

    ; 1. Print status_lbl1 ("Total Matches Found: ")
    mov si, status_lbl1
    cld
.p1:
    lodsb
    cmp al, 0
    je .p1_done
    stosw
    jmp .p1
.p1_done:

    ; 2. Print Integer Match Count (Stack-Based Iterative Conversion)
    mov ax, [bp + 4]
    push word ATTR_STATUS
    call printNum

    ; 3. Print status_lbl2 (" | Viewport Status: ACTIVE")
    mov si, status_lbl2
.p2:
    lodsb
    cmp al, 0
    je .p2_done
    stosw
    jmp .p2
.p2_done:

    ; Fill remaining row 23 with blanks
    mov cx, 80
    mov ax, di
    shr ax, 1
    mov bx, 1920               ; Row 24 start cell index
    sub bx, ax
    mov cx, bx
    mov al, ' '
    mov ah, ATTR_STATUS
    rep stosw

    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 2

; ============================================================================
; SUBROUTINE: printNum
; Stack-based decimal integer printing subroutine
; Parameters: [bp + 4] = Attribute
; Expects:    AX = Number to print, ES:DI = Target Video Memory
; ============================================================================
printNum:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx

    mov bx, 10
    xor cx, cx                 ; Digit counter

.digit_loop:
    xor dx, dx
    div bx                     ; AX = Quotient, DX = Remainder
    push dx                    ; Push remainder digit on stack
    inc cx
    cmp ax, 0
    jne .digit_loop

.print_loop:
    pop dx                     ; Pop digit
    add dl, '0'                ; Convert to ASCII
    mov al, dl
    mov ah, [bp + 4]           ; Attribute byte
    stosw
    loop .print_loop

    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 2