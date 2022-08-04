# proton-domain-names

Configure an Azure-hosted domain name for use with Proton Mail. 

Get the Azure subscription, resource group name, and DNS Zone name from the [Azure Portal](https://portal.azure.com).

Copy the DNS settings directly from the [Proton Mail Domain Name setting](https://account.proton.me/u/2/mail/domain-names).

Requires the `az` command and `az login`. See the install instructions for [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-linux).

The command will always display the current settings. Optionally, use one of the "set" options to modify a setting.

See [command help](./HELP.md).