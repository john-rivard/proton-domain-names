#!/bin/bash
# Copyright (c) 2022 John Rivard
# MIT-LICENSE
set -e
set -o nounset
#set -x # debug

# Values from Azure portal
declare SUB=""      # azure subscription name or id
declare RG=""       # azure resource group name
declare ZONE=""     # azure dns zone name

# Values from proton mail domain name settings
declare DKIM1=""
declare DKIM2=""
declare DKIM3=""
declare RESETTXT=""
declare SETDMARC=""
declare SETMX=""
declare SETSPF=""
declare VERIFY=""
declare SHOWHELP=""
declare -r DMARC="v=DMARC1; p=none"
declare -r MX10="mail.protonmail.ch"
declare -r MX20="mailsec.protonmail.ch"
declare -r SPF="v=spf1 include:_spf.protonmail.ch mx ~all"
declare -r DMARC_NAME="_dmarc"
declare -r DKIM1_NAME="protonmail._domainkey"
declare -r DKIM2_NAME="protonmail2._domainkey"
declare -r DKIM3_NAME="protonmail3._domainkey"
declare -r QUERY_TXT="{id:id,txtRecords:txtRecords}"
declare -r QUERY_CNAME="{id:id,cnameRecord:cnameRecord}"
declare -r QUERY_MX="{id:id,mxRecords:mxRecords}"

usage() {
    USAGE=$(cat <<EOF
Usage: $0 -s sub -g group -z dns-zone [options]
  --sub     | -s {subscription}     The Azure subscription name or id.
  --group   | -g {resource-group}   The Azure resource group name.
  --dns-zone | -z {dns-zone}        The Azure DNS Zone name.
  [--verify | -v {value}]           Set the domain verification TXT record; copy value from the Proton Mail settings.
  [--spf    | -f]                   Set the SPF TXT record to 'v=spf1 include:_spf.protonmail.ch mx ~all'.
  [--mx     | -m]                   Set the MX exchange records for 'mail.protonmail.ch' and 'mailsec.protonmail.ch'.
  [--dkim1  | -1 {value}]           Set the protonmail._domainkey CNAME record; copy value from the Proton Mail settings.
  [--dkim2  | -2 {value}]           Set the protonmail2._domainkey CNAME record; copy from the Proton Mail settings.
  [--dkim3  | -3 {value}]           Set the protonmail3._domainkey CNAME record; copy from the Proton Mail settings.
  [--dmarc  | -d]                   Set the _dmarc TXT record to 'v=DMARC1; p=none'.
  [--reset  | -r]                   Clear the verification and SPF TXT records.
  [--help   | -h]                   Show help message.
EOF
)
    echo "$USAGE"
}

bad_exit() {
    usage
    exit 1
}

# Uncomment for debugging
# az() {
#     echo "az $@"
# }

# Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    '--dkim1')      set -- "$@" '-1'    ;;
    '--dkim2')      set -- "$@" '-2'    ;;
    '--dkim3')      set -- "$@" '-3'    ;;
    '--dmarc')      set -- "$@" '-d'    ;;
    '--dns-name')   set -- "$@" '-z'    ;;
    '--help')       set -- "$@" '-h'    ;;
    '--group')      set -- "$@" '-g'    ;;
    '--reset')      set -- "$@" '-r'    ;;
    '--mx')         set -- "$@" '-m'    ;;
    '--spf')        set -- "$@" '-f'    ;;
    '--sub')        set -- "$@" '-s'    ;;
    '--verify')     set -- "$@" '-v'    ;;
    *)              set -- "$@" "$arg"  ;;
  esac
done

OPTIND=1
while getopts ":1:2:3:dfg:hmrs:v:z:" option; do
    case "${option}" in
        1)  DKIM1=${OPTARG} ;;
        2)  DKIM2=${OPTARG} ;;
        3)  DKIM3=${OPTARG} ;;
        d)  SETDMARC=1      ;;
        f)  SETSPF=1        ;;
        g)  RG=${OPTARG}    ;;
        h)  SHOWHELP=1      ;;
        m)  SETMX=1         ;;
        r)  RESETTXT=1      ;;
        s)  SUB=${OPTARG}   ;;
        v)  VERIFY=${OPTARG} ;;
        z)  ZONE=${OPTARG}  ;;
        :)  echo "Error: option -${OPTARG} requires an argument." 1>&2
            bad_exit        ;;
        *)  echo "Error: unknown option -${OPTARG}" 1>&2
            bad_exit        ;;
    esac
done

if [ ! -z ${SHOWHELP} ]; then
    usage
    exit 0
fi

if [ ! $(which az) ]; then
    echo "Error: az is not installed. See https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-linux" 1>&2
    exit 1
fi

if [ -z ${SUB} ]; then
    echo "Subscription name or id is required, --sub, -s"
    bad_exit
fi

if [ -z ${RG} ]; then
    echo "Resource group name is required, --group, -g"
    bad_exit
fi

if [ -z ${ZONE} ]; then
    echo "DNS zone name is required, --zone, -z"
    bad_exit
fi

# Set current subscription
echo "Setting Azure subscription to $SUB"
az account set --subscription $SUB -o jsonc

# Process Reset first
if [ ! -z ${RESETTXT} ]; then
    echo "Clearing verification and SPF TXT records"
    az network dns record-set txt delete --resource-group $RG --zone-name $ZONE --name "@" --yes
fi

# Set Verify
if [ ! -z ${VERIFY} ]; then
    echo "Setting verification TXT record to $VERIFY"
    az network dns record-set txt add-record --resource-group $RG --zone-name $ZONE --record-set-name "@" --value $VERIFY --query $QUERY_TXT
fi

# Set MX
if [ ! -z ${SETMX} ]; then
    echo "Setting MX exchange records to $MX10 and $MX20"
    az network dns record-set mx add-record --resource-group $RG --zone-name $ZONE --record-set-name "@" --exchange $MX10 --preference 10 --query $QUERY_MX
    az network dns record-set mx add-record --resource-group $RG --zone-name $ZONE --record-set-name "@" --exchange $MX20 --preference 20 --query $QUERY_MX
fi

# Set SPF
if [ ! -z ${SETSPF} ]; then
    echo "Setting SPF text record to $SPF"
    az network dns record-set txt add-record --resource-group $RG --zone-name $ZONE --record-set-name "@" --value $SPF --query $QUERY_TXT
fi

# Set DKIM
if [ ! -z ${DKIM1} ]; then
    echo "Setting $DKIM1_NAME CNAME to $DKIM1"
    az network dns record-set cname set-record --resource-group $RG --zone-name $ZONE --record-set-name $DKIM1_NAME --cname $DKIM1 --query $QUERY_CNAME
fi
if [ ! -z ${DKIM2} ]; then
    echo "Setting $DKIM2_NAME CNAME to $DKIM2"
    az network dns record-set cname set-record --resource-group $RG --zone-name $ZONE --record-set-name $DKIM2_NAME --cname $DKIM2  --query $QUERY_CNAME
fi
if [ ! -z ${DKIM3} ]; then
    echo "Setting $DKIM3_NAME CNAME to $DKIM3"
    az network dns record-set cname set-record --resource-group $RG --zone-name $ZONE --record-set-name $DKIM3_NAME --cname $DKIM3 --query $QUERY_CNAME
fi

# Set DMARC
if [ ! -z ${SETDMARC} ]; then
    echo "Setting $DMARK_NAME TXT value to $DMARC"
    az network dns record-set txt add-record --resource-group $RG --zone-name $ZONE --record-set-name $DMARC_NAME --value $DMARC
fi

# Show All
echo "Verify/SPF"
az network dns record-set txt   show --resource-group $RG --zone-name $ZONE --name "@" -o jsonc --query $QUERY_TXT || true

echo "MX"
az network dns record-set mx    show --resource-group $RG --zone-name $ZONE --name "@" -o jsonc --query $QUERY_MX || true

echo "DKIM"
az network dns record-set cname show --resource-group $RG --zone-name $ZONE --name $DKIM1_NAME -o jsonc --query $QUERY_CNAME || true
az network dns record-set cname show --resource-group $RG --zone-name $ZONE --name $DKIM2_NAME -o jsonc --query $QUERY_CNAME || true
az network dns record-set cname show --resource-group $RG --zone-name $ZONE --name $DKIM3_NAME -o jsonc --query $QUERY_CNAME || true

echo "DMARK"
az network dns record-set txt show --resource-group $RG --zone-name $ZONE --name "_dmarc" -o jsonc --query $QUERY_TXT || true
