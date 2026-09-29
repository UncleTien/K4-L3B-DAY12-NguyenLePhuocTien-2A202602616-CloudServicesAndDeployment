# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay placeholder bằng câu trả lời của bạn.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Nguyễn Lê Phước Tiến  Mã học viên: 2A202602616

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Nếu để mặc định `"changeme"`, khi deploy lên Render mà quên set `AGENT_API_KEY`, app vẫn khởi động bình thường và trả 200 — nhưng bất kỳ ai biết mặc định đó đều gọi được `/ask` miễn phí bằng tiền của mình. Với fail fast, app crash ngay lúc startup, Render báo deploy failed, mình biết ngay là thiếu secret và sửa trước khi có bất kỳ traffic nào vào service.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Dòng log thu được: `{"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T03:11:04.021472+00:00", "user_id": "sv01", "tokens_in": 12, "tokens_out": 45, "cost_usd": 0.0000288}`
>
> Hai việc làm được với JSON log mà print không làm được:
> 1. **Lọc và tìm kiếm tự động**: dùng công cụ như Datadog hay CloudWatch có thể query `cost_usd > 0.01` để tìm các request đắt, hoặc đếm số lần `user_id = "sv01"` trong 1 giờ — print thuần túy không có cấu trúc nên không filter được.
> 2. **Tính toán tổng hợp**: cộng tổng `tokens_in` của tất cả request trong ngày để theo dõi chi phí thực, hoặc vẽ biểu đồ latency theo thời gian — chuỗi text tự do không parse được.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ~1.1 GB |
| Multi-stage | 297 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Chênh lệch ~800 MB là phần compiler và build tools của Python (gcc, make, header files) mà pip cần khi cài một số package có C extension. Stage `builder` dùng chúng để build wheel, nhưng stage `runtime` chỉ copy kết quả đã compiled sang — không mang theo compiler. Ngoài ra còn có apt cache, pip cache và các file tạm của quá trình cài đặt bị loại bỏ hoàn toàn vì chúng không tồn tại trong stage mới.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Với Dockerfile multi-stage hiện tại: khi sửa `app/main.py`, các layer `FROM`, `WORKDIR`, `COPY requirements.txt`, `RUN pip install` đều được dùng lại từ cache vì chúng không phụ thuộc source code. Chỉ layer `COPY app/ ./app/` trở đi mới phải chạy lại — rất nhanh vì không cài lại thư viện.
>
> Nếu đặt `COPY . .` trước `RUN pip install`: mỗi lần sửa bất kỳ file nào (kể cả README hay comment) đều invalidate cache tại bước COPY, buộc `pip install` chạy lại từ đầu — mất thêm vài phút mỗi lần build.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện: (1) Kẻ tấn công tìm được lỗ hổng injection trong `/ask` — ví dụ code eval input từ user. (2) Họ chạy được lệnh shell bên trong container với quyền root. (3) Nếu Docker socket được mount hoặc có lỗ hổng kernel, root trong container có thể leo thang thành root trên host machine — toàn bộ server bị chiếm.
>
> Lệnh `USER appuser` cắt đứt ở bước (2): dù khai thác được lỗ hổng, kẻ tấn công chỉ có quyền của `appuser` (không có sudo, không ghi được ra ngoài `/app`). Bước leo thang từ user thường lên root host khó hơn nhiều và thường cần thêm một lỗ hổng riêng.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> Với đếm theo phút đồng hồ, có thể gửi 20 request trong 2 giây: gửi 10 request vào giây 59 của phút N (vẫn trong hạn mức phút N), rồi gửi thêm 10 request vào giây 00 của phút N+1 (counter vừa reset về 0). Tổng 20 request trong khoảng 1-2 giây mà vẫn hợp lệ.
>
> Sliding window tránh được điều này vì lúc nào cũng đếm trong 60 giây gần nhất — 10 request giây 59 vẫn còn nằm trong cửa sổ khi tính đến giây 00+1, nên request thứ 11 bị chặn ngay.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> Rate limit kiểm soát **tần suất** (bao nhiêu request/phút), cost guard kiểm soát **ngân sách** (bao nhiêu USD/tháng).
>
> Rate limit cho qua nhưng cost guard chặn: user gửi 5 request/phút (dưới hạn mức 10), nhưng mỗi câu hỏi rất dài — 50k token — nên chỉ 3 request đã tiêu hết $10 ngân sách tháng. Request thứ 4 bị cost guard chặn dù tần suất vẫn ổn.
>
> Rate limit chặn nhưng cost guard cho qua: user mới, chưa tiêu đồng nào, nhưng gửi 15 request trong 1 phút (mỗi request chỉ hỏi 1 token, rất rẻ). Rate limit chặn ở request thứ 11 dù ngân sách còn gần như nguyên vẹn.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Thứ tự sự kiện: (1) Redis mất kết nối. (2) Cả 3 container gọi endpoint gộp để liveness check — tất cả đều trả 503 vì Redis lỗi. (3) Orchestrator (Docker/K8s) nhận 503 liveness → đánh giá process đã chết → restart cả 3 container đồng thời. (4) Trong lúc restart, không có container nào nhận request → service down hoàn toàn. (5) Redis phục hồi sau 30 giây, nhưng lúc này app đang trong vòng restart loop.
>
> Với /health và /ready tách biệt: /health vẫn 200 (process còn sống), chỉ /ready trả 503 → load balancer ngừng gửi traffic mới vào nhưng container không bị restart → khi Redis phục hồi, /ready tự xanh trở lại, không mất thêm downtime.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Với Redis: `history_length` tăng đều 0 → 2 → 4 → 6... dù request rơi vào container khác nhau, vì tất cả đọc/ghi cùng một Redis key `history:sv-test`.
>
> Nếu lưu trong dict Python: `history_length` sẽ tăng không nhất quán — request rơi vào container A thì thấy history của A, rơi vào B thì thấy history của B (thường là 0 hoặc ít hơn). Đôi khi thấy 0 → 2 → 0 → 2 luân phiên nếu load balancer round-robin đều nhau. Agent "mất trí nhớ" mỗi lần request đổi container.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> Lỗi gặp phải: khi deploy lần đầu, service crash ngay lúc startup với lỗi `NotImplementedError: TODO (CP4): cài đặt install` trong log của Render.
>
> Tìm ra nguyên nhân: xem Runtime Logs trên Render dashboard, thấy traceback trỏ vào `app/lifecycle.py` dòng `install()`. Nguyên nhân là `lifecycle.install()` được gọi trong `lifespan()` của FastAPI khi app khởi động, nhưng hàm đó chưa implement (vẫn còn `raise NotImplementedError`).
>
> Cách sửa: implement đầy đủ `install()` và `request_shutdown()` trong `lifecycle.py` — đăng ký SIGTERM/SIGINT handler và lưu lại handler cũ của uvicorn. Sau khi push code mới, Render tự redeploy và service khởi động thành công.
