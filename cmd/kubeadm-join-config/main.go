package main

import (
	"flag"
	"fmt"
	"io/fs"
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
	flag.StringVar(&configPath, "config-path", "config/kubeadm-join.yaml",
		"Path where the join configuration will be created. For example: config/kubeadm-join.yaml.")
	flag.StringVar(&apiServerEndpoint, "api-server-endoint", "",
		"API server endpoint used to bootstrap the Node. For example: 10.0.0.20:6443.")
	flag.StringVar(&token, "token", "", "Token used to bootstrap the Node.")
	flag.StringVar(&caCertHash, "ca-cert-hash", "", "CA certificate hash used to bootstrap the Node.")
	flag.StringVar(&labelKey, "label-key", "", "Label key to be added to the Node.")
	flag.StringVar(&labelValue, "label-value", "", "Label value to be added to the Node.")
	flag.StringVar(&taint, "taint", "", "Taint to be added to the Node.")
	flag.Parse()

	if configPath == "" || apiServerEndpoint == "" || token == "" || caCertHash == "" {
		fmt.Println("config-path, api-server-endoint, token and ca-cert-hash flags are mandatory.")
		os.Exit(1)
	}

	opts := []config.Option{
		config.WithAPIServerEndpoint(apiServerEndpoint),
		config.WithToken(token),
		config.WithCACertHash(caCertHash),
	}
	if labelKey != "" && labelValue != "" {
		fmt.Printf("Adding Node label: %s=%s\n", labelKey, labelValue)
		opts = append(opts, config.WithLabel(labelKey, labelValue))
	}
	if taint != "" {
		fmt.Printf("Adding Node taint: %s\n", taint)
		opts = append(opts, config.WithTaint(taint))
	}

	joinConfig, err := config.NewJoinConfig(opts...)
	if err != nil {
		fmt.Printf("Error getting join configuration: %v\n", err)
		os.Exit(1)
	}

	if err := os.WriteFile(configPath, []byte(joinConfig), fs.FileMode(0777)); err != nil {
		fmt.Printf("Error wriing join configuration: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("Join configuration generated at: %v\n", configPath)
}
