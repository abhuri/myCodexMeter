# myCodex Meter

แอป macOS Menu Bar แบบ Native สำหรับแสดงเปอร์เซ็นต์ Codex ที่คงเหลือ พร้อมเวลารีเซ็ตตามเขตเวลา `Asia/Bangkok`

## ความสามารถ

- แสดงโลโก้ Codex และเปอร์เซ็นต์คงเหลือบน Menu Bar
- แสดง Tooltip เมื่อวางเมาส์ พร้อมรอบโควตาและเวลารีเซ็ต
- แสดงรอบหลัก รอบเสริม และ bucket ของโมเดลอื่นเมื่อ Codex ส่งมา
- รีเฟรชอัตโนมัติทุก 60 วินาทีและหลังเครื่องตื่น
- เปิด Usage Dashboard และตั้งค่าเปิดพร้อม macOS ได้จากเมนู
- อ่านข้อมูลผ่าน `codex app-server` โดยไม่อ่านหรือจัดเก็บ access token

## Build

```bash
cd macos
chmod +x scripts/build-app.sh
./scripts/build-app.sh
```

สคริปต์ใช้ Swift Compiler จาก Command Line Tools โดยตรง จึงไม่ต้องติดตั้ง Xcode ตัวเต็ม

แอปที่ Build แล้วจะอยู่ที่:

```text
dist/myCodex Meter.app
```

## ติดตั้งบนเครื่อง

สคริปต์ติดตั้งจะ Build ตัวล่าสุด คัดลอกแอปไปที่ `/Applications/myCodex Meter.app`
เปิดใช้งาน Launch at Login และเปิดแอปจากตำแหน่งหลัก:

```bash
./scripts/install-app.sh
```

ตรวจสอบหรือเปลี่ยน Launch at Login จาก Terminal ได้ด้วย:

```bash
"/Applications/myCodex Meter.app/Contents/MacOS/CodexUsageMenu" --launch-at-login status
"/Applications/myCodex Meter.app/Contents/MacOS/CodexUsageMenu" --launch-at-login enable
"/Applications/myCodex Meter.app/Contents/MacOS/CodexUsageMenu" --launch-at-login disable
```

## ตรวจสอบ

```bash
./.build/debug/CodexUsageMenu --self-test
./.build/debug/CodexUsageMenu --check-live-usage
```

ถ้า `codex` ไม่ได้อยู่ในตำแหน่งมาตรฐาน ให้กำหนดพาธก่อนเปิดแอป:

```bash
export CODEX_CLI_PATH="/absolute/path/to/codex"
```
