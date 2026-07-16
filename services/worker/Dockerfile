# Build stage
FROM golang:1.24-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o worker-test

# Runtime stage
FROM alpine:3.20
RUN apk add --no-cache python3
RUN addgroup -S nonroot && adduser -S nonroot -G nonroot
WORKDIR /app
COPY --from=build --chown=nonroot:nonroot /app/worker-test .
COPY --chown=nonroot:nonroot entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
USER nonroot
EXPOSE 8090
ENTRYPOINT ["/entrypoint.sh"]
CMD ["./worker-test"]