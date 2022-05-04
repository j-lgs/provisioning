package talos

import (
	"context"
	"encoding/base64"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"

	"github.com/hashicorp/terraform-plugin-log/tflog"
	"github.com/hashicorp/terraform-plugin-sdk/v2/diag"
	"github.com/hashicorp/terraform-plugin-sdk/v2/helper/schema"
)

func resourceClusterConfiguration() *schema.Resource {
	return &schema.Resource{
		CreateContext: resourceClusterCreate,
		ReadContext:   resourceClusterRead,
		UpdateContext: resourceClusterUpdate,
		DeleteContext: resourceClusterDelete,
		Schema: map[string]*schema.Schema{
			"cluster_name": {
				Type:     schema.TypeString,
				Required: true,
			},
			"registry_ip": {
				Type:     schema.TypeString,
				Optional: true,
			},
			"gateway_ip": {
				Type:     schema.TypeString,
				Optional: true,
			},
			"gateway": {
				Type:     schema.TypeString,
				Required: true,
			},
			"nameserver": {
				Type:     schema.TypeString,
				Required: true,
			},
			"apiproxy_ip": {
				Type:     schema.TypeString,
				Optional: true,
			},
			"kubernetes_endpoint": {
				Type:     schema.TypeString,
				Optional: true,
			},
			"talos_image": {
				Type:     schema.TypeString,
				Optional: true,
				Default:  "ghcr.io/siderolabs/installer:v1.0.2",
			},
			"kubernetes_version": {
				Type:     schema.TypeString,
				Optional: true,
				Default:  "1.23.6",
			},
			"worker_yaml": {
				Type:     schema.TypeString,
				Computed: true,
			},
			"control_yaml": {
				Type:     schema.TypeString,
				Computed: true,
			},
			"talosconfig": {
				Type:     schema.TypeString,
				Computed: true,
			},
			"pem": {
				Type: schema.TypeString,
				//Sensitive: true,
				Computed: true,
			},
		},
	}
}

func resourceClusterCreate(ctx context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
	// Exec talos program to create the initial ca_crts, and base worker/controlplane configurations
	clusterName := d.Get("cluster_name").(string)
	endpoint := d.Get("kubernetes_endpoint").(string)
	disk := "/dev/vda"
	image := d.Get("talos_image").(string)
	kversion := d.Get("kubernetes_version").(string)

	// Ensure output path exists
	talosOutput, err := os.MkdirTemp("", "talos_provider")
	if err != nil {
		tflog.Error(ctx, "Talos temp dir generation error")
		tflog.Error(ctx, err.Error())
		diag.Errorf("Error creating talos configuration temp directory: %s\n", err)
		return nil
	}
	defer os.RemoveAll(talosOutput)

	out, err := exec.CommandContext(
		ctx, "talosctl", "gen", "config", clusterName, endpoint, "--with-docs=false",
		"--with-examples=false", "-o", talosOutput, "--install-disk="+disk, "--install-image="+image,
		"--with-cluster-discovery=false", "--kubernetes-version="+kversion).CombinedOutput()
	if err != nil {
		tflog.Error(ctx, "Talos configuration generation output error")
		tflog.Error(ctx, string(out))
		tflog.Error(ctx, err.Error())
		diag.Errorf("Talos configuration generation output: %s\n", out)
		diag.Errorf("%s\n", err)
		return nil
	}

	controlYaml, err := os.ReadFile(filepath.Join(talosOutput, "controlplane.yaml"))
	if err != nil {
		diag.Errorf("Error reading generated controlplane: %s", err)
		tflog.Error(ctx, "Talos configuration generation output error")
		tflog.Error(ctx, string(out))
		tflog.Error(ctx, err.Error())
	}
	err = d.Set("control_yaml", string(controlYaml))
	if err != nil {
		tflog.Error(ctx, "Error setting controlplane yaml")
		tflog.Error(ctx, err.Error())
		return nil
	}

	workerYaml, err := os.ReadFile(filepath.Join(talosOutput, "worker.yaml"))
	if err != nil {
		tflog.Error(ctx, "Error reading generated worker")
		tflog.Error(ctx, string(out))
		tflog.Error(ctx, err.Error())
		diag.Errorf("Error reading generated worker: %s", err)
	}
	err = d.Set("worker_yaml", string(workerYaml))
	if err != nil {
		tflog.Error(ctx, "Error setting worker yaml")
		return nil
	}

	talosconfig, err := os.ReadFile(filepath.Join(talosOutput, "talosconfig"))
	if err != nil {
		tflog.Error(ctx, "Error reading generated talosconfig")
		tflog.Error(ctx, string(out))
		tflog.Error(ctx, err.Error())
		diag.Errorf("Error reading generated talosconfig: %s", err)
	}
	err = d.Set("talosconfig", string(talosconfig))
	if err != nil {
		tflog.Error(ctx, "Error setting talosconfig")
		return nil
	}

	config := string(talosconfig)
	ca := regexp.MustCompile(`ca:\s(?P<ca>[\w=]+)`)
	crt := regexp.MustCompile(`crt:\s(?P<crt>[\w=]+)`)
	key := regexp.MustCompile(`key:\s(?P<key>[\w=]+)`)

	caMatches := ca.FindStringSubmatch(config)
	crtMatches := crt.FindStringSubmatch(config)
	keyMatches := key.FindStringSubmatch(config)

	pemCa, err := base64.StdEncoding.DecodeString(caMatches[ca.SubexpIndex("ca")])
	if err != nil {
		tflog.Error(ctx, "Error decoding base64 pem ca")
		return nil
	}
	pemCrt, err := base64.StdEncoding.DecodeString(crtMatches[crt.SubexpIndex("crt")])
	if err != nil {
		tflog.Error(ctx, "Error decoding base64 pem crt")
		return nil
	}
	pemKey, err := base64.StdEncoding.DecodeString(keyMatches[key.SubexpIndex("key")])
	if err != nil {
		tflog.Error(ctx, "Error decoding base64 pem key")
		return nil
	}

	pem := string(pemCa) + string(pemCrt) + string(pemKey)
	d.Set("pem", pem)

	// the cluster has the pem saved so it can be used to dial into the talos GRPC endpoint.

	d.SetId(d.Get("cluster_name").(string))

	return nil
}

func resourceClusterRead(ctx context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
	return nil
}

func resourceClusterUpdate(ctx context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
	return nil
}

func resourceClusterDelete(ctx context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
	return nil
}
