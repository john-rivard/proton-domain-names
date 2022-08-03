#!/bin/bash
set -e
set -o nounset

# Values from Azure portal
SUB="$1"    # azure subscription name or id
RG="$2"     # azure resource group name
ZONE="$3"   # azure dns zone name

# Values from proton mail domain name settings
VERIFY="protonmail-verification=*****"
SPF="v=spf1 include:_spf.protonmail.ch mx ~all"
MX10="mail.protonmail.ch"
MX20="mailsec.protonmail.ch"
DKIM1="protonmail.domainkey.1111.domains.proton.ch."
DKIM2="protonmai2.domainkey.2222.domains.proton.ch."
DKIM3="protonmai3.domainkey.3333.domains.proton.ch."
DMARC="v=DMARC1; p=none"

# Set current subscription
az account set --subscription $SUB >/dev/null

# Verify
[ ! -z ${VERIFY+x} ] && az network dns record-set txt add-record --resource-group $RG --zone-name $ZONE --record-set-name "@" --value $VERIFY >/dev/null

# MX
[ ! -z ${MX10+x} ]   && az network dns record-set mx add-record --resource-group $RG --zone-name $ZONE --record-set-name "@" --exchange $MX10 --preference 10 >/dev/null
[ ! -z ${MX20+x} ]   && az network dns record-set mx add-record --resource-group $RG --zone-name $ZONE --record-set-name "@" --exchange $MX20 --preference 20 >/dev/null

# SPF
[ ! -z ${SPF+x} ]    && az network dns record-set txt add-record --resource-group $RG --zone-name $ZONE --record-set-name "@" --value $SPF >/dev/null

# DKIM
[ ! -z ${DKIM1+x} ]  && az network dns record-set cname set-record --resource-group $RG --zone-name $ZONE --record-set-name "protonmail._domainkey" --cname $DKIM1 >/dev/null
[ ! -z ${DKIM2+x} ]  && az network dns record-set cname set-record --resource-group $RG --zone-name $ZONE --record-set-name "protonmail2._domainkey" --cname $DKIM2 >/dev/null
[ ! -z ${DKIM3+x} ]  && az network dns record-set cname set-record --resource-group $RG --zone-name $ZONE --record-set-name "protonmail3._domainkey" --cname $DKIM3 >/dev/null

# DMARC
[ ! -z ${DMARC+x} ]  && az network dns record-set txt add-record --resource-group $RG --zone-name $ZONE --record-set-name "_dmarc" --value $DMARC >/dev/null

# Show All
echo "Verify/SPF"
az network dns record-set txt   show --resource-group $RG --zone-name $ZONE --name "@" -o jsonc --query "{id:id,txtRecords:txtRecords}"
echo "MX"
az network dns record-set mx    show --resource-group $RG --zone-name $ZONE --name "@" -o jsonc --query "{id:id,mxRecords:mxRecords}"
echo "DKIM"
az network dns record-set cname show --resource-group $RG --zone-name $ZONE --name "protonmail._domainkey" -o jsonc --query "{id:id,cnameRecord:cnameRecord}"
az network dns record-set cname show --resource-group $RG --zone-name $ZONE --name "protonmail2._domainkey" -o jsonc --query "{id:id,cnameRecord:cnameRecord}"
az network dns record-set cname show --resource-group $RG --zone-name $ZONE --name "protonmail3._domainkey" -o jsonc --query "{id:id,cnameRecord:cnameRecord}"
echo "DMARK"
az network dns record-set txt show --resource-group $RG --zone-name $ZONE --name "_dmarc" -o jsonc --query "{id:id,txtRecords:txtRecords}"

