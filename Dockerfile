# ----------- Build Stage -----------
FROM golang:1.20-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /rrs ./cmd

# ----------- Run Stage -----------
FROM alpine:latest
WORKDIR /
COPY --from=builder /rrs /rrs
EXPOSE 8080
ENTRYPOINT ["/rrs"]
