package config

import (
	"testing"

	"github.com/google/go-cmp/cmp"
)

func TestJoinConfiguration(t *testing.T) {
	tests := []struct {
		name       string
		options    []Option
		wantConfig string
		wantErr    bool
	}{
		{
			name:       "no opts",
			options:    nil,
			wantConfig: "",
			wantErr:    true,
		},
		{
			name: "mandatory opts",
			options: []Option{
				WithAPIServerEndpoint("10.0.0.20:6443"),
				WithToken("token"),
				WithCACertHash("sha256:hash"),
			},
			wantConfig: `apiVersion: kubeadm.k8s.io/v1beta4
kind: JoinConfiguration
caCertPath: /etc/kubernetes/pki/ca.crt
discovery:
  bootstrapToken:
    apiServerEndpoint: "10.0.0.20:6443"
    token: "token"
    caCertHashes:
    - "sha256:hash"
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
  kubeletExtraArgs:
  - name: container-runtime-endpoint
    value: unix:///run/containerd/containerd.sock
`,
			wantErr: false,
		},
		{
			name: "label",
			options: []Option{
				WithAPIServerEndpoint("10.0.0.20:6443"),
				WithToken("token"),
				WithCACertHash("sha256:hash"),
				WithLabel("node.mmontes.io/type", "compute"),
			},
			wantConfig: `apiVersion: kubeadm.k8s.io/v1beta4
kind: JoinConfiguration
caCertPath: /etc/kubernetes/pki/ca.crt
discovery:
  bootstrapToken:
    apiServerEndpoint: "10.0.0.20:6443"
    token: "token"
    caCertHashes:
    - "sha256:hash"
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
  kubeletExtraArgs:
  - name: container-runtime-endpoint
    value: unix:///run/containerd/containerd.sock
  - name: node-labels
    value: "node.mmontes.io/type=compute"
`,
			wantErr: false,
		},
		{
			name: "taint",
			options: []Option{
				WithAPIServerEndpoint("10.0.0.20:6443"),
				WithToken("token"),
				WithCACertHash("sha256:hash"),
				WithTaint("node.mmontes.io/storage"),
			},
			wantConfig: `apiVersion: kubeadm.k8s.io/v1beta4
kind: JoinConfiguration
caCertPath: /etc/kubernetes/pki/ca.crt
discovery:
  bootstrapToken:
    apiServerEndpoint: "10.0.0.20:6443"
    token: "token"
    caCertHashes:
    - "sha256:hash"
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
  kubeletExtraArgs:
  - name: container-runtime-endpoint
    value: unix:///run/containerd/containerd.sock
  taints:
  - key: "node.mmontes.io/storage"
    effect: "NoSchedule"
`,
			wantErr: false,
		},
		{
			name: "label and taint",
			options: []Option{
				WithAPIServerEndpoint("10.0.0.20:6443"),
				WithToken("token"),
				WithCACertHash("sha256:hash"),
				WithLabel("node.mmontes.io/type", "storage"),
				WithTaint("node.mmontes.io/storage"),
			},
			wantConfig: `apiVersion: kubeadm.k8s.io/v1beta4
kind: JoinConfiguration
caCertPath: /etc/kubernetes/pki/ca.crt
discovery:
  bootstrapToken:
    apiServerEndpoint: "10.0.0.20:6443"
    token: "token"
    caCertHashes:
    - "sha256:hash"
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
  kubeletExtraArgs:
  - name: container-runtime-endpoint
    value: unix:///run/containerd/containerd.sock
  - name: node-labels
    value: "node.mmontes.io/type=storage"
  taints:
  - key: "node.mmontes.io/storage"
    effect: "NoSchedule"
`,
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			config, err := NewJoinConfig(tt.options...)
			if diff := cmp.Diff(tt.wantConfig, config); diff != "" {
				t.Errorf("unexpected join configuration (want, got):\n%s", diff)
			}
			if tt.wantErr && err == nil {
				t.Error("expect error to have occurred, got nil")
			}
			if !tt.wantErr && err != nil {
				t.Errorf("expect error to not have occurred, got: %v", err)
			}
		})
	}
}
