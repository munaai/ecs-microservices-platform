#1
FROM golang:1.22-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o notification-service-test

#2
FROM alpine:3.20
RUN addgroup -S nonroot && adduser -S nonroot -G nonroot
WORKDIR /app
COPY --from=build --chown=nonroot:nonroot /app/notification-service .
USER nonroot
EXPOSE 8084
CMD ["./notification-service-test"]