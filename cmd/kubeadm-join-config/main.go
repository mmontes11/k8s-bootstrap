package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/mmontes11/k8s-bootstrap/pkg/config"
)

var (
	configPath        string
	apiServerEndpoint string
	token             string
	caCertHash        string
	labelKey          string
	labelValue        string
	taint             string
)

func main() {
	flag.StringVar(&configPath, "config-path", "",
		"Path where the join configuration will be written. For example: config/kubeadm-join.yaml."+
			"If not provided, stdout if used.")
	flag.StringVar(&apiServerEndpoint, "api-server-endpoint", "",
		"API server endpoint used to bootstrap the Node. For example: 10.0.0.20:6443.")
	flag.StringVar(&token, "token", "", "Token used to bootstrap the Node.")
	flag.StringVar(&caCertHash, "ca-cert-hash", "", "CA certificate hash used to bootstrap the Node.")
	flag.StringVar(&labelKey, "label-key", "", "Label key to be added to the Node.")
	flag.StringVar(&labelValue, "label-value", "", "Label value to be added to the Node.")
	flag.StringVar(&taint, "taint", "", "Taint to be added to the Node.")
	flag.Parse()

	if apiServerEndpoint == "" || token == "" || caCertHash == "" {
		fmt.Println("api-server-endpoint, token and ca-cert-hash flags are mandatory.")
		os.Exit(1)
	}

	opts := []config.Option{
		config.WithAPIServerEndpoint(apiServerEndpoint),
		config.WithToken(token),
		config.WithCACertHash(caCertHash),
	}
	if labelKey != "" && labelValue != "" {
		opts = append(opts, config.WithLabel(labelKey, labelValue))
	}
	if taint != "" {
		opts = append(opts, config.WithTaint(taint))
	}

	joinConfig, err := config.NewJoinConfig(opts...)
	if err != nil {
		fmt.Printf("Error getting join configuration: %v\n", err)
		os.Exit(1)
	}

	writer := os.Stdout
	if configPath != "" {
		fmt.Printf("Generating join configuration file: %v\n", configPath)
		file, err := os.Create(configPath)
		if err != nil {
			fmt.Printf("Error opening \"%s\" file: %v\n", configPath, err)
			os.Exit(1)
		}
		defer file.Close()

		writer = file
	}

	if _, err := writer.Write([]byte(joinConfig)); err != nil {
		fmt.Printf("Error writing join configuration: %v\n", err)
		os.Exit(1)
	}
}
