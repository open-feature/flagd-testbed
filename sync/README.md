## Flagd GRPC sync provider

A simple [flagd](https://github.com/open-feature/flagd) gRPC flag configuration sync source.

This implementation confirms to gPRC sync definition of flagd - https://buf.build/open-feature/flagd/docs/main:sync.v1

### How to run ?

#### go run / binary

```shell
go run main.go start -f your-flags.json
```

and then, start flagd in local mode (for example with source):

```shell
go run main.go start -f your-flags.json --uri grpc://127.0.0.1:8080 --debug
```

#### Options

Following options are available to the start command,

```text
  -f string
       file to watch (can be specified more than once)
  -certPath string
        certificate path for tls connection
  -h string
        hostDefault of the server (default "0.0.0.0")
  -keyPath string
        certificate key for tls connection
  -p string
        portDefault of the server (default "9090")
  -s    enable tls
```

For example, to start with TLS certs,

```shell
go run main.go -s=true -certPath=server.crt -keyPath=server.key
```

Then start your flagd with gRPC TLS sync.

### Running RPCs from the command line

Test the sync from the command line with [grpcurl](https://github.com/fullstorydev/grpcurl) (requires you have a copy of [sync.proto](https://raw.githubusercontent.com/open-feature/schemas/main/protobuf/sync/v1/sync_service.proto) at `/path/to/proto/dir/`):

```shell
# request all flags
grpcurl -import-path '/path/to/proto/dir' -proto sync.proto -plaintext localhost:9090 flagd.sync.v1.FlagSyncService/FetchAllFlags
```

```shell
# open a stream for getting flag changes
grpcurl -import-path '/path/to/proto/dir' -proto sync.proto -plaintext localhost:9090 flagd.sync.v1.FlagSyncService/SyncFlags
```

```shell
# get metadata
grpcurl -import-path '/path/to/proto/dir' -proto sync.proto -plaintext localhost:9090 flagd.sync.v1.FlagSyncService/GetMetadata
```

### Generate certificates ? 

Given below are some commands you can use to generate CA cert and Server cert to used with `localhost`

#### Generate CA cert

- CA Private Key: `openssl ecparam -name prime256v1 -genkey -noout -out ca.key`
- CA Certificate: `openssl req -new -x509 -sha256 -key ca.key -out ca.cert`

#### Generate Server certificate

- Server private key:  `openssl ecparam -name prime256v1 -genkey -noout -out server.key`
- Server signing request:  `openssl req -new -sha256 -addext "subjectAltName=DNS:localhost" -key server.key -out server.csr`
- Server cert:  `openssl x509 -req -in server.csr -CA ca.cert -CAkey ca.key  -out server.crt -days 1000 -sha256 -extfile opnessl.conf`

Where the file `opnessl.conf` contains following,

`subjectAltName = DNS:localhost`

#### Running grpc server with certificates

`go run main.go -s=true -certPath=server.crt -keyPath=server.key`

#### Running flagd with certificates

`go run main.go start --sources='[{"uri":"grpcs://localhost:9090","provider":"grpc", "certPath":"ca.cert"}]'`