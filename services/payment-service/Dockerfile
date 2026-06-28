#1
FROM golang:1.22-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o payment-service-test

#2
FROM alpine:3.20
WORKDIR /app
COPY --from=build /app/payment-service-test .

# Give the binary to the non-root user
RUN chown app:app /app/payment-service-test

# Run as the non-root user
USER app

EXPOSE 8083
CMD ["./payment-service-test"]