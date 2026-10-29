# SmartPark Admin

React + TypeScript + Vite, đăng nhập Supabase Auth và quản lý các bãi thuộc owner
hiện tại. Các trang: Tổng quan, Bãi đỗ/vị trí, Đặt chỗ/phương tiện, Nhân viên,
Báo cáo và Bảng giá. Dữ liệu lấy từ RPC và cập nhật qua Realtime + tải lại.

```powershell
npm.cmd ci
npm.cmd run dev
npm.cmd run build
npm.cmd test
```

Đăng ký tài khoản bằng app khách và cấp owner theo
[hướng dẫn backend](../docs/SUPABASE_SETUP.md). Chủ bãi phân công nhân viên đã
đăng ký, không tạo tài khoản Auth bằng khóa quản trị trong browser. Mỗi bảng giá
được kiểm tra version ở server; sửa số xe trong bãi không phải một thao tác thủ công.

URL/public key có mặc định trong source; có thể ghi đè bằng `.env.local` theo
`.env.example`. Không đặt secret key vào biến VITE_. LocalStorage chỉ dùng bởi
Supabase để giữ phiên và cho lựa chọn giao diện, không lưu dữ liệu nghiệp vụ demo.

Playwright sử dụng fixture HTTP riêng, không ghi Cloud. Screenshots cũ trong docs
là tham chiếu thiết kế prototype; ảnh kiểm tra hiện tại nằm trong test-results.
Chưa triển khai hosting; khi tự triển khai sau này cần fallback index.html cho
React Router. Không có thao tác deploy trong các workflow hiện tại.

## Giao diện đăng nhập

Màn hình đăng nhập mới ở `src/components/admin-auth.tsx` và `admin-auth.css`:
minh họa SVG bãi đỗ riêng, bố cục desktop/mobile, giao diện sáng/tối, hiện mật khẩu,
nhắc Caps Lock, trạng thái chờ/lỗi và gửi liên kết khôi phục qua Supabase Auth.
Không hiển thị số liệu vận hành minh họa hoặc tự cấp quyền cho tài khoản.

Bộ Playwright có 33 test, gồm kiểm tra đăng nhập, gửi khôi phục, chặn gửi lặp,
responsive 320–1440px, dark mode và reduced motion. HTTP được intercept trong test,
không gửi email hoặc tạo phiên đăng nhập trên Cloud thật.
