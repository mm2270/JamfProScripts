#!/bin/bash

## Script name:		create_ARD_computer_list.sh
## Author:        	Mike Morales (mm2270)
## Last Modified:	2015-Sept-04

## Special Notes:	This script was designed to work with a Casper Suite server's API functions,
                  	to create a valid Apple Remote Desktop computer group plist file that can be
                  	imported into the application.
                  	The script allows you to choose a Smart or Static Computer Group from your JSS
                  	to use for the conversion process into an ARD plist.

## How to use:		Edit the API_USER, API_PASS and JSS_URL variables below to match your environment's.
                  	Save the script, ensure it is executable, then run it from Terminal and follow the instructions.


## VARIABLES

## Set the API Username, Password and your JSS URL below (Note: leave off trailing slash in the URL)
API_USER="apiuser"
API_PASS="apipass"
JSS_URL="https://your.jss.address.com:8443"


## START OF SCRIPT

## Get the logged in username
loggedInUser=$(stat -f%Su /dev/console)

## Get all JSS computer groups
GROUP_LIST=$(curl -H "Accept: text/xml" -sfku "${API_USER}:${API_PASS}" "${JSS_URL}/JSSResource/computergroups" -X GET 2>/dev/null | xmllint --format - | awk -F'>|<' '/<name>/{print $3}')

if [ ! -z "$GROUP_LIST" ]; then
## Prompt for selection of group name
GROUP_NAME=$(/usr/bin/osascript << EOF
set list_contents to do shell script "echo \"$GROUP_LIST\""
set selected_group to paragraphs of list_contents
tell application "System Events"
activate
choose from list selected_group with prompt "Choose a Computer Group to create an ARD list from"
end tell
EOF)

else
	echo "JSS Computer Groups could not be accessed. Make certain the API Username/Password and JSS URLs entered are correct and have proper read access to computer groups"
	exit 1
fi

if [ "$GROUP_NAME" == "false" ]; then
	exit 0
else

	## html encode the group name
	GROUP_NAME_WEB="$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "$GROUP_NAME")"

	## Get the JSS group ID
	JSS_GROUP_ID=$(curl -H "Accept: text/xml" -sfku "${API_USER}:${API_PASS}" "${JSS_URL}/JSSResource/computergroups/name/${GROUP_NAME_WEB}" -X GET | xmllint --format - | awk '/<computer_group>/,/<site>/{print}' | awk -F'>|<' '/<id>/{print $3}')

	## Pull down the entire Smart or Static Group xml file into /private/tmp using the group ID
	curl -H "Accept: text/xml" -sfku "${API_USER}:${API_PASS}" "${JSS_URL}/JSSResource/computergroups/id/${JSS_GROUP_ID}" -X GET | xmllint --format -  > /private/tmp/JSS_GROUP_${JSS_GROUP_ID}
	
	if [ "$?" == 0 ]; then
		xmlpresent="yes"
	fi
fi

if [ "xmlpresent" ]; then

	## Extract the group name from the xml to use as the ARD group name
	ARD_GROUP_NAME=$(awk '/<computer_group>/,/<site>/{print}' /private/tmp/JSS_GROUP_${JSS_GROUP_ID} | awk -F'>|<' '/<name>/{print $3}')

	## Strip the xml file down to only the computer records
	sed -i "" '/<computer_group>/,/<\/criteria>/d' "/private/tmp/JSS_GROUP_${JSS_GROUP_ID}"
	
	## Get all the JSS computer IDs from the file
	JSS_IDS=$(awk -F'>|<' '/<id>/{print $3}' /private/tmp/JSS_GROUP_${JSS_GROUP_ID})

	## Create the initial plist file contents
	echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
	<key>items</key>
	<array>" > "/private/tmp/${ARD_GROUP_NAME}.plist"


	function appendCompData ()
	{

	echo "		<dict>
			<key>hardwareAddress</key>
			<string>${MAC_ADDRESS}</string>
			<key>name</key>
			<string>${COMP_NAME}</string>
			<key>networkAddress</key>
			<string>${IP_ADDRESS}</string>
			<key>networkPort</key>
			<integer>3283</integer>
			<key>vncPort</key>
			<integer>5900</integer>
		</dict>" >> "/private/tmp/${ARD_GROUP_NAME}.plist"

	}

	## Loop over each JSS ID and get the MAC Address, Computer Name and IP Address for each
	## Run the above function to create individual dict computer entries into the plist file
	
	echo "$JSS_IDS" | while read JSSID || [ -n "$JSSID" ]; do
		MAC_ADDRESS=$(grep -A2 "<id>$JSSID</id>" /private/tmp/JSS_GROUP_${JSS_GROUP_ID} | awk -F'>|<' '/<mac_address>/{print $3}')
		COMP_NAME=$(grep -A2 "<id>$JSSID</id>" /private/tmp/JSS_GROUP_${JSS_GROUP_ID} | awk -F'>|<' '/<name>/{print $3}')
		IP_ADDRESS=$(curl -H "Accept: text/xml" -sfku "${API_USER}:${API_PASS}" "${JSS_URL}/JSSResource/computers/id/${JSSID}/subset/general" -X GET | xmllint --format - | awk -F'>|<' '/<ip_address>/{print $3}')

		appendCompData
	done

	## Generate a random UUID string
	UUID=$(python -c 'import uuid; print uuid.uuid1()' | tr '[:lower:]' '[:upper:]')

	## Finalize the plist file
	echo "	</array>
	<key>listName</key>
	<string>${ARD_GROUP_NAME}</string>
	<key>uuid</key>
	<string>${UUID}</string>
</dict>
</plist>" >> "/private/tmp/${ARD_GROUP_NAME}.plist"

	## IF the plist creation was successful, attempt to move the final plist file to the logged in user's Desktop
	if [ "$?" == "0" ]; then
		mv "/private/tmp/${ARD_GROUP_NAME}.plist" "/Users/${loggedInUser}/Desktop/${ARD_GROUP_NAME}.plist"
		
		if [ "$?" == "0" ]; then
			echo "ARD group plist named \"${ARD_GROUP_NAME}.plist\" was created successfully and moved to your Desktop"
			exit 0
		else
			echo "ARD group plist named \"${ARD_GROUP_NAME}.plist\" was created successfully. It could not be moved to your Desktop. It can be found in /tmp/"
			exit 0
		fi
	else
		echo "An error occurred. Could not create the ARD plist file."
		exit 1
	fi
else
	echo "Failed to pull down the initial xml file. Please check the JSS group ID and API credentials"
	exit 1
fi
