#!/bin/bash

## Script name:		download_jss_scripts.sh
## Author:		Mike Morales (@mm2270 on JAMFNation)
##			https://jamfnation.jamfsoftware.com/viewProfile.html?userID=1927
## Last change:		2018-Jan-15
## Last change description:
##			Placed curl header in front of account credentials to prevent errors when downloading script contents
##			Replaced xmllint with xpath string on line 156 to obtain full script contents

## Description:		Script to download all JSS scripts from a
##			Casper Suite version 9.x or version 10.x Jamf Pro server. For more detailed information,
##			run the script in Terminal with the -h flag

## The following section contains the only variables that should be manually edited in
## the script. They can also be assigned to the script as Casper Suite parameters.
## Read the descriptions for more info.

## If you choose to hardcode API information into the script, set the API Username
## and API Password here. Note: The API account only needs 'read' privileges to
## pull JSS scripts

apiUser=""		## Set the API Username here if you want it hardcoded
apiPass=""		## Set the API Password here if you want it hardcoded
jssURL=""		## Set the JSS URL here if you want it hardcoded

## Set the script downloads folder path here.
## Default path is within the JAMF directory in "JSS_Scripts"
scriptDownloadDir="/Library/Application Support/JAMF/JSS_Scripts"

################################ DO NOT EDIT BELOW THIS LINE ################################

script=$(basename $0)
directory="$(cd "$(dirname "$0")" && pwd)"

## Help / Usage function
usage ()
{
cat << EOF
SYNOPSIS
	sudo script.sh -a "api_user" -p "api_password" -s "server"
	or
	sudo jamf runScript -script "script.sh" -path "/path/to/" -p1 "api_user" -p2 "api_password" -p3 "server"

COMPATIBILITY:
	Casper Suite version 9.x
	
OPTIONS:
	-h	Show this usage screen
	-a	API account username
	-p	API account password
	-s	JSS Server address [optional]

DESCRIPTION:
	This script can be used to download a copy of all JSS scripts
	located on the Casper Suite server specified in the server option.
	The Casper Suite server (JSS) URL is optional. If not specified at run time,
	the script will attempt to obtain the JSS address from the client's settings.
	
	The script can be run in two primary ways.
	1. Calling the script directly in the shell
	
	Example:
	sudo "$0" -a "api_username" -p "api_password" -s "https://jss.server.com:8443"
	
	2. Using the jamf binary
	
	Example:
	sudo jamf runScript -script "$script" -path "$directory" -p1 "api_username" -p2 "api_password" -p3 "https://jss.server.com:8443"
	
	You may also use the script directly in a JSS policy, specifying the API username,
	API password and (optionally) the JSS URL in parameters 4 through 6, respectively.

NOTES:
	It is recommended to enclose the API username, API password and JSS URL in double quotes
	to protect the script against any special characters or spaces in the strings.
		
EOF
exit
}

## Run loop to check for passed args on the command line
while getopts ha:p:s option; do
	case "${option}" in
		a) apiUser=${OPTARG};;
		p) apiPass=${OPTARG};;
		s) jssURL=${OPTARG};;
		h) usage;;
	esac
done

## Check to see if the script was passed any script parameters from Casper
if [[ "$apiUser" == "" ]] && [[ "$4" != "" ]]; then
	apiUser="$4"
fi

if [[ "$apiPass" == "" ]] && [[ "$5" != "" ]]; then
	apiPass="$5"
fi

if [[ "$jssURL" == "" ]] && [[ "$6" != "" ]]; then
	jssURL="$6"
fi

## Finally, make sure we got at least an apiUser & apiPass variable, else we exit
if [[ -z "$apiUser" ]] || [[ -z "$apiPass" ]]; then
	echo -e "API Username = $apiUser\nAPI Password = $apiPass"
	echo "One of the required variables was not passed to the script. Exiting..."
	exit 1
fi

## If no server address was passed to the script, get it from the Mac's com.jamfsoftware.jamf.plist
if [[ -z "$jssURL" ]]; then
	jssURL=$(/usr/bin/defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url 2> /dev/null | sed 's/\/$//')
	if [[ -z "$jssURL" ]]; then
		echo "JSS URL = $jssURL"
		echo "Oops! We couldn't get the JSS URL from this Mac, and none was passed to the script"
		exit 1
	else
		echo "JSS URL = $jssURL"
	fi
else
	## Make sure to remove any trailing / in the passed parameter for the JSS URL
	jssURL="${jssURL%/}"
fi

## Set up the JSS Scripts API URL
jssScriptsURL="${jssURL}/JSSResource/scripts"

## Run quick check on access to the JSS API
curl -skfu "${apiUser}:${apiPass}" "${jssScriptsURL}" 2>&1 > /dev/null

if [[ "$?" != "0" ]]; then
	echo "There was an error retrieving information from the JSS.
Please check your API credentials and/or the JSS URL, and ensure the JSS is accessible from your location. Exiting now..."
	exit 1
fi

## Create the script download directory if not present
if [[ ! -d "$scriptDownloadDir" ]]; then
	mkdir "$scriptDownloadDir"
fi

## Begin script download process
echo "Step 1:	Gathering all Script IDs from the JSS..."
## Generate a list of all Script IDs we can pull from the JSS using the API
allScriptIDs=$(curl -H "Accept: text/xml" -skfu "${apiUser}:${apiPass}" "${jssScriptsURL}" | xmllint --format - | awk -F'>|<' '/<id>/{print $3}' | sort -n)

## Now read through each ID gathered and get specific information on each Script from the JSS
echo "Step 2:	Pulling down each Script from the JSS..."

downloadCount=0
while read ID; do
	## Get the Script name from its JSS ID
	script_Name=$(curl -H "Accept: application/xml" -sku "${apiUser}:${apiPass}" "${jssScriptsURL}/id/${ID}" | xmllint --format - | awk -F'>|<' '/<name>/{print $3}')
	## Get the actual script contents from the API record for the script
	script_Content=$(curl -H "Accept: application/xml" -sku "${apiUser}:${apiPass}" "${jssScriptsURL}/id/${ID}" | xpath '/script/script_contents/text()')
	script_Ext=$(echo "$script_Name" | awk -F. '{print $NF}')
	
	echo "Script name is: $script_Name"
	
	if [ "$script_Ext" == "$script_Name" ]; then
		## Get the first line, which should be a shebang of some kind
		firstLine=$(echo "${script_Content}" | head -1)
		## If it looks like the first line begins with a shebang...
		if [[ $(echo "$firstLine" | grep "^#\!" ) ]]; then
			## ...grab the script's interpreter
			shellEnv=$(echo "$firstLine" | awk -F'/' '{print $NF}' | perl -pi -e 'tr/\cM//d;')
			## If the script's interpreter ends in sh (.sh, .bash, .ksh, csh, etc)...
			if [[ "$shellEnv" =~ sh$ ]]; then
				## ...set the script extension to .sh
				script_Ext="sh"
			else
				## Otherwise, use whatever we grabbed as the interpreter (might be .py, .pl, etc)
				script_Ext=$(echo "${shellEnv}" | sed 's/^M//')
			fi
		else
			## We didn't see a shebang as the first line, so assume its a shell script. Set the extension to .sh
			script_Ext="sh"
		fi
		## Echo the script contents into script file
		echo "${script_Content}" > "${scriptDownloadDir}/${script_Name}.${script_Ext}"
		echo "Downloaded script \"${script_Name}.${script_Ext}\"..."
		let downloadCount+=1
	else
		## The script name already has an extension. Echo the script contents into script file
		echo "${script_Content}" > "${scriptDownloadDir}/${script_Name}"
		echo "Downloaded script \"${script_Name}\"..."
		let downloadCount+=1
	fi
done < <(echo "${allScriptIDs}")

echo "Finished downloading all scripts from the JSS"

echo "Step 3:	Cleaning up script file contents...
	Adding ea_display_name line to end of each file (if needed)...
	Cleaning up ^M carriage returns in script contents...
	Setting executable flag for all script files..."

## Loop through all downloaded scripts, stripping out problem characters and adding the ea_display_name line
while read downloadedScript; do
	scriptBaseName="${downloadedScript%.*}"
	## Replace '&lt' and '&gt' with proper '<' and '>' symbols in script contents
	sed -i '' 's/&lt;/</g;s/&gt;/>/g' "${scriptDownloadDir}/${downloadedScript}"
	## Replace '&amp' with proper '&' symbol in script contents
	sed -i '' 's/&amp;/\&/g' "${scriptDownloadDir}/${downloadedScript}"
	## Remove all Windows carriage returns (^M) from the script contents
	perl -pi -e 'tr/\cM//d;' "${scriptDownloadDir}/${downloadedScript}"
	## Make sure all the scripts have the executable flag set for them
	chmod +x "${scriptDownloadDir}/${downloadedScript}"
done < <(ls -p "${scriptDownloadDir}" | grep -v /)


echo -e "\nFinal results:
A total of ${downloadCount} scripts were downloaded.

You should check the output for each script to verify that the results are what you expect."

echo -e "\nStep 4:	Done!"

exit
