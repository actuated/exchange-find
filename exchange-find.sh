#!/bin/bash
#sleepscan.sh
#Script uses curl to check HTTPS response headers for provided hostname or IP targets.
dateCreated="3/2/2020"
dateLastMod="3/2/2020"
# 3/2/2020 - Added check if 302 Location header url starts with htt*: or not.
#          - Set to ignore 400, 403, and 500 responses in addition to 404.
#          - Added check to note if 401 but no Basic or NTLM auth.

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
  thisTarget=$(echo "$thisTargetInput" | tr 'A-Z' 'a-z' | sed 's/https:\/\///g' | sed 's/\/$//g')
  firstResult="Y"
  for exchUrl in $exchUrls; do
    thisOut=""
    thisUrl="https://$thisTarget$exchUrl"
    thisResp=$(curl -Iks $thisUrl --max-time 60)
    if [ "$thisResp" != "" ]; then
      thisRespCode=$(echo "$thisResp" | grep -i "^HTTP" | awk '{print $2}')
      if [ "$thisRespCode" != "" ] && [ "$thisRespCode" != "400" ] && [ "$thisRespCode" != "403" ]  && [ "$thisRespCode" != "404" ] && [ "$thisRespCode" != "500" ]; then
        thisOut="$thisUrl - $thisRespCode"
        is302=$(echo "$thisResp" | grep -i "Location:" | awk '{print $2}')
        if [ "$is302" != "" ]; then
          check302Url=$(echo "$is302" | grep -i "^htt.*:")
          if [ "$check302Url" != "" ]; then
            thisOut="$thisOut - $is302"
          else
            thisOut="$thisOut - https://$thisTarget$is302"
          fi
        fi
        isBasic=$(echo "$thisResp" | grep -i "WWW-Authenticate: Basic")
        if [ "$isBasic" != "" ]; then
          thisOut="$thisOut - Basic"
        fi
        isNtlm=$(echo "$thisResp" | grep -i "WWW-Authenticate: N")
        if [ "$isNtlm" != "" ]; then
          thisOut="$thisOut - NTLM"
        fi
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
