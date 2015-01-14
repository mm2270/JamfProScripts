#!/bin/bash

## Script name:		install_Latest_GoogleChrome-SelfService.sh
## Author:			Mike Morales
## Last modified:	2015-01-14

## Path to cocoaDialog. Used for all dialogs and progress bars
cdPath="/Library/Application Support/JAMF/bin/cocoaDialog.app/Contents/MacOS/cocoaDialog"

## Common variable strings used throughout dialogs
MsgTitle="IT - Application Installer"
properName="Google Chrome"
dmg_icon="/System/Library/CoreServices/DiskImageMounter.app/Contents/Resources/diskcopy-doc.icns"

## URL to the latest version of Google Chrome DMG
download_url="https://dl.google.com/chrome/mac/stable/GGRM/googlechrome.dmg"

## Path to install location for Google Chrome. Also used in case of existing install
appPath="/Applications/Google Chrome.app"

## Logged in user
loggedInUser=$( ls -l /dev/console | awk '{print $3}' )


function checkVersion ()
{

## This function runs when an installed version of Chrome is present
## and checks for updates by calling the Google Software Update mechanism.

## Get the version of Google Chrome AFTER running the GoogleSoftwareUpdate command
ChVersAfter=$( defaults read "${appPath}/Contents/Info" CFBundleShortVersionString )

## Shut down the progress bar
exec 10>&-
rm -f /tmp/hpipe

## Check the before and after versions to determine if an update was installed
if [[ "${ChVersBefore}" != "${ChVersAfter}" ]]; then
	echo "Google Chrome was updated from version ${ChVersBefore} to version ${ChVersAfter}"
	"$cdPath" msgbox --title "${MsgTitle}" --text "An update was installed" \
	--informative-text "Your copy of Google Chrome was just updated to version ${ChVersAfter}, and is now up-to-date." \
	--button1 "    OK    " --width 400 --height 150 --posY top --icon info --quiet
else
	echo "There were no new versions of Google Chrome to update to."
	"$cdPath" msgbox --title "${MsgTitle}" --text "No new updates" \
	--informative-text "Looks like your version of Google Chrome, ${ChVersAfter}, is the latest up-to-date version." \
	--button1 "    OK    " --width 400 --height 150 --posY top --icon info --quiet
fi

exit 0

}

function RUNGSU ()
{

exec 10>&-
rm -f /tmp/hpipe
mkfifo /tmp/hpipe
sleep 0.2

"$cdPath" progressbar --indeterminate --title "" --text "Please wait. Checking for updates to your Chrome browser" --width 500 --icon info --icon-height 40 --icon-width 40 --posY top < /tmp/hpipe &

## Send progress through the named pipe
exec 10<> /tmp/hpipe

/bin/launchctl bsexec "${loggedInPID}" sudo -iu "${loggedInUser}" "\"${GSUEXE}\" -runMode oneshot -userInitiated YES \"$@\" 2> /dev/null"

## Run the version check function after checking for updates
checkVersion

}


function findGSU ()
{

## This function runs when an installed version of Google Chrome is installed and attempts to locate the
## Google Software Update framework so we can call it manually

## Get the logged in user, since we will need to check for the GoogleSoftwareUpdate.bundle in their home Library dir
loggedInUser=$( ls -l /dev/console | awk '{print $3}' )
loggedInPID=$( ps -axj | awk "/^$loggedInUser/ && /Dock.app/ {print \$2;exit}" )

## Set the base path to the GoogleSoftwareUpdateAgent
GSUAGENT="Google/GoogleSoftwareUpdate/GoogleSoftwareUpdate.bundle/Contents/Resources/GoogleSoftwareUpdateAgent.app/Contents/MacOS/GoogleSoftwareUpdateAgent"

## Next, check to make sure Chrome is installed on this Mac. For now, we're only looking in Applications

## If its installed, capture the current version, before any update, into a variable
ChVersBefore=$( defaults read "/Applications/Google Chrome.app/Contents/Info" CFBundleShortVersionString )

## Find out if the GoogleSoftwareUpdate agent is located in the current user's Library folder
if [[ -x "/Users/$loggedInUser/Library/${GSUAGENT}" ]]; then
	echo "Agent found in current user Library directory"
	## Set the full path to the executable if found
	GSUEXE="/Users/$loggedInUser/Library/${GSUAGENT}"
	## Run the update function
	RUNGSU
else
	## If not in the user's Library folder, check the main one
	echo "Agent not found in user Library directory"
	if [[ -x "/Library/${GSUAGENT}" ]]; then
		echo "Agent found in root Library directory"
		## Set the full path to the executable if found
		GSUEXE="/Library/${GSUAGENT}"
		## Run the update function
		RUNGSU
	else
		## No agent found, so we exit
		"${cdPath}" msgbox --title "${MsgTitle}" --text "Google Software Update not found" \
		--informative-text "Oops. It looks like we couldn't locate the Google Software Updater on your Mac. We'll need to download the latest version and install it instead." \
		--button1 "    OK    " --width 400 --height 150 --posY top --icon info
		echo "No GoogleSoftwareUpdate agent was found. Alerting user and moving to dlLatest function..."
		dlLatest
	fi
fi

}


function cleanUpAction_Success ()
{

## Description: This function runs on a successful installation of the app.
## It will display a successful message to the user and clean up the downloaded files and other items as necessary.

headText="Installation successful"
mainText="The installation of ${properName} was successful. The version installed was ${updatedVers}."

## Delete the downloaded disk image
rm -Rf "/Library/Application Support/ITUpdater/Downloads/${properName}.dmg"

## If there is a renamed application bundle...
if [[ -d "${appPath}_old" ]]; then
	## delete it now that the new version is installed
	rm -Rfd "${appPath}_old"
fi

## Show the successful install message to the end user
"$cdPath" msgbox --title "${MsgTitle}" --text "$headText" --informative-text "$mainText" \
--button1 "    OK    " --width 400 --posY top --icon info --quiet

## If the app was running during installation send up a message alerting user to relaunch it.
#if [[ "$appRunning" ]]; then
#	wasOpenMsg="${properName} was just updated to version ${currVers}. The application was running during the upgrade. Please close ${properName} and relaunch it to start using the new version."
#	"$cdPath" msbox --title "${MsgTitle}" --text "${properName} was updated" \
#	--informative-text "$wasOpenMsg" --button1 "    OK    " \
#	--width 400 --posY top --icon info --quiet
#	exit $exit_status
#else
#	exit $exit_status
#fi

}


function cleanUpAction_Failure ()
{

## Description: This function runs on a failed installation of the app or package.
## It will display a failure message to the user (if SelfService is set) and clean up the downloaded files and other items as necessary.

## Now close the progress bar
exec 20>&-
rm -f /tmp/hpipe

if [[ "$exit_status" == "1" ]]; then
	mainTextFail="The installation of ${properName} has failed. Your original application was left in place.

You can try running the policy again later. If you continue to encounter problems, contact the Help Desk for assistance and mention error code $exit_status"

elif [[ "$exit_status" == "2" ]]; then
	mainTextFail="An installable package couldn't be found in the disk image. It may have been corrupted, or there was a problem with the script that needs to be corrected.

You can try running the policy again later. If you continue to encounter problems, contact the Help Desk for assistance and mention error code $exit_status"

elif [[ "$exit_status" == "3" ]]; then
	mainTextFail="The disk image could not be mounted to install the update. It may have been corrupted during the download.

You can try running the policy again later. If you continue to encounter problems, contact the Help Desk for assistance and mention error code $exit_status."

fi

## Delete the downloaded disk image from /Library/Application Support/ITUpdater/Downloads/
echo "Deleting downloaded disk image..."
rm -f "/Library/Application Support/ITUpdater/Downloads/${properName}.dmg"

## If we previously renamed the target application,
## reset the name and make it visible again
if [[ -d "${appPath}_old" ]]; then
	mv "${appPath}_old" "${appPath}"
	chflags nohidden "${appPath}"
fi

"$cdPath" msgbox --title "${MsgTitle}" --text "Installation failed" --informative-text "$mainTextFail" --button1 "    OK    " --width 400 --height 175 --posY top --icon caution

exit $exit_status

}


function copyAPPUpdate2 ()
{

## Description: This function is called when the specified app is in an app bundle format.
## It gets called from copyAPPUpdate1 and determines if the application is running if the SelfService flag is set..
## If SelfService is set and the app is running, it prompts the user to quit the app before proceeding, or allows the user to cancel the operation.

## Check to see if the application is running
AppProc=$( ps axc | grep -i "${properName}" )

AppOpenText="Please quit ${properName}, then click Continue to proceed with the installation."
if [[ "$AppProc" != "" ]]; then
	echo "0 ${properName} is running..." >&20
	quitAppMsg=$( "$cdPath" msgbox --title "$MsgTitle" --text "${properName} is running" \
	--informative-text "$AppOpenText" --button1 "  Continue  " --button2 "  Cancel  " \
	--width 400 --icon caution --posY center )

	if [[ "$quitAppMsg" == "1" ]]; then
		copyAPPUpdate2
	else
		echo "100 Installation has been cancelled..." >&20
		hdiutil detach -force "${updateVolName}"
		sleep 1
		rm -f "/Library/Application Support/ITUpdater/Downloads/${properName}.dmg"
		exit 0
	fi
else
	echo "0 Checking for existing installation..." >&20
	echo "Renaming any previous installation"
	mv "${appPath}" "${appPath}_old" 2> /dev/null
	chflags hidden "${appPath}_old" 2> /dev/null

	sleep 1

	echo "Copying ${updateAPPName} to /Applications/"

	## Loop while copying app to Applications, calculating percentage complete. Update progress bar
	while read line; do
		if [[ $(echo "$line" | grep "^copying") ]]; then
			dlSize=$(du -sk "/Applications/${updateAPPName}" | awk '{print $1}' 2>/dev/null)
			if [[ ! -z "$dlSize" ]]; then
				pct=$(expr "${dlSize}" \* 100 / "${origSize}") 2>/dev/null
				echo "$pct ${pct}% - Please wait. Installing ${properName}..." >&20
			fi
		fi
	done < <(ditto -V "${updateVolName}/${updateAPPName}" "/Applications/${updateAPPName}" 2>&1)

	sleep 1

	## If the app is not in /Applications/ then the copy failed
	if [[ ! -d "${appPath}" ]]; then
		echo "${properName} app could not be copied to the Applications folder"
		exit_status=1
		cleanUpAction_Failure
	fi

	## Continue if successful
	echo "20 Fixing permissions on the application..." >&20
	sleep 0.5
	echo "Adjusting permissions on ${appPath}, and removing quarantine flag"
	echo "40 Fixing permissions on the application..." >&20
	chown -R root:admin "${appPath}"
	chmod -R 755 "${appPath}"
	if [[ $(xattr -l "${appPath}" | grep "com.apple.quarantine") ]]; then
		echo "Removing quarantine flag on ${appPath}"
		xattr -d com.apple.quarantine "${appPath}"
	fi
	sleep 0.5
	echo "60 Checking application..." >&20
	sleep 0.5
	echo "80 Installation complete. Please wait..." >&20
	sleep 0.5
	echo "Install done. Cleaning up..."
	echo "90 Cleaning up..." >&20
	echo "Unmounting volume..."
	hdiutil detach -force "${updateVolName}"
	sleep 0.5
	echo "100 Checking new version for ${prpperName}..." >&20
	sleep 0.4
fi

## Get the new version number from disk
updatedVers=$( /usr/bin/defaults read "${appPath}/Contents/Info.plist" CFBundleShortVersionString )
	

## Now close the progress bar
exec 20>&-
rm -f /tmp/hpipe

cleanUpAction_Success

}


function copyAPPUpdate1 ()
{

## Description: This function is called when the specified app is in an app bundle format.
## It first mounts the disk image, gets the application size, and then calls function copyAPPUpdate2.

errNoMount="The installation of ${properName} failed. The error was:

	Disk image mount failed
	
Please try running the policy again."

errNoAppBundle="The installation of ${properName} failed. The error was:

	App bundle not found in disk image

Please try running the policy again."


echo "Silently mounting the ${properName} disk image..."

echo "0 Accessing downloaded file..." >&20

## Mount the disk image and capture the mounted volume's name
updateVolName=$( /usr/bin/hdiutil attach "/Library/Application Support/ITUpdater/Downloads/${properName}.dmg" -nobrowse -noverify -noautoopen 2>&1 | awk -F'[\t]' '/\/Volumes/{ print $NF }' )

if [ "$?" == "0" ]; then
	## Get the package name in the mounted disk image
	updateAPPName=$( ls "$updateVolName" | grep ".app$" | grep -i "${properName}" )

	if [[ ! -z "$updateAPPName" ]]; then
		echo "A matching app bundle was found on the mounted volume - ${updateAPPName}"	
		echo "0 Checking application..." >&20
		origSize=$(du -sk "${updateVolName}/${updateAPPName}" | awk '{print $1}')

		echo "0 Checking active applications..." >&20
		copyAPPUpdate2
	else
		echo "Mounting of the disk image failed. Exit"
		exec 20>&-
		rm -f /tmp/hpipe
		"$cdPath" msgbox --title "${MsgTitle}" --text "Installation failed" \
		--informative-text "$errNoMount" \
		--button1 "    OK    " --icon caution --width 400
		exit 1
	fi
else
	echo "Couldn't locate an app bundle on the mounted volume. Exiting..."
	exec 20>&-
	rm -f /tmp/hpipe
	"$cdPath" msgbox --title "${MsgTitle}" --text "Installation failed" \
	--informative-text "$errNoAppBundle" \
	--button1 "    OK    " --icon caution --width 400
	exit 1
fi

}


function dlLatest ()
{


errNoDwnld="The installation of ${properName} failed. The error was:

	Installation could not be downloaded

Please try running the policy again."

## Description: This function is used to download the current, or latest version of the specified product.
## This function gets the download_url string passed to it and uses curl to pull down the update into
## the "/Library/Application Support/ITUpdater/Downloads/" directory
	
rawSize=$(curl -sI "${download_url}" | awk '/Content-Length/{print $NF}' | tail -1 | tr -cd [:digit:])
adjSize=$(expr ${rawSize} / 1024)

## Set up progress bar elements
exec 20>&-
rm -f /tmp/hpipe
mkfifo /tmp/hpipe
sleep 0.2

## Set up the progress bar
"$cdPath" progressbar --title "" --text " Please wait. Downloading the latest ${properName}..." --width 500 \
--posY top --float --icon-file "$dmg_icon" --icon-height 40 --icon-width 40 < /tmp/hpipe &

## Wait just a half sec
sleep 0.5

## Send progress through the named pipe
exec 20<> /tmp/hpipe

## Start the download and push the process to the background
curl -sf "${download_url}" -o "/Library/Application Support/ITUpdater/Downloads/${properName}.dmg" &

## Wait a moment before beginning calculations
sleep 0.5

## Loop while DMG download is taking place, calculating percentage complete. Update progress bar
pct=0

while [[ "$pct" -lt 100 ]]; do
	sleep 0.2
	dlSize=$(du -hk "/Library/Application Support/ITUpdater/Downloads/${properName}.dmg" | awk '{print $1}' 2>/dev/null)
	if [ "$dlSize" != "" ]; then
		pct=$(expr ${dlSize} \* 100 / ${adjSize})
		echo "$pct ${pct}% - Please wait. Downloading the latest ${properName}..." >&20
	fi
done

sleep 0.7

if [[ -e "/Library/Application Support/ITUpdater/Downloads/${properName}.dmg" ]]; then
	echo "Download of ${properName}.dmg was successful"
	## Begin the copy function
	copyAPPUpdate1
else
	echo "Download of ${properName}.dmg failed. Exiting..."
	## Shutting down the progress bar
	exec 20>&-
	rm -f /tmp/hpipe
	## Show download failure message
	"$cdPath" msgbox --title "${MsgTitle}" --text "Installation failed" \
	--informative-text "$errNoDwnld" \
	--button1 "    OK    " --icon caution --width 400
	exit 1
fi

}


## Start of script

## Create the ITUpdater directory if it doesn't exist
if [[ ! -d "/Library/Application Support/ITUpdater/" ]]; then
	mkdir "/Library/Application Support/ITUpdater/"
fi

## Create the Downloads directory if it doesn't exist
if [[ ! -d "/Library/Application Support/ITUpdater/Downloads/" ]]; then
	mkdir "/Library/Application Support/ITUpdater/Downloads/"
fi

if [ -d "${appPath}" ]; then
	echo "Google Chrome is already installed in the main Applications folder"
	
	checkUpdt=$( "$cdPath" msgbox --title "${MsgTitle}" --text "Google Chrome is already installed" \
	--informative-text "Chrome is already installed on this Mac, so we'll check for updates instead of re-downloading it." \
	--button1 "    OK    " --button2 " Cancel " --cancel "button2" --icon info --width 400 --posY top --timeout 15 )
	if [ "$checkUpdt" -lt "2" ]; then
		findGSU
	else
		echo "User cancelled checking for an updated version"
		exit 0
	fi
else
	dlLatest
fi
