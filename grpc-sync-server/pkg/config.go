package Core

import (
	"flag"
	"fmt"
)

const hostDefault = "localhost"
const portDefault = "9090"

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
	Host     string
	Port     string
	Secure   bool
	Files    arrayFlags
	CertPath string
	KeyPath  string
}

func LoadConfig() Config {
	cfg := Config{}

	flag.StringVar(&cfg.Host, "h", hostDefault, "hostDefault of the server")
	flag.StringVar(&cfg.Port, "p", portDefault, "portDefault of the server")
	flag.Var(&cfg.Files, "f", "file to watch")
	flag.BoolVar(&cfg.Secure, "s", false, "enable tls")
	flag.StringVar(&cfg.CertPath, "certPath", "", "certificate path for tls connection")
	flag.StringVar(&cfg.KeyPath, "keyPath", "", "certificate key for tls connection")
	flag.Parse()

	return cfg
}
