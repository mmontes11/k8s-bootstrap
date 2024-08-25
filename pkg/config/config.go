package config

import (
	"bytes"
	"errors"
	"fmt"
	"text/template"
)

type Option func(*Options)

func WithAPIServerEndpoint(apiServerEndpoint string) Option {
	return func(o *Options) {
		o.APIServerEndpoint = apiServerEndpoint
	}
}

func WithToken(token string) Option {
	return func(o *Options) {
		o.Token = token
	}
}

func WithCACertHash(caCertHash string) Option {
	return func(o *Options) {
		o.CACertHash = caCertHash
	}
}

func WithLabel(labelKey, labelValue string) Option {
	return func(o *Options) {
		o.LabelKey = labelKey
		o.LabelValue = labelValue
	}
}

func WithTaint(taint string) Option {
	return func(o *Options) {
		o.Taint = taint
	}
}

type Options struct {
	APIServerEndpoint string
	Token             string
	CACertHash        string
	LabelKey          string
	LabelValue        string
	Taint             string
}

func NewJoinConfig(joinOpts ...Option) (string, error) {
	opts := Options{}
	for _, setOpt := range joinOpts {
		setOpt(&opts)
	}
	if opts.APIServerEndpoint == "" || opts.Token == "" || opts.CACertHash == "" {
		return "", errors.New("APIServerEndpoint, Token and CACertHash are mandatory")
	}

	tpl := createTpl("join-config", `apiVersion: kubeadm.k8s.io/v1beta4
kind: JoinConfiguration
caCertPath: /etc/kubernetes/pki/ca.crt
discovery:
  bootstrapToken:
    apiServerEndpoint: "{{ .APIServerEndpoint }}"
    token: "{{ .Token }}"
    caCertHashes:
    - "{{ .CACertHash }}"
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
  kubeletExtraArgs:
  - name: container-runtime-endpoint
    value: unix:///run/containerd/containerd.sock
    {{- if and .LabelKey .LabelValue }}
  - name: node-labels
    value: "{{ .LabelKey }}={{ .LabelValue }}"
    {{- end }}
    {{- if .Taint }}
  taints:
  - key: "{{ .Taint }}"
    effect: "NoSchedule"
    {{- end }}
`)

	buf := new(bytes.Buffer)
	if err := tpl.Execute(buf, opts); err != nil {
		return "", fmt.Errorf("error rendering join configuration: %v", err)
	}
	return buf.String(), nil
}

func createTpl(name, t string) *template.Template {
	return template.Must(template.New(name).Parse(t))
}
