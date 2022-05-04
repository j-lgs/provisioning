package talos

import (
	"bytes"
	"context"
	"encoding/json"
	"strings"
	"text/template"

	"golang.zx2c4.com/wireguard/wgctrl/wgtypes"

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
			// Mandatory for minimal template generation
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
			"nameservers": {
				Type:     schema.TypeList,
				Required: true,
				MinItems: 1,
				Elem: &schema.Schema{
					Type: schema.TypeString,
				},
			},

			// Wireguard optionals TODO make into typeset
			"wg_ip": {
				Type:     schema.TypeString,
				Optional: true,
			},
			"wg_allowed_ips": {
				Type:     schema.TypeString,
				Optional: true,
			},
			"wg_endpoint": {
				Type:     schema.TypeString,
				Optional: true,
			},
			"wg_public_key": {
				Type:     schema.TypeString,
				Computed: true,
			},
			"wg_private_key": {
				Type:     schema.TypeString,
				Computed: true,
			},

			// Load balancing API proxy optionals
			"api_proxy_ip": {
				Type:     schema.TypeString,
				Optional: true,
			},

			// Container registry optionals
			"registry_ip": {
				Type:     schema.TypeString,
				Optional: true,
			},

			// From the cluster provider
			"pem": {
				Type:      schema.TypeString,
				Required:  true,
				Sensitive: true,
			},
			"control_yaml": {
				Type:      schema.TypeString,
				Required:  true,
				Sensitive: true,
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
	WgInterface  string
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
	nameservers := []string{}
	for _, ns := range d.Get("nameservers").([]interface{}) {
		nameservers = append(nameservers, ns.(string))
	}

	// generate wireguard keypair
	pubkey := ""
	privkey := ""
	wgip := d.Get("wg_ip").(string)
	if wgip != "" {
		pvk, err := wgtypes.GeneratePrivateKey()
		if err != nil {
			tflog.Error(ctx, "Error generating wireguard private key.")
			tflog.Error(ctx, err.Error())
			return nil
		}
		privkey = pvk.String()
		pubkey = pvk.PublicKey().String()
	}
	d.Set("wg_public_key", pubkey)
	d.Set("wg_private_key", privkey)

	var t *template.Template

	funcMap := template.FuncMap{
		"templateContent": func(name string, data interface{}) string {
			type ContentSpec struct {
				Content string `json:"content"`
			}

			buffer := &bytes.Buffer{}
			if err := t.ExecuteTemplate(buffer, name, data); err != nil {
				panic(err)
			}

			bytes, err := json.Marshal(ContentSpec{buffer.String()})
			if err != nil {
				panic(err)
			}

			return string(bytes)
		},
	}

	// template controlplane patches
	t = template.Must(template.New("controlPlane").Funcs(funcMap).Parse(templateControl()))
	t = template.Must(t.Parse(templateHaproxy()))
	t = template.Must(t.Parse(templateKeepalived()))
	t = template.Must(t.Parse(templateAPICheck()))

	buffer := new(strings.Builder)
	err := t.ExecuteTemplate(buffer, "controlPlane", ControlNodeSpec{
		Name: d.Get("name").(string),
		IP:   d.Get("ip").(string),

		Hostname:    d.Get("name").(string),
		Gateway:     d.Get("gateway").(string),
		Nameservers: nameservers,
		Peers:       []string{},

		WgIP:         wgip,
		WgInterface:  "wg0",
		WgAllowedIPs: "",
		WgEndpoint:   "",
		WgPublicKey:  pubkey,
		WgPrivateKey: privkey,

		IngressPort:    0,
		IngressSSLPort: 0,
		IngressIP:      "",

		RouterID: "",
		VRID:     "",
		State:    "",
		Priority: "",
		VIPPass:  "",

		APIProxyIP:        d.Get("api_proxy_ip").(string),
		APIProxyPort:      0,
		LocalAPIProxyPort: 0,

		RegistryIP: d.Get("registry_ip").(string),

		KeepalivedImage: "osixia/keepalived:1.3.5-1",
		HaproxyImage:    "haproxy:2.4.14",
	})
	if err != nil {
		tflog.Error(ctx, "Error running controlplane template.")
		tflog.Error(ctx, err.Error())
		return nil
	}

	tflog.Error(ctx, buffer.String())

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
