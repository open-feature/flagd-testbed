package sync

import (
	"flag"
	"fmt"
	"os"
)

const hostDefault = "0.0.0.0"
const portDefault = "9090"
const cmdDefault = "start"

// arrayFlags is a custom flag implementation
type arrayFlags struct {
	Array []string
}

func (i *arrayFlags) String() string {
	return fmt.Sprint(i.Array)
}

func (i *arrayFlags) Set(value string) error {
	i.Array = append(i.Array, value)
	return nil
}

type Config struct {
	Command  string
	Host     string
	Port     string
	Secure   bool
	Files    arrayFlags
	CertPath string
	KeyPath  string
}

func LoadConfig() Config {
	cfg := Config{}

	start := flag.NewFlagSet("start", flag.ExitOnError)
	start.StringVar(&cfg.Host, "h", hostDefault, "hostDefault of the server")
	start.StringVar(&cfg.Port, "p", portDefault, "portDefault of the server")
	start.Var(&cfg.Files, "f", "file to watch")
	start.BoolVar(&cfg.Secure, "s", false, "enable tls")
	start.StringVar(&cfg.CertPath, "certPath", "", "certificate path for tls connection")
	start.StringVar(&cfg.KeyPath, "keyPath", "", "certificate key for tls connection")
	start.Parse(os.Args[2:])

	return cfg
}
