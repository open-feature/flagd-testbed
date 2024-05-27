module github.com/open-feature/test-harness/sync

go 1.21

require (
	buf.build/gen/go/open-feature/flagd/grpc/go v1.3.0-20240215170432-1e611e2999cc.3
	buf.build/gen/go/open-feature/flagd/protocolbuffers/go v1.34.1-20240215170432-1e611e2999cc.1
	github.com/fsnotify/fsnotify v1.7.0
	golang.org/x/exp v0.0.0-20240525044651-4c93da0ed11d
	google.golang.org/grpc v1.63.2
)

require (
	golang.org/x/net v0.24.0 // indirect
	golang.org/x/sys v0.19.0 // indirect
	golang.org/x/text v0.14.0 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20240401170217-c3f982113cda // indirect
	google.golang.org/protobuf v1.34.1 // indirect
)
