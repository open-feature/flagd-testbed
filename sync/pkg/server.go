package sync

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"os"
	"time"

	"github.com/fsnotify/fsnotify"
	"golang.org/x/exp/maps"

	"buf.build/gen/go/open-feature/flagd/grpc/go/sync/v1/syncv1grpc"
	v1 "buf.build/gen/go/open-feature/flagd/protocolbuffers/go/sync/v1"
	"go.opentelemetry.io/contrib/instrumentation/google.golang.org/grpc/otelgrpc"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
)

type Server struct {
	Config Config
}

func (s *Server) Start() {
	err := SetupTraceProvider()
	if err != nil {
		log.Printf("Error setting up telemetry : %s\n", err.Error())
		return
	}

	listen, err := net.Listen("tcp", s.Config.Host+":"+s.Config.Port)
	if err != nil {
		log.Printf("Error when listening to address : %s\n", err.Error())
		return
	}

	options, err := s.buildOptions()
	if err != nil {
		log.Printf("Error building gRPC options : %s\n", err.Error())
		return
	}

	options = append(options, grpc.StreamInterceptor(otelgrpc.StreamServerInterceptor()))

	server := grpc.NewServer(options...)
	sync, err := NewSyncImpl(s.Config.Files.Array)
	syncv1grpc.RegisterFlagSyncServiceServer(server, &sync)

	fmt.Printf("Server listening : %s\n", s.Config.Host+":"+s.Config.Port)
	err = server.Serve(listen)
	if err != nil {
		log.Printf("Error when starting the server : %s\n", err.Error())
		return
	}
}

func (s *Server) buildOptions() ([]grpc.ServerOption, error) {
	var options []grpc.ServerOption

	if !s.Config.Secure {
		return options, nil
	}

	keyPair, err := tls.LoadX509KeyPair(s.Config.CertPath, s.Config.KeyPath)
	if err != nil {
		return nil, err
	}

	options = append(options, grpc.Creds(credentials.NewServerTLSFromCert(&keyPair)))
	return options, nil
}

// SyncImpl implements the flagd Sync contract
type SyncImpl struct {
	filePaths []string
	watcher   *fsnotify.Watcher
}

func NewSyncImpl(filePaths []string) (SyncImpl, error) {
	watcher, err := fsnotify.NewWatcher()
	for _, filePath := range filePaths {

		if err != nil {
			return SyncImpl{}, err
		}
		watcher.Add(filePath)
	}
	return SyncImpl{
		filePaths,
		watcher,
	}, nil
}

func (s *SyncImpl) SyncFlags(req *v1.SyncFlagsRequest, stream syncv1grpc.FlagSyncService_SyncFlagsServer) error {
	log.Printf("Requesting flags for provider : %s", req.ProviderId)

	marshalled, err := s.readFlags()
	if err != nil {
		log.Println("error reading flags:", err)
	}
	err = stream.Send(&v1.SyncFlagsResponse{
		FlagConfiguration: string(marshalled),
		State:             v1.SyncState_SYNC_STATE_ALL,
	})
	if err != nil {
		log.Println("error sending initial stream:", err)
	}

	// Start listening for events.
	for {
		select {
		case event, ok := <-s.watcher.Events:
			if !ok {
				log.Println("unable to process file event")
			}
			if event.Has(fsnotify.Write) {
				marshalled, err := s.readFlags()
				if err != nil {
					log.Println("error reading flags:", err)
				}
				err = stream.Send(&v1.SyncFlagsResponse{
					FlagConfiguration: string(marshalled),
					State:             v1.SyncState_SYNC_STATE_ALL,
				})
				if err != nil {
					log.Println("error sending stream:", err)
				}
			}
		case err, _ := <-s.watcher.Errors:
			log.Println("error in file watcher:", err)
		}
	}
}

func (s *SyncImpl) readFlags() ([]byte, error) {
	flags := make(map[string]any)
	evaluators := make(map[string]any)

	for _, path := range s.filePaths {
		bytes, err := os.ReadFile(path)
		for len(bytes) == 0 {
			// this is a fitly hack
			// file writes are NOT atomic and often when they are occur they have transitional empty states
			// this "re-reads" the file in these cases a bit later
			time.Sleep(10 * time.Millisecond)
			bytes, err = os.ReadFile(path)
		}
		if err != nil {
			return nil, err
		}
		parsed := make(map[string]map[string]any)
		json.Unmarshal(bytes, &parsed)
		maps.Copy(flags, parsed["flags"])
		maps.Copy(evaluators, parsed["$evaluators"])
	}

	payload := make(map[string]any)
	payload["flags"] = flags
	payload["$evaluators"] = evaluators
	marshalled, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}
	return marshalled, nil
}

func (s *SyncImpl) FetchAllFlags(context.Context, *v1.FetchAllFlagsRequest) (*v1.FetchAllFlagsResponse, error) {
	marshalled, err := s.readFlags()
	if err != nil {
		log.Println("error reading flags:", err)
	}
	return &v1.FetchAllFlagsResponse{
		FlagConfiguration: string(marshalled),
	}, nil
}
