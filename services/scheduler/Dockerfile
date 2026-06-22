#1
FROM golang:1.22-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o scheduler-test

#2
FROM alpine:3.20
WORKDIR /app
COPY --from=build /app/scheduler-test .
EXPOSE 8091
CMD ["./scheduler-test"]