#1
FROM golang:1.22-alpine AS build
WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o worker-test

#2
FROM alpine:3.20
WORKDIR /app
COPY --from=build /app/worker-test .
EXPOSE 8090
CMD ["./worker-test"]