# =============================================================================
# CLIProxyAPI Dockerfile - Fly.io 完整配置版本
# 更新日期：2026-01-11
# =============================================================================

# -----------------------------------------------------------------------------
# 阶段一：构建阶段
# -----------------------------------------------------------------------------
FROM golang:1.24-alpine AS builder

RUN apk add --no-cache git ca-certificates

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

ARG VERSION=dev
ARG COMMIT=none
ARG BUILD_DATE=unknown

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -buildvcs=false \
    -ldflags="-s -w \
    -X 'main.Version=${VERSION}' \
    -X 'main.Commit=${COMMIT}' \
    -X 'main.BuildDate=${BUILD_DATE}'" \
    -o ./CLIProxyAPI ./cmd/server/

# -----------------------------------------------------------------------------
# 阶段二：运行阶段
# -----------------------------------------------------------------------------
FROM alpine:3.22

RUN apk add --no-cache ca-certificates tzdata

# 创建用户和目录
RUN addgroup -S cliproxy && adduser -S cliproxy -G cliproxy
RUN mkdir -p /CLIProxyAPI/logs /data/.cli-proxy-api && \
    chown -R cliproxy:cliproxy /CLIProxyAPI /data

WORKDIR /CLIProxyAPI

# 复制二进制文件
COPY --from=builder /app/CLIProxyAPI /CLIProxyAPI/CLIProxyAPI
COPY config.example.yaml /CLIProxyAPI/config.example.yaml

# 创建完整配置文件（支持环境变量覆盖 secret-key）
# 注意：auth-dir 指向 /data 目录，这会通过 Fly.io Volume 持久化
RUN echo 'host: ""' > /CLIProxyAPI/config.yaml && \
    echo 'port: 8317' >> /CLIProxyAPI/config.yaml && \
    echo '' >> /CLIProxyAPI/config.yaml && \
    echo 'remote-management:' >> /CLIProxyAPI/config.yaml && \
    echo '  allow-remote: true' >> /CLIProxyAPI/config.yaml && \
    echo '  secret-key: "${MANAGEMENT_PASSWORD:-admin123}"' >> /CLIProxyAPI/config.yaml && \
    echo '  disable-control-panel: false' >> /CLIProxyAPI/config.yaml && \
    echo '  panel-github-repository: "https://github.com/hmtxj/Cli-Proxy-API-Management-Center"' >> /CLIProxyAPI/config.yaml && \
    echo '' >> /CLIProxyAPI/config.yaml && \
    echo 'auth-dir: "/data/.cli-proxy-api"' >> /CLIProxyAPI/config.yaml && \
    echo '' >> /CLIProxyAPI/config.yaml && \
    echo 'debug: false' >> /CLIProxyAPI/config.yaml && \
    echo 'logging-to-file: false' >> /CLIProxyAPI/config.yaml && \
    echo 'usage-statistics-enabled: true' >> /CLIProxyAPI/config.yaml

RUN chmod +x /CLIProxyAPI/CLIProxyAPI && \
    chown -R cliproxy:cliproxy /CLIProxyAPI /data

ENV TZ=Asia/Shanghai
RUN cp /usr/share/zoneinfo/${TZ} /etc/localtime && echo "${TZ}" > /etc/timezone

EXPOSE 8317

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8317/ || exit 1

USER cliproxy

CMD ["./CLIProxyAPI"]