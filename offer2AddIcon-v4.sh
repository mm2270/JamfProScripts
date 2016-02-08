#!/bin/sh

#########################################################################################
##
##	Script Name:        offer2AddIcon-v4.sh
##	Author:             Mike Morales
##	Last Date Modified: 06-13-2014
##	Notes:		    Edited to include cocoaDialog GUI functions if installed
##		            Added error check if app path is not found on disk, to exit
##
#########################################################################################

## Get information about the logged in user
user=$(stat -f%Su /dev/console)
HomeDirPath=$( /usr/bin/dscl . -read /Users/$user NFSHomeDirectory | awk '{print $2}' )

## Set the location to dockutil and the SS icon
dockutil="/usr/sbin/dockutil"
icon="/Applications/Self Service.app/Contents/Resources/Self Service.icns"

## Location of cocoaDialog and jamfHelper
cdPath="/Library/Application Support/JAMF/bin/cocoaDialog.app/Contents/MacOS/cocoaDialog"
jhPath="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

## Parameter assignments. $4, $5 and $6 must be assigned within the Casper Suite policy
AppName=""
ID=""
AppPath=""


## Assign REQUIRED parameters 4, 5 and 6 to "AppName", "ID" and "AppPath" respectively
if [ "$4" != "" ] && [ "$AppName" == "" ]; then
	AppName=$4
fi

if [ "$5" != "" ] && [ "$ID" == "" ]; then
	ID=$5
fi

if [ "$6" != "" ] && [ "$AppPath" == "" ]; then
	AppPath=$6
fi

## Set optional parameter for "after" icon
## Note, script will continue if this parameter is not assigned in the policy
if [ "$7" != "" ]; then
	AfterApp=$7
fi

## Check for assigned parameters. If either $4 or $5 fail, we exit with an error
if [ "$AppName" == "" ]; then
	echo "Error:  The parameter 'AppName' is blank.  Please specify an application name."
	exit 1
fi

if [ "$ID" == "" ]; then
	echo "Error:  The parameter 'ID' is blank.  Please specify a Dock icon ID #."
	exit 1
fi

if [ "$AppPath" == "" ]; then
	echo "Error:  The parameter 'AppPath' is blank.  Please specify an application path."
	exit 1
fi

## Debug process - Echoing parameters
echo "Listing parameters for script:
App Name:\t${AppName}
App Path:\t${AppPath}
Icon ID:\t${ID}
Username:\t${user}"

## Creating variables based on assigned parameters
dockIconCheck=$( /usr/bin/defaults read $HomeDirPath/Library/Preferences/com.apple.dock | grep "file-label.*${AppName}" )

## Various message strings that we may use
MSG1="The $AppName installation has completed.

The $AppName icon is not in your Dock. Would you like to add it now?"

MSG2="The $AppName installation has completed"

MSG3="The $AppName icon is not in your Dock. Would you like to add it now?"

#### BEGIN SCRIPT CONTENTS. DO NOT EDIT BELOW THIS LINE ####

## Function to add the Dock icon using either dockutil or the jamf binary
function addDockIcon ()
{

if [[ -f /usr/sbin/dockutil ]]; then
	echo "$user clicked \"Yes\", adding $AppName Dock icon. dockutil found on system. Utilizing..."
	if [[ $AfterApp != "" ]]; then
		if [[ $( /usr/sbin/dockutil --list /Users/$user | awk -F"file" '{print $1}' | grep "$AfterApp" ) != "" ]]; then
			## The After app was found in the user's Dock, so place the new icon after it
			/usr/sbin/dockutil --add "/Applications/$AppName.app" --after "$AfterApp" /Users/$user
			echo "$AppName icon added after the $AfterApp icon in $user's Dock"
		else
			## The After app wasn't found in the user's Dock, so place it at the end
			/usr/sbin/dockutil --add "/Applications/$AppName.app" /Users/$user
			echo "$AppName icon added to the end of $user's Dock"
		fi
	else
		## No After app was set in the script parameter, so just add it to the end of the Dock
		/usr/sbin/dockutil --add "/Applications/$AppName.app" /Users/$user
		echo "$AppName icon added to the end of $user's Dock"
	fi
else
	## Dockutil isn't installed, so fall back to using the jamf binary function
	echo "$user clicked \"Yes\", adding $AppName Dock icon. dockutil not found on system. Using jamf binary..."
	/usr/local/jamf/bin/jamf modifyDock -id "$ID" -end
	echo "$AppName icon added to $user's Dock"
fi

}

## First check to make sure the AppPath executable exists on the Mac or we exit silently,
## since it means perhaps the installation from Self Service failed

if [[ ! -d "${AppPath}" ]]; then
	echo "The application at $AppPath isn't on this Mac, so exit"
	exit 1
fi

## If the Dock icon is not found, offer to add it
if [[ "$dockIconCheck" = "" ]]; then
	echo "The icon for $AppName was not found in $user's Dock"
	if [[ -e "$cdPath" ]]; then
		## cocoaDialog is installed. Display cocoaDialog message
		offerRes=$( "$cdPath" msgbox --title "Self Service" --text "$MSG2" --informative-text "$MSG3" --button1 "   Yes   " --button2 "   No   " \
		--cancel "button2" --timeout 30 --timeout-format " " --icon-file "$icon" --posY top --width 400 --string-output )
	else
		## cocoaDialog isn't installed yet, so fall back to using jamfHelper. Display jamfHelper message
		offerRes=$( "$jamfHelper" -windowType utility -title "Self Service" -description "$MSG1" -button1 "Yes" -button2 "No" \
		-defaultButton 1 -cancelButton 2 -timeout 30 -icon "$icon" )
	fi
	
	## Check the result of the offer dialog
	if [[ "$offerRes" == "0" ]] || [[ "$offerRes" =~ "Yes" ]]; then
		## Looks like the Yes was button was clicked, so move on to the add Dock icon function
		addDockIcon
	else
		echo "$user clicked \"No\". Leaving Dock as is and exiting"
		exit 0
	fi
fi

## If the Dock icon is already present, let the user know installation is complete
if [[ "$dockIconCheck" != "" ]]; then
	echo "$AppName icon was already found in $user's Dock"
	if [[ -e "$cdPath" ]]; then
		## cocoaDialog is installed. Use it
		"$cdPath" msgbox --title "Self Service" --text "Complete" --informative-text "$MSG2" --button1 "    OK    " --timeout 10 --timeout-format " " --icon-file "$icon" --posY top
	else
		## cocoaDialog isn't installed, so use jamfHelper
		"$jamfHelper" -windowType utility -title "Self Service" -description "$MSG2" -button1 "OK" -defaultButton 1 -timeout 10 -icon "$icon"
	fi
fi
