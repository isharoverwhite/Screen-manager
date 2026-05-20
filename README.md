<!-- ========================================================================= -->
<!-- screen-tui — GNU Screen Terminal UI Manager                              -->
<!-- README.md — Written by Experience (DTK)                                 -->
<!-- Version: 5.1.0                                                          -->
<!-- ========================================================================= -->

<p align="center">
  <img src="https://img.shields.io/badge/version-5.1.0-brightgreen?style=for-the-badge&logo=gnu&logoColor=white" alt="Version 5.1.0">
  <img src="https://img.shields.io/badge/platform-Pure%20Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white" alt="Platform: Pure Bash">
  <img src="https://img.shields.io/badge/license-MIT-blue?style=for-the-badge" alt="License: MIT">
  <img src="https://img.shields.io/badge/manager-Screen-cyan?style=for-the-badge&logo=gnu&logoColor=white" alt="GNU Screen">
</p>

<br>

<!-- =========================== TITLE & TAGLINE ============================== -->

<h1 align="center">
  <code>[>_]</code> screen-tui
</h1>

<h3 align="center">
  <em>Trình quản lý phiên GNU Screen — Giao diện Terminal Hacker phong cách Kali Linux</em>
</h3>

<p align="center">
  <strong>screen-tui</strong> là một <strong>Pure Bash TUI</strong> (Terminal User Interface)
  mã nguồn mở, hoàn toàn không phụ thuộc vào Python hay Node.js.
  Nó tự động hiển thị danh sách phiên <strong>GNU Screen</strong> mỗi khi bạn
  đăng nhập terminal hoặc SSH — với giao diện xanh-cyan hacker đặc trưng,
  điều hướng bàn phím, và hỗ trợ đầy đủ attached/detached session.
</p>

<br>

<!-- =========================== PROBLEM & SOLUTION ============================ -->

## 🚨 Vấn đề & Giải pháp

| ❌ **Trước đây (không có screen-tui)** | ✅ **Sau khi cài screen-tui** |
|:---|:---|
| Phải gõ `screen -ls` để xem danh sách phiên | Tự động hiển thị danh sách ngay khi mở terminal |
| Phải nhớ PID và gõ `screen -r PID` thủ công | Chỉ cần phím mũi tên + Enter — attach ngay lập tức |
| Không biết session nào attached hay detached | Màu sắc phân biệt rõ: 🟢 Detached / 🟡 Attached |
| Không theo dõi được thời gian chạy của session | Hiển thị uptime real-time cho từng phiên |
| Phải nhớ cú pháp `screen -S name`, `screen -X kill` | Menu trực quan: `n` = tạo mới, `x` = xoá (có xác nhận) |
| Không có giao diện — terminal trần trụi | Giao diện hacker Kali Linux với khung viền box-drawing |
| Dễ lỡ kill nhầm session quan trọng | Modal xác nhận với ← → chọn Yes/No (mặc định là No) |

<br>

<!-- =========================== KEY FEATURES ================================== -->

## ✨ Tính năng nổi bật

<table>
<tr>
<td width="50%">

### 🖥️ Giao diện & Hiển thị
- Giao diện Kali-Linux hacker aesthetic
- Khung viền UTF-8 box-drawing (╔═╗║╚═╝)
- Danh sách phiên với PID, tên, trạng thái, uptime
- Scroll khi có nhiều phiên (>12)
- Đồng hồ thời gian thực trên header
- Thanh thông tin: PID được chọn, tổng số phiên

</td>
<td width="50%">

### ⌨️ Điều hướng & Thao tác
- ↑↓ di chuyển (vòng quanh ở biên)
- Enter — attach ngay vào session
- `n` — tạo session mới (đặt tên tuỳ chỉnh)
- `x` — kill session (modal xác nhận)
- `q` / Ctrl+X — thoát
- `h` — màn hình trợ giúp tích hợp

</td>
</tr>
<tr>
<td width="50%">

### 🔧 Chế độ Attach thông minh
- Session Detached → attach bình thường
- Session Attached → shared attach (screen -x)
- Sau Ctrl+A D → tự động quay lại menu
- Không crash khi attach vào session lỗi

</td>
<td width="50%">

### 🚀 Cài đặt & Tự động hoá
- **Tự động launch** mỗi khi mở terminal
- Hook vào `.zshrc` / `.bashrc` / `.profile`
- Script duy nhất — không dependency
- Mã nguồn PLAIN TEXT — không base64
- Idempotent — chạy nhiều lần an toàn

</td>
</tr>
<tr>
<td width="50%">

### ⏱️ Theo dõi Uptime
- Parse timestamp từ `screen -ls`
- Hiển thị: `30s`, `5m`, `2h30m`, `3d12h`
- Tự động cập nhật khi render lại
- Xử lý epoch âm / invalid

</td>
<td width="50%">

### ⚡ Hiệu năng & Trải nghiệm
- Chỉ render khi state thay đổi (needs_render)
- Xử lý SIGWINCH — resize terminal an toàn
- Modal kill: mặc định **No** — tránh nhầm lẫn
- `Goodbye!` flash khi thoát bằng `q`

</td>
</tr>
</table>

<br>

<!-- =========================== INTERFACE ===================================== -->

## 🖼️ Giao diện

```
 ╔══════════════════════════════════════════════════════╗
 ║  [>_] SCREEN-TUI v5.0 — GNU Screen Session Manager   ║
 ║  made by Experience (DTK)                             ║
 ╚══════════════════════════════════════════════════════╝

 ───┤ Sessions: 3  │  Selected: #1  │  PID: 12345  │  Uptime: 2h30m  │  14:25:30 ├───

    PID       SESSION NAME              STATUS / UPTIME
    ─────────────────────────────────────────────────────────────────────────────

 ▶ 12345     dev-server                  ● DETACHED   2h30m
   12389     django-api                  ● ATTACHED   45m
   12750     tail-logs                   ● DETACHED   12m

 ─────────────────────────────────────────────────────────────────────────────
  [↑/↓] Navigate • [Enter] Attach • [n] New • [x] Kill • [h] Help • [q] Quit
```

### Modal xác nhận kill

```
 ╔══════════════════════════════════════════════════════╗
 ║  ⚠  KILL SESSION: dev-server  ⚠                     ║
 ║                                                      ║
 ║     Bạn có chắc chắn muốn kill session này?          ║
 ║                                                      ║
 ║           [ Yes ]        < No >                      ║
 ║                                                      ║
 ║  ← → để chọn • Enter để xác nhận • Esc/q để huỷ    ║
 ╚══════════════════════════════════════════════════════╝
```

### Màn hình Help

```
 ╔══════════════════════════════════════════════════════╗
 ║  [?] HELP — Keyboard Reference                      ║
 ╚══════════════════════════════════════════════════════╝

 ───┤ NAVIGATION ├───────────────────────────────────────────
   ↑ / ↓        Move up / down (wrap-around tại biên)
   F5 / Ctrl+L  Refresh danh sách session
   h            Mở màn hình Help

 ───┤ ACTIONS ├──────────────────────────────────────────────
   Enter       Attach vào session đang chọn
               Nếu Attached → shared attach (screen -x)
   n           Tạo session mới (nhập tên)
   x           Kill session (có modal xác nhận)
   q / Ctrl+X  Thoát screen-tui
   Ctrl+C      Thoát ngay (không hiện Goodbye)

 ───┤ LEGEND ├────────────────────────────────────────────────
   ● DETACHED   Session rảnh — sẵn sàng attach
   ● ATTACHED   Session đang dùng — có thể share (screen -x)
   ▶            Dòng đang chọn
   ▲ / ▼        Còn session phía trên / dưới (scroll)
```

<br>

<!-- =========================== INSTALLATION ================================== -->

## 📦 Cài đặt

### Yêu cầu hệ thống

| Điều kiện | Mô tả |
|:---|:---|
| **Hệ điều hành** | Linux (Debian/Ubuntu, Arch, Fedora) |
| **Terminal** | Hỗ trợ ANSI escape codes, UTF-8 |
| **GNU Screen** | Tự động cài đặt nếu chưa có (apt/pacman/dnf) |
| **Dung lượng** | ~80KB cho installer |

### ⚡ One-Line Install (từ GitHub)

```bash
curl -sL https://raw.githubusercontent.com/ryzen30xx/Screen-manager/main/install-screen-tui.sh | bash
```

> 💡 File installer là **plain text** — mở ra đọc được ngay, không mã hoá, không base64.

### Cách 1: Cài đặt từ file local (khuyên dùng khi đã tải về)

```bash
chmod +x install-screen-tui.sh
./install-screen-tui.sh
```

Quy trình cài đặt:
1. Kiểm tra GNU Screen → cài tự động nếu thiếu
2. Copy script `screen-tui` vào `~/.local/bin/`
3. Thêm hook vào `.zshrc`, `.bashrc`, `.profile`
4. Thêm `~/.local/bin` vào PATH
5. Kiểm tra xác nhận và hiển thị phiên ngay lập tức 🎉

### Cách 2: Cập nhật

```bash
./install-screen-tui.sh --update
```

Chỉ cập nhật script `screen-tui` và hook — không chạm vào cấu hình cũ.

### Cách 3: Gỡ cài đặt

```bash
./install-screen-tui.sh --uninstall
```

Xoá hoàn toàn:
- Script `screen-tui` khỏi `~/.local/bin/`
- Toàn bộ hook trong `.zshrc`, `.bashrc`, `.profile`

### Cách 4: Trích xuất mã nguồn

```bash
./install-screen-tui.sh --extract          # In script gốc ra stdout
./install-screen-tui.sh --extract | less   # Xem với less
./install-screen-tui.sh --extract | sha256sum  # Kiểm tra checksum
```

### Cách 5: Chạy thủ công (không cài đặt)

```bash
sed '0,/^__EMBED__$/d' install-screen-tui.sh > screen-tui
chmod +x screen-tui
./screen-tui
```

<br>

<!-- =========================== PROJECT STRUCTURE ============================== -->

## 📁 Cấu trúc dự án

```
Screen-manager/
├── install-screen-tui.sh     # 📦 Installer self-contained (79KB)
│   ├── [dòng 1 → exit 0]     #   ├── Logic cài đặt (Bash installer)
│   └── [sau __EMBED__]       #   └── Script screen-tui nhúng (1402 dòng)
│
└── (sau khi cài đặt)
    ~/.local/bin/
    ├── screen-tui             # 🚀 Trình TUI chính
    └── install-screen-tui     # 📦 Installer (bản sao)

    ~/.zshrc / .bashrc / .profile
    └── # >>> screen-tui auto-launch >>>   # Hook tự động kích hoạt
        eval "$(screen-tui --version)"     # (thực tế: gọi screen-tui)
        # <<< screen-tui auto-launch <<<
```

> **Tính minh bạch**: Installer là một file Bash duy nhất chứa **plain text** — không mã hoá, không base64. Bạn có thể mở bằng bất kỳ editor nào để đọc toàn bộ mã nguồn script screen-tui.

<br>

<!-- =========================== COLORS & FORMATTING =========================== -->

## 🎨 Bảng màu & Formatting

| Màu sắc | Mã ANSI | Ý nghĩa | Áp dụng |
|:--------|:--------|:--------|:--------|
| 🟢 **Xanh lá** | `\x1b[1;32m` | Primary — Detached, menu chính | Khung viền, mũi tên, session Detached |
| 🟡 **Vàng** | `\x1b[1;33m` | Warning — Session Attached | Dot indicator, trạng thái Attached |
| 🔴 **Đỏ** | `\x1b[1;31m` | Danger — Kill, cảnh báo | Nút kill, modal xác nhận |
| 🔵 **Xanh cyan** | `\x1b[1;36m` | Info — Header, box-drawing | Khung banner, thông tin |
| ⚪ **Trắng đậm** | `\x1b[1;37m` | Tiêu đề cột | Headers bảng |
| 🌫 **Mờ (dim)** | `\x1b[2m` | Phụ — scroll indicator, uptime | Thông tin không quan trọng |
| 🔄 **Reverse** | `\x1b[7m` | Highlight | (Dự trữ) |

Phong cách: **Kali Linux Hacker Aesthetic** — xanh lá chủ đạo, khung viền kép, thông tin cô đọng.

<br>

<!-- =========================== TECHNOLOGY ===================================== -->

## 🛠️ Công nghệ sử dụng

| Công nghệ | Vai trò |
|:----------|:--------|
| **Bash** `#!/usr/bin/env bash` | Ngôn ngữ chính — toàn bộ script chạy trên Bash |
| **GNU Screen** | Trình multiplexer terminal — quản lý session |
| **ANSI Escape Codes** (`\x1b[...m`) | Tô màu, định dạng, tạo giao diện TUI |
| **UTF-8 Box-Drawing** (`╔═╗║╚═╝`) | Khung viền, border, bảng biểu |
| **sed** | Trích xuất script nhúng từ installer |
| **tput** / `\x1b[2J` | Xoá màn hình, điều khiển terminal |
| **date** `+%s` | Parse timestamp, tính uptime |

### Tại sao là Pure Bash?

```
┌─────────────────────────────────────────────────┐
│  ✅ Không Python       → 0 dependency cài thêm   │
│  ✅ Không Node.js      → tiết kiệm RAM, nhẹ     │
│  ✅ Không base64       → mã nguồn đọc được ngay  │
│  ✅ Chạy mọi nơi       → server, WSL, container  │
│  ✅ Tương thích ngược  → Bash 3.2+ là đủ        │
└─────────────────────────────────────────────────┘
```

<br>

<!-- =========================== KEYBOARD SHORTCUTS ============================= -->

## ⌨️ Bảng phím tắt

| Phím | Chức năng | Mô tả chi tiết |
|:----|:----------|:---------------|
| `↑` | Lên | Di chuyển con trỏ lên (vòng quanh ở biên trên) |
| `↓` | Xuống | Di chuyển con trỏ xuống (vòng quanh ở biên dưới) |
| `Enter` | Attach | Attach vào session được chọn. Nếu đang Attached → hỏi shared attach (`screen -x`) |
| `n` | New session | Tạo session Screen mới, nhập tên tuỳ chỉnh |
| `x` | Kill session | Kill session đang chọn → hiện modal xác nhận |
| `← →` | Chọn Yes/No | Trong modal kill: di chuyển giữa Yes (trái) và No (phải) |
| `h` | Help | Mở màn hình trợ giúp keyboard reference |
| `q` | Quit | Thoát screen-tui (flash "Goodbye!") |
| `Ctrl+X` | Quit | Thoát screen-tui (tương tự `q`) |
| `Ctrl+C` | Exit ngay | Thoát tức thời, không hiển thị "Goodbye!" |
| `F5` | Refresh | Làm mới danh sách session |
| `Ctrl+L` | Refresh | Làm mới danh sách session (tương tự F5) |
| `Esc` | Cancel | Trong modal kill: huỷ, quay lại menu |

### Chi tiết đặc biệt

| Tình huống | Hành vi |
|:-----------|:--------|
| **Không có session nào** | Màn hình trống → tự động gợi ý tạo session mới |
| **Attach vào session đã attached** | Shared attach (`screen -x`) — cả hai cùng xem |
| **Sau Ctrl+A D (detach)** | Quay lại menu screen-tui ngay lập tức |
| **Kill session đã attached** | Force kill bằng `screen -X kill` |
| **Resize terminal** | Tự động render lại (SIGWINCH) |
| **Scroll >12 sessions** | ▲ ▼ indicator + scroll offset |

<br>

<!-- =========================== USAGE FLOW ===================================== -->

## 🔄 Luồng sử dụng (ASCII Diagram)

```

  ╔══════════════════════════════════════════════════════════╗
  ║           MỞ TERMINAL / SSH / LOGIN                     ║
  ╚══════════════════════════════════════════════════════════╝
                              │
                              ▼
              ┌───────────────────────────────┐
              │   screen-tui AUTO-LAUNCH       │
              │   (hook trong .zshrc/.bashrc)  │
              └───────────────┬───────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │   Phân tích screen -ls         │
              └───────────────┬───────────────┘
                              │
                    ┌─────────┴──────────┐
                    ▼                    ▼
          ┌─────────────────┐  ┌─────────────────┐
          │  Có session     │  │  Không session  │
          └────────┬────────┘  └────────┬────────┘
                   │                    │
                   ▼                    ▼
          ┌─────────────────┐  ┌─────────────────┐
          │  MENU CHÍNH     │  │  MÀN HÌNH TRỐNG  │
          │  Danh sách      │  │  [n] Tạo mới     │
          │  + thông tin    │  │  [q] Thoát       │
          └────────┬────────┘  └────────┬────────┘
                   │                    │
         ┌─────────┼─────────┐          │
         ▼         ▼         ▼          │
   ┌────────┐ ┌────────┐ ┌────────┐     │
   │[Enter] │ │ [n]    │ │ [x]    │     │
   │Attach  │ │Tạo mới │ │Kill    │     │
   └───┬────┘ └───┬────┘ └───┬────┘     │
       │          │          │          │
       ▼          ▼          ▼          │
   ┌────────┐ ┌────────┐ ┌────────┐     │
   │screen  │ │screen  │ │Modal   │     │
   │ -r     │ │ -S name│ │Xác nhận│     │
   │hoặc -x │ │ + attach│ │[Yes/No]│     │
   └────────┘ └────────┘ └───┬────┘     │
       │          │          │          │
       ▼          ▼          ▼          │
   ┌──────────────────────────────┐     │
   │  Ctrl+A D (detach)           │     │
   │  → Tự động quay lại MENU    │     │
   └──────────────────────────────┘     │
       │                                │
       └──────────── ALL ROADS ─────────┘
                              │
                              ▼
                   ┌──────────────────┐
                   │  [q] / Ctrl+X    │
                   │  → Goodbye! 🖐️   │
                   └──────────────────┘
```

<br>

<!-- =========================== ROADMAP ======================================== -->

## 🗺️ Lộ trình phát triển

### ✅ Đã hoàn thành

| Phiên bản | Tính năng |
|:-----------|:----------|
| **v1.0** | TUI cơ bản: danh sách session, attach, create, kill |
| **v2.0** | Scroll cho nhiều session, tối ưu needs_render |
| **v3.0** | Modal kill confirmation, force-kill attached, success/fail notification |
| **v4.0** | CLI flags (--version, --help), terminal size check, kiểm tra GNU Screen |
| **v5.0** | Session uptime counter, timestamp parsing, banner alignment fix |
| **v5.1** | Scroll indicator ▲▼, xoá top/bottom scroll ở biên, clean exit trên `q` |

### 🔜 Kế hoạch tương lai

- [ ] **v6.0** — Tìm kiếm session (Ctrl+F / `/`)
- [ ] **v6.1** — Sort sessions: theo tên / PID / uptime / trạng thái
- [ ] **v7.0** — Chế độ xem chi tiết session (log, windows, processes)
- [ ] **v7.1** — Rename session ngay trong TUI
- [ ] **v8.0** — Multi-select: kill / attach nhiều session cùng lúc
- [ ] **v8.1** — Tabs / categories: nhóm session theo project
- [ ] **v9.0** — Tích hợp tmux backend (tuỳ chọn)
- [ ] **v10.0** — Giao diện config: tuỳ chỉnh màu sắc, phím tắt, auto-refresh interval

> 💡 **Gợi ý tính năng?** Mở issue hoặc gửi pull request — chúng tôi luôn chào đón!

<br>

<!-- =========================== FOOTER ========================================= -->

---

<p align="center">
  <strong>screen-tui</strong> — <em>Because your terminal deserves a command center.</em>
</p>

<p align="center">
  <sub>
  Tác giả: <strong>Experience (DTK)</strong> •
  Phiên bản: <strong>v5.1.0</strong> •
  Trình cài đặt: <strong>v2.3.0</strong> •
  Trang chủ: <a href="https://github.com/example/screen-tui">GitHub</a>
  </sub>
</p>

<p align="center">
  <sub>
  <strong>screen-tui</strong> được xây dựng bằng <strong>Bash thuần</strong> —
  không Python, không Node.js, không phụ thuộc.
  </sub>
</p>

<p align="center">
  <sub>
  <a href="#">Báo lỗi</a> •
  <a href="#">Yêu cầu tính năng</a> •
  <a href="#">Đóng góp</a> •
  <a href="#">Giấy phép MIT</a>
  </sub>
</p>

<!-- ========================================================================= -->
<!-- End of README.md                                                         -->
<!-- ========================================================================= -->
