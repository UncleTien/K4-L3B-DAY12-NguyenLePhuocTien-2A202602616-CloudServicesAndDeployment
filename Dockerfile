# ═══════════════════════════════════════════════════════════════════
# Stage 1: builder — cài dependency, không mang compiler vào runtime
# ═══════════════════════════════════════════════════════════════════
FROM python:3.11-slim AS builder

WORKDIR /app

# Copy requirements trước để tận dụng Docker layer cache
# (sửa code không phải cài lại thư viện)
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ═══════════════════════════════════════════════════════════════════
# Stage 2: runtime — chỉ copy kết quả từ builder, không có compiler
# ═══════════════════════════════════════════════════════════════════
FROM python:3.11-slim AS runtime

WORKDIR /app

# Copy các package đã cài từ builder
COPY --from=builder /install /usr/local

# Copy source code
COPY app/ ./app/
COPY utils/ ./utils/

# Tạo user thường, không chạy bằng root
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
USER appuser

# Cloud tự gán cổng qua $PORT; mặc định 8000 cho local
ENV PORT=8000
EXPOSE ${PORT}

# Healthcheck gọi /health — Docker biết khi nào container cần restart
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:${PORT}/health')"

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]
