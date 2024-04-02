package sync

import (
	"context"
	"crypto/tls"
	"fmt"
	"log"
	"net"
	"sync"

	"buf.build/gen/go/open-feature/flagd/grpc/go/flagd/sync/v1/syncv1grpc"
	v1 "buf.build/gen/go/open-feature/flagd/protocolbuffers/go/flagd/sync/v1"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
)

type Server struct {
	Config Config
}

func (s *Server) Start() {
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

	server := grpc.NewServer(options...)
	sync, err := NewSyncImpl(s.Config.Files.Array)
	if err != nil {
		log.Printf("Error configuring the server : %s\n", err.Error())
		return
	}

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
	fw *fileWatcher
}

func NewSyncImpl(filePaths []string) (SyncImpl, error) {
	fw := &fileWatcher{
		paths: filePaths,
		subs:  make(map[interface{}]chan<- []byte),
		mu:    sync.Mutex{},
	}

	err := fw.init()
	if err != nil {
		log.Printf("Error starting file watcher %s\n", err.Error())
		return SyncImpl{}, err
	}

	return SyncImpl{
		fw,
	}, nil
}

func (s *SyncImpl) SyncFlags(req *v1.SyncFlagsRequest, stream syncv1grpc.FlagSyncService_SyncFlagsServer) error {
	log.Printf("Requesting flags for provider: %s\n", req.ProviderId)

	// initial read
	err := stream.Send(&v1.SyncFlagsResponse{
		FlagConfiguration: string(s.fw.getCurrentData()),
	})
	if err != nil {
		log.Printf("Error sending initial stream: %v\n", err)
		return err
	}

	listener := make(chan []byte)
	s.fw.subscribe(listener)

	// Start listening for events.
	for {
		select {
		case data := <-listener:
			err = stream.Send(&v1.SyncFlagsResponse{
				FlagConfiguration: string(data),
			})
			if err != nil {
				// this is probably a close
				message := fmt.Sprintf("error sending stream, likely closed: %v", err)
				log.Println(message)
				return nil
			}
		case <-stream.Context().Done():
			s.fw.unSubscribe(listener)
			log.Printf("Stream completed for provider: %s\n", req.ProviderId)
			return nil
		}
	}
}

func (s *SyncImpl) FetchAllFlags(context.Context, *v1.FetchAllFlagsRequest) (*v1.FetchAllFlagsResponse, error) {
	marshalled := s.fw.getCurrentData()

	return &v1.FetchAllFlagsResponse{
		FlagConfiguration: string(marshalled),
	}, nil
}

func (s *SyncImpl) GetMetadata(context.Context, *v1.GetMetadataRequest) (*v1.GetMetadataResponse, error) {
	return &v1.GetMetadataResponse{}, nil
}
