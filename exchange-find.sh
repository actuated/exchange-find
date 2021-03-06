#!/bin/bash
#sleepscan.sh
#Script uses curl to check HTTPS response headers for provided hostname or IP targets.
dateCreated="3/2/2020"
dateLastMod="3/2/2020"
#   3/2/2020 - Added check if 302 Location header url starts with htt*: or not.
#            - Set to ignore 400, 403, and 500 responses in addition to 404.
#            - Added check to note if 401 but no Basic or NTLM auth.
#   3/2/2020 - Limited NTLM flag to WWW-Authenticate: NTLM header so it doesn't flag on Negotiate.
#            - Added 451 redirect check.
#            - Changed /owa to /owa/, added NTLM response check, added 301 redirect check.
#  3/19/2020 - Changed /ecp to /ecp/, targets to target(s).

exchUrls="/autodiscover/autodiscover.xml /ecp/ /ews /mapi /Microsoft-Server-ActiveSync /OAB /owa/ /rpc"

echo
echo "=====================[ exchange-find.sh - Ted R (github: actuated) ]====================="

inFile="$1"
if [ "$inFile" = "" ] || [ ! -f "$inFile" ]; then
  echo
  echo "Error: Input file '$inFile' does not exist or was not specified."
  echo
  echo "Usage: ./exchange-find.sh [list of target hosts] [--show-ntlm]"
  echo
  echo "Script uses curl to check HTTPS response headers for provided hostname or IP targets."
  echo "Checks for Exchange URLs and WWW-Authenticate headers. Checks for:"
  echo "$exchUrls"
  echo
  echo "--show-ntlm   If NTLM authentication endpoints are found, script attempts to get the"
  echo "              domain name by curling an empty NTLM login to the last NTLM endpoint for"
  echo "              that target. This option adds the parsed ASCII output of that response."
  echo
  echo "Created $dateCreated, last modified $dateLastMod."
  echo
  echo "=========================================[ fin ]========================================="
  echo
  exit
fi

showNTLM="N"
if [ "$2" == "--show-ntlm" ]; then showNTLM="Y"; fi

numTargets=$(wc -l "$inFile" | awk '{print $1}')
echo
read -p "Press Enter to start checking $numTargets target(s) in $inFile..."

while read -r thisTargetInput; do
  # Check target input for https:// or trailing /
  thisTarget=$(echo "$thisTargetInput" | tr 'A-Z' 'a-z' | sed 's/https:\/\///g' | sed 's/\/$//g')
  firstResult="Y"
  lastNTLMUrl=""
  for exchUrl in $exchUrls; do
    thisOut=""
    thisUrl="https://$thisTarget$exchUrl"
    thisResp=$(curl -Iks $thisUrl --max-time 60)
    if [ "$thisResp" != "" ]; then
      thisRespCode=$(echo "$thisResp" | grep -i "^HTTP" | head -n 1 | awk '{print $2}')
      if [ "$thisRespCode" != "" ] && [ "$thisRespCode" != "400" ] && [ "$thisRespCode" != "403" ]  && [ "$thisRespCode" != "404" ] && [ "$thisRespCode" != "500" ]; then
        thisOut="$thisUrl - $thisRespCode"
        # For 302/301, check if there is a Location header, and if it is a full URL or needs the host added.
        if [ "$thisRespCode" = "302" ] || [ "$thisRespCode" = "301" ]; then
          hasLoc=$(echo "$thisResp" | grep -i "Location:" | awk '{print $2}')
          if [ "$hasLoc" != "" ]; then
            check302Url=$(echo "$hasLoc" | grep -i "^htt.*:")
            if [ "$check302Url" != "" ]; then
              thisOut="$thisOut - $hasLoc"
            else
              thisOut="$thisOut - https://$thisTarget$hasLoc"
            fi
          fi
        fi
        # For 451, check for X-MS-Location header, and if it is a full URL or needs the host added.
        if [ "$thisRespCode" = "451" ]; then
          hasLoc=$(echo "$thisResp" | grep -i "X-MS-Location:" | awk '{print $2}')
          if [ "$hasLoc" != "" ]; then
            check451Url=$(echo "$hasLoc" | grep -i "^htt.*:")
            if [ "$check451Url" != "" ]; then
              thisOut="$thisOut - $hasLoc"
            else
              thisOut="$thisOut - https://$thisTarget$hasLoc"
            fi
          fi
        fi
        # Check for Basic auth header
        isBasic=$(echo "$thisResp" | grep -i "WWW-Authenticate: Basic")
        if [ "$isBasic" != "" ]; then
          thisOut="$thisOut - Basic"
        fi
        # Check for NTLM auth header
        isNtlm=$(echo "$thisResp" | grep -i "WWW-Authenticate: NTLM")
        if [ "$isNtlm" != "" ]; then
          thisOut="$thisOut - NTLM"
          lastNTLMUrl="$thisUrl"
        fi
        # Flag if 401 response did not support Basic or NTLM auth
        if [ "$thisRespCode" = "401" ] && [ "$isBasic" = "" ] && [ "$isNtlm" = "" ]; then
          thisOut="$thisOut - No Basic or NTLM?"
        fi
        if [ "$firstResult" = "Y" ]; then
          echo
          echo "========================================================================================="
          echo
          firstResult="N"
        fi
        echo "$thisOut"
      fi
    fi
  done
  # If an NTLM URL was found for this target, get blank auth response, decode and parse for domain name
  if [ "$lastNTLMUrl" != "" ]; then
    echo
    thisRand="parse-ntlmssp-$(cat /dev/urandom | tr -dc 'A-Za-z' | head -c 10 | cut -c1-10).txt"
    if [ -f "$thisRand" ]; then rm "$thisRand"; fi
    curl -Iks --ntlm -u : $thisUrl | grep -i "WWW-Authenticate: NTLM ..." | awk '{print $3}' > "$thisRand"
    if [ "$showNTLM" = "Y" ]; then
      echo "NTLMSSP Response for Blank Auth to $thisUrl:"
      base64 -d --ignore-garbage "$thisRand" | xxd -c 80 | awk '{print $NF}'
      echo
    fi
    thisDomain=$(base64 -d --ignore-garbage "$thisRand" | xxd | awk '{print $NF}' | tr -d '\n' | cut -c57-100 | awk -F \. '{print $1}')
    echo "Domain is probably: $thisDomain"
    if [ -f "$thisRand" ]; then rm "$thisRand"; fi
  fi
done < "$inFile"

echo
echo "=========================================[ fin ]========================================="
echo
