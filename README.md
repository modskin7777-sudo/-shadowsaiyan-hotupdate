# Shadow Saiyan – Hot Update qua GitHub

Repo: https://github.com/modskin7777-sudo/-shadowsaiyan-hotupdate

File mod nằm ở `android/media/<đường dẫn>` trong repo. Trên máy, game tải về
`/storage/emulated/<uid>/Android/media/com.ryzengames.shadowsaiyan/<đường dẫn>` (thư mục mod có ưu tiên cao nhất).

```
android/media/src/...     -> Android/media/<gói>/src/...   (Lua)
android/media/res/...     -> Android/media/<gói>/res/...   (hình, effect, âm thanh)
hotupdate_manifest.txt    -> danh sách file + kích thước + CRC32 (tạo bằng tools/make_manifest.py)
deleted.txt               -> file cần xoá khỏi máy
```

## 1. Đẩy lên GitHub (làm 1 lần)

Repo phải để **Public** (game tải qua `raw.githubusercontent.com`, không có token).

```bash
cd shadowsaiyan-hotupdate
git init -b main
git add -A
git commit -m "hot update v1"
git remote add origin https://github.com/modskin7777-sudo/-shadowsaiyan-hotupdate.git
git push -u origin main
```

Kiểm tra link này mở được trên trình duyệt:
`https://raw.githubusercontent.com/modskin7777-sudo/-shadowsaiyan-hotupdate/main/hotupdate_manifest.txt`

## 2. Cài bản có HotUpdate lên máy (làm 1 lần)

Game cần có `HotUpdate.lua` + `app.lua` đã sửa trước thì mới tự tải được. Chép thư mục `android/media/src`
vào `Android/media/com.ryzengames.shadowsaiyan/src` trên máy (ghi đè), rồi **thoát hẳn game và mở lại**.

Từ lần sau mọi thứ tự cập nhật.

## 3. Cập nhật về sau

1. Sửa/thêm file trong `android/media/...` (giữ đúng cấu trúc `src/...`, `res/...`).
2. Cần xoá file trên máy: ghi đường dẫn vào `deleted.txt`.
3. Chạy:
   ```bash
   python3 tools/make_manifest.py
   git add -A && git commit -m "update" && git push
   ```
4. Mở game: sau ~8 giây game kiểm tra, tải file thay đổi, hiện thông báo. **Thoát hẳn game rồi mở lại** để file Lua mới có hiệu lực.

## Cách hoạt động / an toàn

- So `hotupdate_manifest.txt` với `hotupdate_state.txt` trên máy; cùng phiên bản thì dừng (chỉ 1 request nhỏ).
- Mỗi file: kiểm tra kích thước + CRC32 trước khi ghi (ghi `.tmp` rồi đổi tên) – không bao giờ ghi file hỏng.
- Phiên bản chỉ được ghi nhận khi **tất cả** file thành công; lỗi mạng thì lần mở game sau tự thử lại.
- Chỉ ghi vào `src/` và `res/`; chặn `..`, `\`, đường dẫn tuyệt đối; không đụng `src/client/offline/seed/*.txt` (dữ liệu game tự sinh).
- Tắt: tạo file rỗng `hotupdate_off.txt` trong `Android/media/<gói>/`. Bật lại: xoá file đó.
- Nhật ký: `Android/media/<gói>/hotupdate_log.txt`.
- Ép kiểm tra lại toàn bộ file (bỏ qua so phiên bản): gọi `HotUpdate.check(true)`.
- Thử nhánh `main` rồi `master`.

**Bảo mật:** ai có quyền push vào repo này sẽ chạy được code Lua trong game của bạn. Bật 2FA cho tài khoản GitHub.
