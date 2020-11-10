FROM golang:1.14-alpine as builder
WORKDIR $GOPATH/src/$CODEPATH
COPY . .
RUN GO111MODULE=on CGO_ENABLED=0 GOOS=linux GOPROXY=https://mirrors.aliyun.com/goproxy/ go build -o /opt/app app.go

# build server
FROM centos:7.6.1810
WORKDIR /opt
COPY --from=builder /opt/app .
RUN chmod +x /opt/app
CMD [ "app" ]

