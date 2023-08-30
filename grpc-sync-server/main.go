package main

import (
	"server/pkg"
)

func main() {
	server := Core.Server{
		Config: Core.LoadConfig(),
	}

	server.Start()
}
