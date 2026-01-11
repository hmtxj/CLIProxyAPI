# =============================================================================
# CLIProxyAPI Dockerfile
# 多阶段构建：编译阶段 + 运行阶段，最小化镜像体积
# 更新日期：2026-01-11
# =============================================================================

# -----------------------------------------------------------------------------
# 阶段一：构建阶段
# 使用 Go 官方 Alpine 镜像编译应用
# -----------------------------------------------------------------------------
FROM golang:1.24-alpine AS builder

# 安装编译依赖（git 用于获取版本信息，ca-certificates 用于 HTTPS）
RUN apk add --no-cache git ca-certificates

WORKDIR /app

# 先复制依赖文件，利用 Docker 缓存层加速后续构建
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码
COPY . .

# 构建参数（可通过 docker build --build-arg 传入）
ARG VERSION=dev
ARG COMMIT=none
ARG BUILD_DATE=unknown

# 编译静态链接的二进制文件
# -s -w 去除调试信息减小体积
# -buildvcs=false 禁用 VCS 信息获取（修复 Fly.io 构建错误）
# -ldflags 注入版本信息
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -buildvcs=false \
    -ldflags="-s -w \
    -X 'main.Version=${VERSION}' \
    -X 'main.Commit=${COMMIT}' \
    -X 'main.BuildDate=${BUILD_DATE}'" \
    -o ./CLIProxyAPI ./cmd/server/

# -----------------------------------------------------------------------------
# 阶段二：运行阶段
# 使用最小化 Alpine 镜像运行应用
# -----------------------------------------------------------------------------
FROM alpine:3.22

# 安装运行时依赖
# - ca-certificates: HTTPS 证书
# - tzdata: 时区数据
RUN apk add --no-cache ca-certificates tzdata

# 创建非 root 用户运行应用（安全最佳实践）
RUN addgroup -S cliproxy && adduser -S cliproxy -G cliproxy

# 创建应用目录
RUN mkdir -p /CLIProxyAPI/logs /CLIProxyAPI/auths && \
    chown -R cliproxy:cliproxy /CLIProxyAPI

WORKDIR /CLIProxyAPI

# 从构建阶段复制编译后的二进制文件
COPY --from=builder /app/CLIProxyAPI /CLIProxyAPI/CLIProxyAPI

# 复制配置文件示例
COPY config.example.yaml /CLIProxyAPI/config.example.yaml

# 创建启用远程管理的配置文件
RUN echo 'host: ""' > /CLIProxyAPI/config.yaml && \
    echo 'port: 8317' >> /CLIProxyAPI/config.yaml && \
    echo 'remote-management:' >> /CLIProxyAPI/config.yaml && \
    echo '  allow-remote: true' >> /CLIProxyAPI/config.yaml && \
    echo '  secret-key: "admin123"' >> /CLIProxyAPI/config.yaml && \
    echo '  disable-control-panel: false' >> /CLIProxyAPI/config.yaml && \
    echo 'auth-dir: "~/.cli-proxy-api"' >> /CLIProxyAPI/config.yaml && \
    echo 'debug: false' >> /CLIProxyAPI/config.yaml

# 设置文件权限
RUN chmod +x /CLIProxyAPI/CLIProxyAPI && \
    chown -R cliproxy:cliproxy /CLIProxyAPI

# 设置时区为上海（可通过环境变量覆盖）
ENV TZ=Asia/Shanghai
RUN cp /usr/share/zoneinfo/${TZ} /etc/localtime && echo "${TZ}" > /etc/timezone

# 暴露端口
# 8317: 主 API 端口
# 8085, 1455, 54545, 51121, 11451: 其他服务端口
EXPOSE 8317 8085 1455 54545 51121 11451

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8317/health || exit 1

# 切换到非 root 用户
USER cliproxy

# 启动命令
CMD ["./CLIProxyAPI"]