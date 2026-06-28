# Build stage
FROM golang:1.22-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o api-gateway-test

# Runtime stage
FROM alpine:3.20
RUN addgroup -S nonroot && adduser -S nonroot -G nonroot
WORKDIR /app
COPY --from=build --chown=nonroot:nonroot /app/api-gateway-test .
USER nonroot
EXPOSE 8080
CMD ["./api-gateway-test"]