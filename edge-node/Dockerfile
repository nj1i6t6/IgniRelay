FROM golang:1.22-alpine AS builder

WORKDIR /app

# 安裝 CGO 依賴庫（因為 go-sqlite3 需要 C compiler）
RUN apk add --no-cache gcc musl-dev

# 複製依賴宣告
COPY go.mod ./
# 處理模組
RUN go mod tidy
RUN go mod download

# 複製原始碼
COPY . .

# 編譯 Go app (啟用 CGO)
RUN CGO_ENABLED=1 GOOS=linux go build -o resqmesh-node ./cmd/resqmesh-node/main.go

# 使用極輕量的 alpine 特意作為最終鏡像 (確保執行環境越小越好)
FROM alpine:latest

WORKDIR /app

# 複製編譯完成的 binary 和靜態/樣板檔案
COPY --from=builder /app/resqmesh-node .
COPY --from=builder /app/web ./web

EXPOSE 8080

CMD ["./resqmesh-node"]
