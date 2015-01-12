#!/bin/bash

##	Script:		create_SelfService_Plug-in.sh
##	Author:		Mike Morales
##	Last Change:	2015-01-11


function createPlugIn ()
{

echo "Starting Plug-in creation..."
echo "Checking for existing Plug-ins..."
sleep 0.5

if [ -d "/Library/Application Support/JAMF/" ]; then
	## Check for an existing Self Service Plug-ins directory
	if [ -d "/Library/Application Support/JAMF/Self Service/Plug-ins" ]; then
		pluginFolderExists="yes"
		destDir="/Library/Application Support/JAMF/Self Service/Plug-ins"

		## Capture a list of any installed plug-ins
		installedPlugIns=$(ls "/Library/Application Support/JAMF/Self Service/Plug-ins" | sed 's/.plist//g' | sort -g | awk '$1 > 999 {print}')
	
		## If any are in the 1000+ range, determine the next available ID
		if [ ! -z "$installedPlugIns" ]; then
			lastID=$(ls "/Library/Application Support/JAMF/Self Service/Plug-ins" | sed 's/.plist//g' | sort -g | awk '$1 > 999 {print}' | tail -1)
		
			nextID=$((lastID+1))
		else
			## If none are in the 1000+ range, set the ID to 1000
			nextID="1000"
		fi
	else
		## If there is no Plug-Ins folder, set the ID to 1000
		nextID="1000"
	
		echo "The Self Service Plug-ins folder doesn't exist on this Mac. Creating it now..."
	
		mkdir -p "/Library/Application Support/JAMF/Self Service/Plug-ins"
		chown root:admin "/Library/Application Support/JAMF/Self Service/Plug-ins"
		chmod -R 755 "/Library/Application Support/JAMF/Self Service/Plug-ins"

		pluginFolderExists="yes"
		destDir="/Library/Application Support/JAMF/Self Service/Plug-ins"

		sleep 0.5
	fi
else
	## The 'JAMF' directory does not exist on this Mac. Therefore, its an un-enrolled system
	echo -e "No '/Library/Application Support/JAMF' directory was found on this Mac.\nThe Plug-in will be saved to your Desktop."

	nextID="1000"
	destDir="/Users/$loggedInUser/Desktop"

	sleep 0.5
fi

## If an image was chosen, convert it to binary data
if [ ! -z "$ICON" ]; then
	echo "Converting image file to binary data..."
	sleep 0.5

	imageData=$(cat "$ICON" | base64)
fi

id="$nextID"
url="$URL"
title="$TITLE"
subtitle="$SUBTITLE"
priority="$PRIORITY"
openInBrowser="$OPENINBROWSER"
icon="$imageData"

echo "Creating $TITLE Plug-in..."
sleep 0.5

## Create the Plug-in plist file
echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
  <dict>
    <key>id</key>
    <string>$id</string>
    <key>version</key>
    <integer>1</integer>
    <key>url</key>
    <string>$url</string>
    <key>title</key>
    <string>$title</string>
    <key>priority</key>
    <string>$priority</string>
    <key>subtitle</key>
    <string>$subtitle</string>
    <key>openInBrowserAutomatically</key>
    <$openInBrowser/>
    <key>image</key>
    <data>$imageData</data>
  </dict>
</plist>" > "${destDir}/${id}.plist"

if [ "$?" == "0" ]; then
	if [ "$pluginFolderExists" == "yes" ]; then
		echo -e "The Plug-in has been saved to the location: ${destDir}/${id}.plist. Self Service should now show the Plug-in\n"
		exit 0
	else
		echo -e "The Plug-in has been saved to the location: ${destDir}/${id}.plist. If necessary, you can package this plug-in plist and deploy it to other Macs.\n"
		exit 0
	fi
else
	echo "We ran into an error while creating the Plug-in.
However, its possible the Plug-in was successfully saved. If its not showing up in Self Service,
try running this script again to create it."

	exit 1
fi
}

function finalSteps ()
{

if [ -z "$SUBTITLE" ]; then
	SUBTITLE_PRINT="* None chosen *"
else
	SUBTITLE_PRINT="$SUBTITLE"
fi

if [ -z "$ICON" ]; then
	ICON_PRINT="* None chosen *"
else
	ICON_PRINT="$ICON"
fi

finalText="Looks like we have everything we need.
Check the settings you chose below and press Enter or Return to create the Self Service URL Plug-in:

URL:			$URL
Title:			$TITLE
Description:		$SUBTITLE_PRINT
Priority:		$PRIORITY
Icon:			$ICON_PRINT
Open in browser: 	$OPENINBROWSER

If everything above looks good, press 'Enter' or 'Return' to create the Plug-in.
If you would like to start over, type in REDO and press Enter or Return"

echo "$finalText"

read PROCESS

if [ -z "$PROCESS" ]; then
	echo -e "Processing...\n"
	createPlugIn

elif [[ "$PROCESS" == "REDO" || "redo" ]]; then
	echo -e "Starting over...\n"
	sleep 0.5
	
	initialUsage
fi

}


function askBrowserPref ()
{

browserPrefText="Step 6: Choose if you would like the Plug-in to open in a default browser, or load into Self Service.
Type in \"yes\" for opening in an external browser, or press Enter/Return to have it open in Self Service."

echo "$browserPrefText"

read BROWSER

shopt -s nocasematch

if [[ ! -z "$BROWSER" ]] && [[ "$BROWSER" == "yes" ]]; then
	OPENINBROWSER="true"
	
	echo -e "Setting chosen was: \"Open in browser\" Continuing...\n"	
	shopt -u nocasematch
	
	sleep 0.5
	finalSteps
	
else
	OPENINBROWSER="false"
	
	echo -e "Setting chosen was: \"Open in Self Service\" Continuing...\n"
	
	sleep 0.5
	finalSteps
fi

}


function askForIcon ()
{

if [ -z "$iconText" ]; then
	iconText="Step 5: Drag and drop an image file from the Finder to be used for the Plug-in icon (Optional but Recommended) and press Enter/Return
Preferred format is PNG at 128x128 pixels, but can also accept .GIF, .TIF or .JPG formats.
Also, square images (pixel dimensions) work best, otherwise the icon will get squished disportionately within Self Service.app."
fi

echo "$iconText"

read ICON

if [ -z "$ICON" ]; then
	echo -e "Icon selected: None. This Self Service Plug-in will be created without an icon. Continuing...\n"
	askBrowserPref
else
	## Test to make sure we see a GIF, PNG, TIF or JPEG/JPG extension
	extension="${ICON##*.}"
	ICON_NAME=$(basename $ICON)
	
	## Set up case insensitive matching
	shopt -s nocasematch
	
	case "$extension" in
	png|tif|gif|jpg|jpeg)
		echo -e "Icon selected: $ICON_NAME. Continuing...\n"
		
		## Disable case insensitivity
		shopt -u nocasematch
		askBrowserPref ;;
	*)
		iconText="We couldn't detect if the image ${ICON_NAME} is in one of the accepted formats. Please use only a png, gif, tif or jpeg/jpg and try again:"
		
		## Disable case insensitivity
		shopt -u nocasematch
		askForIcon ;;
	esac
	
fi

}

function askForPriority ()
{

if [ -z "$priorityText" ]; then
	priorityText="Step 4: Enter a numeric value (1-20) for the priority of the Plug-in (Optional) and press Enter or Return
Lower values mean the Plug-in will appear before others in the Self Service sidebar.
Note that you can leave a default value of 5 by pressing Enter or Return:"

fi

echo "$priorityText"

read PRIORITY

if [ -z "$PRIORITY" ]; then
	echo -e "No value assigned. Using a default of \"5\"\n"
	
	PRIORITY="5"

	sleep 0.5
	askForIcon

else
	## Test to make sure we received an integer value
	test=$(echo "$PRIORITY / $PRIORITY" | bc)
	if [ "$test" == "1" ]; then
		if [[ "$PRIORITY" -gt 0 ]] && [[ "$PRIORITY" -lt 21 ]]; then
			echo -e "Value entered: \"$PRIORITY\" Continuing...\n"
			sleep 0.5
			askForIcon
		else
			priorityText="Oops! We can only accept a number value between 1-20. Please try again, or press Enter or Return to use the default value:"
			
			askForPriority
		fi
	else
		priorityText="Oops! We can only accept a number value between 1-20. No letters or punctuation. Please try again, or press Enter or Return to use the default value:"

		askForPriority
	fi
fi

}

function askForSubtitle ()
{

subTitleText="Step 3: Enter a description for the Plug-in (Optional), then Press Enter or Return
(Note: If you don't want a description, simply press Enter or Return to continue:"

echo "$subTitleText"

read SUBTITLE

if [ -z "$SUBTITLE" ]; then
	echo -e "No description was specified. Continuing...\n"
	sleep 0.5
	askForPriority
else
	echo -e "Description entered: \"$SUBTITLE\" Continuing...\n"
	sleep 0.5
	askForPriority
fi

}
function askForTitle ()
{

if [ -z "$titleText" ]; then
	titleText="Step 2: Enter a title for the Plug-in (Required), then press Enter or Return:"
fi

echo "$titleText"

read TITLE

if [ -z "$TITLE" ]; then
	titleText="Oops! A Title is required! Enter a title for the Plug-in, then press Enter or Return:"
	askForTitle
else
	echo -e "Title entered: \"$TITLE\" Continuing...\n"
	sleep 0.5
	askForSubtitle
fi

}


function askForURL ()
{

if [ -z "$urlText" ]; then
	urlText="Step 1: Enter a URL to use for the Plug-in (Required), then press Enter or Return:"
fi

echo "$urlText"

read URL

if [ -z "$URL" ]; then
	urlText="Oops! A URL is required! Please enter a URL and press Enter or Return:"
	askForURL
else
	echo -e "URL entered was: \"$URL\" Continuing...\n"
	sleep 0.5
	askForTitle
fi

}


function initialUsage ()
{

startMessage="This script will guide you in generating a Self Service URL Plug-in.
By default, new Self Service URL plug-ins are generated with an ID in the 1000 plus range 
so as to avoid any conflict with Plug-ins that may be set up on your JSS.

When ready to get started, just press 'Enter' or 'Return'. Otherwise, type 'exit' and press 'Return' to exit the script."

echo "$startMessage"

read BEGIN

if [ "$BEGIN" == "" ]; then
	echo -e "Starting...\n"
	sleep 0.5
	askForURL
elif [ "$BEGIN" == "exit" ]; then
	echo "Exiting. Good-bye!"
	exit 0
else
	initialUsage
fi

}

function checkForRoot ()
{

if [[ $EUID -ne 0 ]]; then
	echo -e "This script must be run as root. Please use 'sudo /path/to/script.sh' and try again\n"
	exit 1
else
	initialUsage
fi

}

checkForRoot
