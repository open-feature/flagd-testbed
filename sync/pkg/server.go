package sync

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net"
	"os"
	"time"

	"github.com/fsnotify/fsnotify"
	"golang.org/x/exp/maps"

	"buf.build/gen/go/open-feature/flagd/grpc/go/sync/v1/syncv1grpc"
	v1 "buf.build/gen/go/open-feature/flagd/protocolbuffers/go/sync/v1"
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
	filePaths []string
	watcher   *fsnotify.Watcher
}

func NewSyncImpl(filePaths []string) (SyncImpl, error) {
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		return SyncImpl{}, err
	}

	for _, filePath := range filePaths {
		err := watcher.Add(filePath)
		if err != nil {
			log.Printf("Error watching file %s, caused by %s\n", filePath, err.Error())
			return SyncImpl{}, err
		}
	}
	return SyncImpl{
		filePaths,
		watcher,
	}, nil
}

func (s *SyncImpl) SyncFlags(req *v1.SyncFlagsRequest, stream syncv1grpc.FlagSyncService_SyncFlagsServer) error {
	log.Printf("Requesting flags for provider: %s\n", req.ProviderId)

	// initial read
	marshalled, err := readFlags(s.filePaths)
	if err != nil {
		log.Printf("Error reading flag data: %v\n", err)
		return err
	}
	err = stream.Send(&v1.SyncFlagsResponse{
		FlagConfiguration: string(marshalled),
		State:             v1.SyncState_SYNC_STATE_ALL,
	})
	if err != nil {
		log.Printf("Error sending initial stream: %v\n", err)
		return err
	}

	// Start listening for events.
	for {
		select {
		case event, ok := <-s.watcher.Events:
			if !ok {
				message := "unable to process file event"
				log.Println(message)
				return errors.New(message)
			}
			if event.Has(fsnotify.Write) {
				marshalled, err := readFlags(s.filePaths)
				if err != nil {
					log.Println("error reading flags:", err)
				}
				err = stream.Send(&v1.SyncFlagsResponse{
					FlagConfiguration: string(marshalled),
					State:             v1.SyncState_SYNC_STATE_ALL,
				})
				if err != nil {
					// this is probably a close
					message := fmt.Sprintf("error sending stream, likely closed: %v", err)
					log.Println(message)
					return nil
				}
			}
		case err, _ := <-s.watcher.Errors:
			log.Println("Error in file watcher:", err)
			return err
		case <-stream.Context().Done():
			log.Printf("Stream completed for provider: %s\n", req.ProviderId)
			return nil
		}
	}
}

func (s *SyncImpl) FetchAllFlags(context.Context, *v1.FetchAllFlagsRequest) (*v1.FetchAllFlagsResponse, error) {
	marshalled, err := readFlags(s.filePaths)
	if err != nil {
		log.Printf("Error reading flags: %s\n", err.Error())
		return nil, err
	}
	
	return &v1.FetchAllFlagsResponse{
		FlagConfiguration: string(marshalled),
	}, nil
}

// readFlags is a helper to read given files and combine flags in them
func readFlags(filePaths []string) ([]byte, error) {
	flags := make(map[string]any)
	evaluators := make(map[string]any)

	for _, path := range filePaths {
		bytes, err := os.ReadFile(path)
		if err != nil {
			log.Printf("File read error %s\n", err.Error())
			return nil, err
		}

		for len(bytes) == 0 {
			// this is a fitly hack
			// file writes are NOT atomic and often when they are occur they have transitional empty states
			// this "re-reads" the file in these cases a bit later
			log.Printf("File content not ready for %s, busy wait\n", path)
			time.Sleep(5 * time.Millisecond)
			bytes, err = os.ReadFile(path)
			if err != nil {
				log.Printf("File read error %s\n", err.Error())
				return nil, err
			}
		}
		parsed := make(map[string]map[string]any)
		err = json.Unmarshal(bytes, &parsed)
		if err != nil {
			log.Printf("JSON unmarshal error %s\n", err.Error())
			return nil, err
		}
		maps.Copy(flags, parsed["flags"])
		maps.Copy(evaluators, parsed["$evaluators"])
	}

	payload := make(map[string]any)
	payload["flags"] = flags
	payload["$evaluators"] = evaluators
	marshalled, err := json.Marshal(payload)
	if err != nil {
		log.Printf("JSON marshal error %s\n", err.Error())
		return nil, err
	}
	return marshalled, nil
}
