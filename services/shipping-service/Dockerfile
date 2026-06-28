#1
FROM golang:1.22-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o shipping-service-test

#2
FROM alpine:3.20
RUN addgroup -S nonroot && adduser -S nonroot -G nonroot
WORKDIR /app
COPY --from=build --chown=nonroot:nonroot /app/shipping-service-test .
USER nonroot
EXPOSE 8085
CMD ["./shipping-service-test"]