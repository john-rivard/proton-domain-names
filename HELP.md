<pre><code>Usage: ./configure-proton-mail-dns.sh -s sub -g group -z dns-zone [options]
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
</code></pre>