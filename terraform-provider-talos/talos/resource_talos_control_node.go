package talos

import (
	"context"
	"strings"
	"text/template"

	"github.com/hashicorp/terraform-plugin-log/tflog"
	"github.com/hashicorp/terraform-plugin-sdk/v2/diag"
	"github.com/hashicorp/terraform-plugin-sdk/v2/helper/schema"
)

func resourceControlNode() *schema.Resource {
	return &schema.Resource{
		CreateContext: resourceControlNodeCreate,
		ReadContext:   resourceControlNodeRead,
		UpdateContext: resourceControlNodeUpdate,
		DeleteContext: resourceControlNodeDelete,
		Schema: map[string]*schema.Schema{
			"name": {
				Type:     schema.TypeString,
				Required: true,
			},
			"macaddr": {
				Type:     schema.TypeString,
				Required: true,
			},
			"ip": {
				Type:     schema.TypeString,
				Required: true,
			},
			"gateway": {
				Type:     schema.TypeString,
				Required: true,
			},
			"tmpl": {
				Type:     schema.TypeString,
				Computed: true,
			},
			"nameservers": {
				Type:     schema.TypeList,
				Required: true,
				MinItems: 1,
				Elem: &schema.Schema{
					Type: schema.TypeString,
				},
			},
			"pem": {
				Type:     schema.TypeString,
				Required: true,
			},
			"control_yaml": {
				Type:     schema.TypeString,
				Required: true,
			},
		},
	}
}

type ControlNodeSpec struct {
	Name string

	IP          string
	Hostname    string
	Gateway     string
	Nameservers []string
	Peers       []string

	WgIP         string
	WgAllowedIPs string
	WgEndpoint   string
	WgPublicKey  string
	WgPrivateKey string

	IngressPort    uint
	IngressSSLPort uint
	IngressIP      string

	RouterID string
	VRID     string
	State    string
	Priority string
	VIPPass  string

	APIProxyIP        string
	APIProxyPort      uint
	LocalAPIProxyPort uint

	RegistryIP string

	KeepalivedImage string
	HaproxyImage    string
}

func resourceControlNodeCreate(ctx context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
	// generate wireguard keypair

	// template keepalived
	// tempalte haproxy
	// template keepalived check

	// template controlplane patches
	tmpl, err := template.New("controlPlane").Parse(templateControl())
	if err != nil {
		tflog.Error(ctx, "Error creating controlplane patch template.")
		tflog.Error(ctx, err.Error())
		return nil
	}

	nameservers := []string{}
	for _, ns := range d.Get("nameservers").([]interface{}) {
		nameservers = append(nameservers, ns.(string))
	}

	buffer := new(strings.Builder)
	err = tmpl.Execute(buffer, ControlNodeSpec{
		Name: d.Get("name").(string),
		IP:   d.Get("ip").(string),

		Hostname:    d.Get("name").(string),
		Gateway:     d.Get("gateway").(string),
		Nameservers: nameservers,
		Peers:       []string{},

		WgIP:         "",
		WgAllowedIPs: "",
		WgEndpoint:   "",
		WgPublicKey:  "",
		WgPrivateKey: "",

		IngressPort:    0,
		IngressSSLPort: 0,
		IngressIP:      "",

		RouterID: "",
		VRID:     "",
		State:    "",
		Priority: "",
		VIPPass:  "",

		APIProxyIP:        "",
		APIProxyPort:      0,
		LocalAPIProxyPort: 0,

		RegistryIP: "",

		KeepalivedImage: "osixia/keepalived:1.3.5-1",
		HaproxyImage:    "haproxy:2.4.14",
	})

	tflog.Error(ctx, buffer.String())

	d.Set("tmpl", buffer.String())

	// apply controlplane base configuration
	// apply controlplane patches
	d.SetId(d.Get("name").(string))
	return nil
}

func resourceControlNodeRead(ctx context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
	return nil
}

func resourceControlNodeUpdate(ctx context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
	// template keepalived
	// tempalte haproxy
	// template keepalived check

	// template controlplane patches

	// apply controlplane patches
	return nil
}

func resourceControlNodeDelete(ctx context.Context, d *schema.ResourceData, m interface{}) diag.Diagnostics {
	return nil
}
