package main

import (
	sync "github.com/open-feature/test-harness/sync/pkg"
)

func main() {
	server := sync.Server{
		Config: sync.LoadConfig(),
	}

	server.Start()
}
