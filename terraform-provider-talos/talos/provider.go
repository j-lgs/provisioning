package talos

import (
	"context"

	"github.com/hashicorp/terraform-plugin-sdk/v2/diag"
	"github.com/hashicorp/terraform-plugin-sdk/v2/helper/schema"
)

func Provider() *schema.Provider {
	return &schema.Provider{
		Schema: map[string]*schema.Schema{
			"talos_environment": {
				Type:        schema.TypeString,
				Required:    true,
				DefaultFunc: schema.EnvDefaultFunc("TALOS_ENVIRONMENT", nil),
			},
			"talos_node_dhcp_cidr": {
				Type:        schema.TypeString,
				Required:    true,
				DefaultFunc: schema.EnvDefaultFunc("TALOS_NODE_DHCP_CIDR", nil),
			},
		},
		ResourcesMap: map[string]*schema.Resource{
			"talos_configuration": resourceClusterConfiguration(),
		},
		DataSourcesMap:       map[string]*schema.Resource{},
		ConfigureContextFunc: providerConfigure,
	}
}

type providerSpec struct {
	environment string
	dhcp_cidr   string
}

func providerConfigure(ctx context.Context, d *schema.ResourceData) (interface{}, diag.Diagnostics) {
	environment := d.Get("talos_environment").(string)
	dhcp_cidr := d.Get("talos_node_dhcp_cidr").(string)

	return providerSpec{
		environment: environment,
		dhcp_cidr:   dhcp_cidr,
	}, nil
}
