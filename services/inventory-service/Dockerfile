#1
FROM golang:1.22-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o inventory-service-test

#2
FROM alpine:3.20
WORKDIR /app
COPY --from=build /app/inventory-service-test .
EXPOSE 8082
CMD ["./inventory-service-test"]