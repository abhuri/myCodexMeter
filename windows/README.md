# myCodex Meter for Windows

แอปเบื้องหลังสำหรับแสดง Codex Usage ใน Notification Area ด้านขวาล่างของ Windows

## ความสามารถ

- ไอคอนรูปทรง Codex ที่วาดเปอร์เซ็นต์คงเหลือไว้ภายใน
- Tooltip แสดงเปอร์เซ็นต์คงเหลือและเวลารีเซ็ตตามประเทศไทย
- สีเขียว ส้ม และแดงตามระดับ Usage ที่เหลือ
- เมนูรายละเอียดโควตา รีเฟรช เปิด Usage Dashboard และออกจากแอป
- เปิดพร้อม Windows ผ่าน Registry ของผู้ใช้ปัจจุบันโดยไม่ต้องใช้สิทธิ์ Administrator
- เชื่อมต่อผ่าน `codex app-server` โดยไม่อ่านหรือจัดเก็บ access token

## Requirements

- Windows 10 หรือ Windows 11 แบบ x64
- Codex CLI ที่ล็อกอินด้วยบัญชี ChatGPT แล้ว

ถ้า `codex.exe` หรือ `codex.cmd` ไม่อยู่ใน `PATH` ให้กำหนดตัวแปร `CODEX_CLI_PATH`

## Build

```powershell
dotnet publish windows/src/MyCodexMeter.Windows/MyCodexMeter.Windows.csproj `
  -c Release `
  -r win-x64 `
  --self-contained true `
  -p:PublishSingleFile=true `
  -p:IncludeNativeLibrariesForSelfExtract=true `
  -o dist/windows-x64
```

## Self-tests

```powershell
dotnet run --project windows/tests/MyCodexMeter.Core.SelfTests -c Release
```
