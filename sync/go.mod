module github.com/open-feature/test-harness/sync

go 1.22.7

toolchain go1.23.3

require (
	buf.build/gen/go/open-feature/flagd/grpc/go v1.4.0-20240215170432-1e611e2999cc.1
	buf.build/gen/go/open-feature/flagd/protocolbuffers/go v1.34.2-20240215170432-1e611e2999cc.2
	github.com/fsnotify/fsnotify v1.7.0
	golang.org/x/exp v0.0.0-20240613232115-7f521ea00fb8
	google.golang.org/grpc v1.68.0
)

require (
	golang.org/x/net v0.29.0 // indirect
	golang.org/x/sys v0.25.0 // indirect
	golang.org/x/text v0.18.0 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20240903143218-8af14fe29dc1 // indirect
	google.golang.org/protobuf v1.34.2 // indirect
)
