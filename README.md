# exchange-find
Shell script to check a list of hostnames or IPs for HTTPS response codes, WWW-Authenticate headers, and 302 redirect Location headers for common Exchange URLs.

# Usage
```
./exchange-find.sh [list of target hosts]
```
- Strips `https://` and trailing `/`s from target hostnames or IPs.
  - Target list should be a file containing hostnames, IPs, or IP:Port.
  - Example:
```
example.com
mail.example.com
x.x.x.x
y.y.y.y:z
```
- Uses `curl -Iks https://[target][url]` to get HTTPS response headers for Exchange URLs:
  - `/autodiscover/autodiscover.xml /ecp /ews /mapi /Microsoft-Server-ActiveSync /OAB /owa/ /rpc`
  - Timeout set to 60 seconds.
- Ignores non-responses, 400, 403, 404, and 500 responses.
- Provides responses codes for responsive URLs.
  - For 301/302, adds the URL from the Location response header.
  - For 451, adds the URL from the X-MS-Location response header.
  - Flags "Basic" for responses with `WWW-Authenticate: Basic`.
  - Flags "NTLM" for responses with headers that match `WWW-Authenticate: NTLM`.
  - After finding NTLM auth, will show Base64-decoded response for empty authentication so you can try to figure out the domain.
  - Flags if 401, but no Basic or NTLM authentication headers.
  - Checks for headers are case-insensitive.
  
# Example
```
=====================[ exchange-find.sh - Ted R (github: actuated) ]=====================

Press Enter to start checking 5 targets in test.txt...

=========================================================================================

https://a.a.a.a/autodiscover/autodiscover.xml - 401 - Basic - NTLM
https://a.a.a.a/ecp - 401 - NTLM
https://a.a.a.a/ews - 401 - NTLM
https://a.a.a.a/mapi - 401 - NTLM
https://a.a.a.a/Microsoft-Server-ActiveSync - 401 - Basic
https://a.a.a.a/OAB - 401 - NTLM
https://a.a.a.a/owa - 401 - NTLM
https://a.a.a.a/rpc - 401 - Basic - NTLM

=========================================================================================

https://b.b.b.b/Microsoft-Server-ActiveSync - 401 - Basic

=========================================================================================

https://c.c.c.c/Microsoft-Server-ActiveSync - 401 - Basic

=========================================================================================

https://d.d.d.d/autodiscover/autodiscover.xml - 302 - https://d.d.d.d/vpn/tmindex.html
https://d.d.d.d/ecp - 302 - https://d.d.d.d/vpn/tmindex.html
https://d.d.d.d/ews - 302 - https://d.d.d.d/vpn/tmindex.html
https://d.d.d.d/mapi - 302 - https://d.d.d.d/vpn/tmindex.html
https://d.d.d.d/Microsoft-Server-ActiveSync - 302 - https://d.d.d.d/vpn/tmindex.html
https://d.d.d.d/OAB - 302 - https://d.d.d.d/vpn/tmindex.html
https://d.d.d.d/owa - 302 - https://d.d.d.d/vpn/tmindex.html
https://d.d.d.d/rpc - 302 - https://d.d.d.d/vpn/tmindex.html

=========================================[ fin ]=========================================
```
