#!/bin/bash
#sleepscan.sh
#Script uses curl to check HTTPS response headers for provided hostname or IP targets.
dateCreated="3/2/2020"
dateLastMod="3/2/2020"
# 3/2/2020 - Added check if 302 Location header url starts with htt*: or not.
#          - Set to ignore 400, 403, and 500 responses in addition to 404.
#          - Added check to note if 401 but no Basic or NTLM auth.
# 3/2/2020 - Limited NTLM flag to WWW-Authenticate: NTLM header so it doesn't flag on Negotiate.
#          - Added 451 redirect check.

exchUrls="/autodiscover/autodiscover.xml /ecp /ews /mapi /Microsoft-Server-ActiveSync /OAB /owa /rpc"

echo
echo "=====================[ exchange-find.sh - Ted R (github: actuated) ]====================="

inFile="$1"
if [ "$inFile" = "" ] || [ ! -f "$inFile" ]; then
  echo
  echo "Error: Input file '$inFile' does not exist or was not specified."
  echo
  echo "Usage: ./exchange-find.sh [list of target hosts]"
  echo
  echo "Script uses curl to check HTTPS response headers for provided hostname or IP targets."
  echo "Checks for Exchange URLs and WWW-Authenticate headers. Checks for:"
  echo "$exchUrls"
  echo
  echo "Created $dateCreated, last modified $dateLastMod."
  echo
  echo "=========================================[ fin ]========================================="
  echo
  exit
fi

numTargets=$(wc -l "$inFile" | awk '{print $1}')
echo
read -p "Press Enter to start checking $numTargets targets in $inFile..."

while read -r thisTargetInput; do
  # Check target input for https:// or trailing /
  thisTarget=$(echo "$thisTargetInput" | tr 'A-Z' 'a-z' | sed 's/https:\/\///g' | sed 's/\/$//g')
  firstResult="Y"
  for exchUrl in $exchUrls; do
    thisOut=""
    thisUrl="https://$thisTarget$exchUrl"
    thisResp=$(curl -Iks $thisUrl --max-time 60)
    if [ "$thisResp" != "" ]; then
      thisRespCode=$(echo "$thisResp" | grep -i "^HTTP" | head -n 1 | awk '{print $2}')
      if [ "$thisRespCode" != "" ] && [ "$thisRespCode" != "400" ] && [ "$thisRespCode" != "403" ]  && [ "$thisRespCode" != "404" ] && [ "$thisRespCode" != "500" ]; then
        thisOut="$thisUrl - $thisRespCode"
        # For 302, check if there is a Location header, and if it is a full URL or needs the host added.
        if [ "$thisRespCode" = "302" ]; then
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
done < "$inFile"

echo
echo "=========================================[ fin ]========================================="
echo
