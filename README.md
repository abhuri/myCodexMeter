# myCodex Meter

แอปขนาดเล็กสำหรับดู Codex Usage จากแถบสถานะของระบบ โดยรองรับทั้ง macOS และ Windows ใน Repository เดียว

## Platforms

| Platform | ตำแหน่ง | การแสดงเปอร์เซ็นต์ | Package |
| --- | --- | --- | --- |
| macOS | Menu Bar ด้านขวาบน | โลโก้ Codex พร้อมข้อความ เช่น `97%` | `myCodex Meter.app` |
| Windows | Notification Area ด้านขวาล่าง | โลโก้ Codex พร้อมเลขแบบ Dynamic Icon เช่น `97` | `myCodex Meter.exe` |

เมื่อวางเมาส์บนไอคอน แอปจะแสดงเปอร์เซ็นต์คงเหลือและเวลารีเซ็ตตามประเทศไทย

## Features

- อ่านข้อมูลผ่าน Codex App Server API `account/rateLimits/read`
- ไม่อ่านหรือจัดเก็บ ChatGPT access token
- รองรับโควตาหลายช่วงเวลาและหลาย Codex buckets
- ใช้โควตาที่เหลือน้อยที่สุดเป็นสถานะหลัก
- สีเขียวเมื่อเหลืออย่างน้อย 50% สีส้มเมื่อเหลือ 20–49% และสีแดงเมื่อต่ำกว่า 20%
- รีเฟรชอัตโนมัติทุก 60 วินาที
- เมนูรีเฟรช เปิด Usage Dashboard เปิดพร้อมระบบ และออกจากแอป
- แสดงข้อผิดพลาดเมื่อไม่พบ Codex CLI, ยังไม่ได้ล็อกอิน หรือ App Server ไม่ตอบกลับ

## Requirements

- ติดตั้ง Codex CLI และล็อกอินด้วยบัญชี ChatGPT แล้ว
- macOS 13 ขึ้นไปสำหรับเวอร์ชัน Mac
- Windows 10 หรือ Windows 11 สำหรับเวอร์ชัน Windows

ถ้า Codex CLI ไม่อยู่ในตำแหน่งมาตรฐาน ให้กำหนด `CODEX_CLI_PATH` เป็นพาธเต็มของ `codex`, `codex.exe` หรือ `codex.cmd`

## Project structure

```text
myCodexMeter/
├── macos/      # Native Swift + AppKit Menu Bar app
├── windows/    # .NET 10 + Windows Forms NotifyIcon app
└── .github/    # GitHub Actions builds for both platforms
```

## Build macOS

```bash
cd macos
./scripts/build-app.sh
```

ผลลัพธ์อยู่ที่ `macos/dist/myCodex Meter.app`

ติดตั้งตัวล่าสุดไว้ใน `/Applications` พร้อมเปิด Launch at Login:

```bash
cd macos
./scripts/install-app.sh
```

## Build Windows

```powershell
windows/scripts/build.ps1 win-x64
```

ผลลัพธ์อยู่ที่ `dist/windows-win-x64/myCodex Meter.exe`

Windows อาจซ่อนไอคอนใหม่ไว้ใต้ปุ่ม `^` ใน Notification Area ผู้ใช้สามารถลากไอคอนออกมาเพื่อให้แสดงตลอดได้

## Tests

```bash
cd macos
swift build
./.build/debug/CodexUsageMenu --self-test
```

```powershell
dotnet run --project windows/tests/MyCodexMeter.Core.SelfTests -c Release
```

เพิ่ม `-- --live` ท้ายคำสั่ง Windows Self-tests เมื่อต้องการตรวจการเชื่อม Codex App Server จริง

## Continuous integration

GitHub Actions สร้าง artifacts เหล่านี้ทุกครั้งที่ Push เข้า `main`

- `myCodex-Meter-macOS.zip`
- `myCodex-Meter-win-x64.zip`
- `myCodex-Meter-win-arm64.zip`
