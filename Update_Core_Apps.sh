#!/bin/bash

## Script name:		Update_Core_Apps.sh
## Script author:	Mike Morales
## Last updated:	2015-01-04
##
## NOTES:
## This script will only work with Intel Macs.
## If necessary, the script dynamically builds a Safari User Agent string
## based on the client system to use when checking against some pages.

## EDITABLE VARIABLES BELOW

## Path to cocoaDialog and jamfHelper (Edit path to cocoaDialog to match your environment)
cdPath="/Library/Application Support/JAMF/bin/cocoaDialog.app/Contents/MacOS/cocoaDialog"
#cdPath="//Applications/Utilities/cocoaDialog.app/Contents/MacOS/cocoaDialog"
jhPath="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

## The following variable can be hardcoded into the script to set whether new installs should take place
## on Macs that may not have the specified app or plug-in, or if we should only be updating an existing
## installation. Set the variable to "Yes" if you would like new installs to occur. Comment out the entire line
## or set the string to blank ("") if you would like to skip new installations.
##
## Note that the one exception is Office 2011 updates, because these are only updaters for an
## existing installation, and not full installs.

installNew="Yes"

## The common title bar string to use in all cocoaDialog messages (Primarily applies when SelfService is set)
MsgTitle="IT - Application Updater"

## END - EDITABLE VARIABLES

## Do not edit the script below this line unless changing any of the cocoaDialog message strings

function showHelp ()
{

## This function gets called if no paramater is passed to the script. It outputs a brief 'help' page to stdout.
## The help printout will show up in the policy log.

## Set up Terminal formatting variables
header=$(tput sgr 0 1)$(tput bold)$(tput setaf 25)
normal=$(tput sgr0)
tabs -25

echo "
Update_Core_Apps.sh - usage


${header}App or Plug-In To Update				
${normal}For this script to function, parameter 4 (\$4) must be passed to the script.
The following items can be updated or installed new by passing a valid parameter to it.
The table below shows the application or plug-in and corresponding valid strings
(All strings are case insensitive):

${header}App or Plug-In Name	Accepted strings			
${normal}Java 7/8	\"Java\", \"Oracle Java\"
Flash Player	\"Flash\", \"FlashPlayer\", \"Flash Player\", \"Adobe Flash\", \"AdobeFlash\"
Silverlight	\"Silverlight\", \"SL\"
Flip Player	\"FlipPlayer\", \"Flip Player\", \"WMV Player\", \"Flip4Mac Player\", \"Flip4MacPlayer\"
Firefox	\"Firefox\", \"FF\"
Firefox ESR	\"FirefoxESR\", \"FFESR\"
VLC	\"VLC\", \"VLC Media Player\"
Adobe Reader	\"Reader\", \"Adobe Reader\", \"AdobeReader\"

The following can only be UPDATED with this script using the below parameter strings:
Office 2011	\"MSO\", \"Office\", \"Office 2011\", \"Office2011\",\"MS Office\", \"MSOffice\"

${header}'Silent' and 'Self Service' modes			
${normal}This script is run in a silent mode in its default state. Silent mode will auto update the specified app or plug-in (assuming an update is available) and report on the results.

The script can also be run in a Self Service mode by passing any value to parameter 5 (\$5).
Self Service mode will show dialogs and progress bars to the current user as it downloads and installs the current version of the application or Plug-In.${normal}
" | fold -s -w 100

}


## Get the assigned app or plug-in name from parameter 4
## Exit the script with an error if its blank
if [ "$appName" == "" ] && [ "$4" != "" ]; then
	appName="$4"
else
	echo "No application or plug-in name was assigned to parameter 4. Printing help page..."
	showHelp
	exit 1
fi

## Determine if this script should be used in a Self Service mode.
## Usage: If $5 is set to any value in the script parameter, then we set a new "SelfService" variable and
## use Self Service dialogs and prompts throughout the process when required.
## If $5 is not assigned, we assume the script is to be run in "Silent" mode
## Note: to use the script explicitly in Silent Mode, do not assign parameter 5.

if [ "$5" != "" ]; then
	SelfService="Yes"
	echo "
[Mode]: Self Service"
else
	echo "
[Mode]: Silent"
fi

## Get the logged in user's name
loggedInUser=$( ls -l /dev/console | awk '{print $3}' )

## Sanity check for the existence of cocoaDialog. Only checks when SelfService flag is set.
if [ "$SelfService" ]; then
	if [ ! -f "$cdPath" ]; then
		echo "cocoaDialog was not found on this Mac and the SelfService flag was set. We can't continue..."
		if [ "$SelfService" ]; then
			"$jhPath" -windowType utility -title "IT" -heading "A problem occurred" -alignHeading center \
			-description "A necessary component was not found on this Mac. Please allow up to 24 hours for the situation to correct itself and try again." \
			-button1 "OK" -icon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertCautionIcon.icns"
		fi
		exit 1
	fi
fi

## Create the necessary folder structure for downloads
if [ ! -d "/Library/Application Support/ITUpdater/Downloads/" ]; then
	mkdir -p "/Library/Application Support/ITUpdater/Downloads/"
fi

## List of base check URLs
javaCheckURL="http://java.com/en/download/mac_download.jsp"
flashCheckURL="http://fpdownload2.macromedia.com/get/flashplayer/update/current/xml/version_en_mac_pl.xml"
firefoxCheckURL="http://download-origin.cdn.mozilla.net/pub/mozilla.org/firefox/releases/latest/mac/en-US/"
firefoxESRCheckURL="http://download-origin.cdn.mozilla.net/pub/mozilla.org/firefox/releases/latest-esr/mac/en-US/"
flipPlayerCheckURL="http://www.telestream.net/flip-player/download.htm?keepThis=true&TB_iframe=true&height=420&width=520"
silLightCheckURL="http://www.microsoft.com/getsilverlight/locale/en-us/html/Microsoft%20Silverlight%20Release%20History.htm"
VLCCheckURL="http://update.videolan.org/vlc/sparkle/vlc-intel64.xml"
adbeRdrCheckURL="http://get.adobe.com/reader/"
MSOfficeCheckURL="http://www.microsoft.com/mac/autoupdate/0409MSOf14.xml"


## Case statement to set proper URLs, application/plug-in paths and function calls
shopt -s nocasematch

case "$appName" in
	Java|"Oracle Java")
		properName="Oracle Java"					## Edit this to change the name that appears in dialogs
		installerString="java"
		type="Plug-In"
		installType="PKG"
		URL="${javaCheckURL}"
		appPath="/Library/Internet Plug-Ins/JavaAppletPlugin.plugin"
		runFunc="getJavaVersion"
		curlFlag="-L"
		versProcessor="cut -d. -f1,2,3"
		UAReq="Yes"
		CFVers="CFBundleVersion"
		iconType="--icon" 
		iconFile="package" ;;
	FlashPlayer|Flash|"Flash Player")
		properName="Flash Player"					## Edit this to change the name that appears in dialogs
		installerString="flash"
		type="Plug-In"
		installType="PKG"
		URL="${flashCheckURL}"
		appPath="/Library/Internet Plug-Ins/Flash Player.plugin"
		runFunc="getFlashVersion"
		UAReq="No"
		CFVers="CFBundleShortVersionString"
		iconType="--icon"
		iconFile="package" ;;
	Silverlight|SL)
		properName="Silverlight"					## Edit this to change the name that appears in dialogs
		installerString="silverlight"
		type="Plug-In"
		installType="PKG"
		URL="${silLightCheckURL}"
		appPath="/Library/Internet Plug-Ins/Silverlight.plugin"
		runFunc="getSilverlightVersion"
		UAReq="Yes"
		CFVers="CFBundleShortVersionString"
		iconType="--icon"
		iconFile="package" ;;
	FlipPlayer|"Flip Player"|"WMV Player"|"Flip4Mac Player"|Flip4MacPlayer)
		properName="Flip Player"					## Edit this to change the name that appears in dialogs
		installerString="flip player"
		type="application"
		installType="APP"
		URL="${flipPlayerCheckURL}"
		appPath="/Applications/Flip Player.app"
		runFunc="getFlipPlayerVersion"
		versProcessor="cut -d. -f1,2,3"
		UAReq="No"
		CFVers="CFBundleShortVersionString"
		iconType="--icon-file"
		iconFile="/System/Library/CoreServices/DiskImageMounter.app/Contents/Resources/diskcopy-doc.icns" ;;
	Firefox|FF)
		properName="Firefox"						## Edit this to change the name that appears in dialogs
		installerString="firefox"
		type="browser"
		installType="APP"
		URL="${firefoxCheckURL}"
		appPath="/Applications/Firefox.app"
		runFunc="getFirefoxVersion"
		UAReq="No" 
		CFVers="CFBundleShortVersionString"
		iconType="--icon-file"
		iconFile="/System/Library/CoreServices/DiskImageMounter.app/Contents/Resources/diskcopy-doc.icns" ;;
	FirefoxESR|FFESR)
		properName="Firefox ESR"					## Edit this to change the name that appears in dialogs
		installerString="firefox"
		type="browser"
		installType="APP"
		URL="${firefoxESRCheckURL}"
		appPath="/Applications/Firefox.app"
		runFunc="getFirefoxVersion"
		UAReq="No" 
		CFVers="CFBundleShortVersionString"
		iconType="--icon-file"
		iconFile="/System/Library/CoreServices/DiskImageMounter.app/Contents/Resources/diskcopy-doc.icns" ;;
	VLC|"VLC Media Player")
		properName="VLC"							## Edit this to change the name that appears in dialogs
		installerString="vlc"
		type="application"
		installType="APP"
		URL="${VLCCheckURL}"
		appPath="/Applications/VLC.app"
		runFunc="getVLCVersion"
		curlFlag="-L"
		UAReq="No"
		CFVers="CFBundleShortVersionString"
		iconType="--icon-file"
		iconFile="/System/Library/CoreServices/DiskImageMounter.app/Contents/Resources/diskcopy-doc.icns" ;;
	Reader|"Adobe Reader"|AdobeReader)
		properName="Adobe Reader"					## Edit this to change the name that appears in dialogs
		installerString="reader"
		type="application"
		installType="PKG"
		URL="${adbeRdrCheckURL}"
		appPath="/Applications/Adobe Reader.app"
		runFunc="getRdrVersion"
		UAReq="Yes"
		CFVers="CFBundleShortVersionString"
		iconType="--icon"
		iconFile="package" ;;
	MSO|Office|"Office 2011"|Office2011|"MS Office"|MSOffice)
		properName="Office 2011"					## Edit this to change the name that appears in dialogs
		installerString="office 2011"
		type="suite"
		installType="PKG"
		URL="${MSOfficeCheckURL}"
		appPath="/Applications/Microsoft Office 2011/Office/Microsoft Database Daemon.app"
		runFunc="getOfficeVersion"
		UAReq="No"
		CFVers="CFBundleShortVersionString"
		iconType="--icon"
		iconFile="package" ;;
	*)
		echo -e "The application, suite or plug-in specified ( ${appName} ) has no reference in this script.\nPlease check your entry and try again."
		exit 1
esac

shopt -u nocasematch


firstChar=${properName:0:1}

case "$firstChar" in
	A|E|I|O|U)
	art="An" ;;
	*)
	art="A" ;;
esac


function emailOnInstallError ()
{

macName=$(scutil --get ComputerName)

echo "$art ${properName} ${currVers} update failed to install on ${macName}. Please check the script for errors" | mail -s "$art ${properName} ${currVers} update failed to install" morales2270@gmail.com

exit $exitstatus

}


function cleanUpAction_Success ()
{

## Description: This function runs on a successful installation of the app or package.
## It will display a successful message to the user and clean up the downloaded files and other items as necessary.

## Now close the progress bar (if necessary)
exec 20>&-
rm -f /tmp/hpipe

if [[ "$updateMode" == "update" ]]; then
	headText="The ${properName} update was successful"
	mainText="The update for ${properName} was installed successfully. The version installed is now ${updatedVers}."
elif [[ "$updateMode" == "new" ]]; then
	headText="The ${properName} installation was successful"
	mainText="The installation of ${properName} was successful. The version installed was ${updatedVers}."
fi

## Set up different messaging if we just installed an Office update and at least one of the apps was running
MSOAppsOpen=$(ps axc | awk -F'[0-9] ' '/Microsoft Word|Microsoft Excel|Microsoft PowerPoint|Microsoft Outlook|My Day|Microsoft Office Reminders/{print $NF}')

if [[ "${properName}" == "Office 2011" ]]; then
	if [[ "$SelfService" ]] && [[ ! -z "$MSOAppsOpen" ]]; then
		headText="The ${properName} update was successful"
		mainText="The update for ${properName} was installed successfully. The version installed is now ${updatedVers}.

The following applications were open during the installation. You should quit and relaunch these apps at your earliest convenience to begin using the new version:

$MSOAppsOpen"
	else
		if [[ "$SelfService" ]] && [[ -z "$MSOAppsOpen" ]]; then
			headText="Your ${properName} ${type} was just updated"
			mainText="${properName} on your Mac was just updated to version ${updatedVers}."
		fi
	fi
fi

rm -Rf /Library/Application\ Support/ITUpdater/Downloads/*
rm -f "/Library/Application Support/ITUpdater/NoQuit.xml" 2>/dev/null

## If there is a renamed application bundle, delete it now that the new version is installed
if [ -d "${appPath}_old" ]; then
	## Delete the older renamed application
	rm -Rfd "${appPath}_old"
fi

## First message
if [ "$SelfService" ]; then
	## Show the successful install message to the end user
	"$cdPath" msgbox --title "${MsgTitle}" --text "$headText" --informative-text "$mainText" \
	--button1 "    OK    " --width 400 --posY top --icon info --quiet

	exit $exit_status
fi

## If SelfService was not set but the app was running during installation,
## send up a message alerting user to relaunch it.
## Not dependent on cocoaDialog being installed. Will use jamfHelper if necessary.
if [[ ! "$SelfService" ]] && [[ "$appRunning" ]]; then
	wasOpenMsg="${properName} was just updated to version ${currVers}. The application was running during the upgrade. Please close ${properName} and relaunch it to start using the new version."
	if [ -e "$cdPath" ]; then
		"$cdPath" msgbox --title "${MsgTitle}" --text "${properName} was updated" \
		--informative-text "$wasOpenMsg" --button1 "    OK    " \
		--width 400 --posY top --icon info --quiet

		exit $exit_status
	else
		"$jhPath" -windowType utility -title "${MsgTitle}" -description "$wasOpenMsg" -button1 "OK" -defaultButton 1 -icon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarInfo.icns"
		exit $exit_status
	fi
else
	if [[ ! "$SelfService" ]]; then
		if [[ "${properName}" == "Office 2011" ]] && [[ ! -z "$MSOAppsOpen" ]]; then
			if [ -e "$cdPath" ]; then
				"$cdPath" msgbox --title "${MsgTitle}" --text "${headText}" \
				--informative-text "${mainText}" --button1 "   OK   " --width 400 \
				--posY top --icon info --quiet

				exit $exit_status
			else
				"$jhPath" -windowType utility -title "${MsgTitle}" -heading "${headText}" -description "${mainText}" -button1 "OK" -defaultButton 1 -icon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarInfo.icns"

				exit $exit_status
			fi
		else
			exit $exit_status
		fi
	fi
fi

}


function cleanUpAction_Failure ()
{

## Description: This function runs on a failed installation of the app or package.
## It will display a failure message to the user (if SelfService is set) and clean up the downloaded files and other items as necessary.

## Now close the progress bar (if necessary)
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

if [[ "${properName}" == "Office 2011" ]]; then
	## If there are Office 2011 update(s), delete contents of Downloads directory and xml file
	echo "Deleting downloaded disk image(s) and xml file..."
	rm -Rfd "/Library/Application Support/ITUpdater/Downloads/*"
	rm -f "/Library/Application Support/ITUpdater/NoQuit.xml"
else
	## Delete the downloaded disk image from /Library/Application Support/ITUpdater/Downloads/
	echo "Deleting downloaded disk image..."
	rm -f "/Library/Application Support/ITUpdater/Downloads/${properName}_${currVers}.dmg"
fi

## If we previously renamed the target application,
## reset the name and make it visible again
if [[ -d "${appPath}_old" ]]; then
	mv "${appPath}_old" "${appPath}"
	chflags nohidden "${appPath}"
fi

if [ "$SelfService" ]; then
	"$cdPath" msgbox --title "${MsgTitle}" --text "Installation failed" --informative-text "$mainTextFail" \
	--button1 "    OK    " --width 400 --posY top --icon caution --quiet
fi

## Uncomment the below line to have the script exit without sending out an error email
#exit $exit_status

emailOnInstallError

}


function getNewVers ()
{

## Description: This function is called at the end of an installation to check the new version number
## to ensure it is what we expect. The function will call another function based on success or failure results.

let StepNum=$StepNum+1
if [ "$updateMode" == "update" ]; then
	echo "[Stage ${StepNum}]: ${properName} update installation was successful. Checking new version for confirmation..."
elif [ "$updateMode" == "new" ]; then
	echo "[Stage ${StepNum}]: ${properName} installation was successful. Checking installed version for confirmation..."
fi

## Get the new version number from disk to ensure it matches the expected current version
updatedVers=$( /usr/bin/defaults read "${appPath}/Contents/Info.plist" ${CFVers} )

## If the assigned application has a versProcessor var assigned, run it to generate a modified version string
if [ ! -z "$versProcessor" ]; then
	updatedVers=$( eval echo "$updatedVers" | $versProcessor )
fi

if [[ "${updatedVers}" == "${currVers}" ]]; then
	echo "[Final Result]: Confirmed the new version of ${properName} on disk is now ${currVers}..."
	exit_status=0

	cleanUpAction_Success
else
	echo "[Final Result]: New version and latest version do not match. Installation may have failed..."
	exit_status=1

	cleanUpAction_Failure
fi

}


function copyAPPUpdate2 ()
{

## Description: This function is called when the specified app is in an app bundle format.
## It gets called from copyAPPUpdate1 and determines if the application is running if the SelfService flag is set.
## If SelfService is set and the app is running, it prompts the user to quit the app before proceeding, or allows the user to cancel the operation.

## Check to see if the application is running
AppProc=$( ps axc | grep -i "${properName}" )

if [[ "$SelfService" ]]; then
	if [[ "$AppProc" != "" ]]; then
		appOpenText="Please quit ${properName}, then click Continue to proceed with the installation."
		echo "0 ${properName} is running..." >&20
		quitAppMsg=$( "$cdPath" msgbox --title "$MsgTitle" --text "${properName} is running" \
		--informative-text "$appOpenText" --button1 "  Continue  " --button2 "  Cancel  " \
		--width 400 --icon caution --posY center )

		if [[ "$quitAppMsg" == "1" ]]; then
			copyAPPUpdate2
		else
			echo "100 Installation has been cancelled..." >&20
			hdiutil detach -force "${updateVolName}"
			sleep 0.5
			rm -f "/Library/Application Support/ITUpdater/Downloads/${properName}_${currVers}.dmg"
			exit 0
		fi
	else
		## If an existing version of the target app is in the /Applications/ path,
		## rename and hide it before copying in the new version
		if [ -d "${appPath}" ]; then
			echo "0 Removing any previous version..." >&20
			echo "	Renaming previous installation"
			mv "${appPath}" "${appPath}_old" 2> /dev/null
			chflags hidden "${appPath}_old" 2> /dev/null
		fi

		sleep 1

		let StepNum=$StepNum+1
		echo "[Stage ${StepNum}]: Copying ${updateAPPName} to /Applications/"

		## Copy the application to the /Applications/ folder, calculate progress and feed it back to cocoaDialog
		while read line; do
			if [[ $(echo "$line" | grep "^copying") ]]; then
				dlSize=$(du -sk "/Applications/${updateAPPName}" | awk '{print $1}' 2>/dev/null)
				if [ "$dlSize" != "" ]; then
					let pct=$(expr ${dlSize} \* 100 / ${origSize})
				echo "$pct ${pct}% - Please wait. Installing ${properName}..." >&20
				fi
			fi
		done < <(ditto -V "${updateVolName}/${updateAPPName}" "/Applications/${updateAPPName}" 2>&1)

		sleep 1

		if [[ ! -d "${appPath}" ]]; then
			echo "${properName} app could not be copied to the Applications folder"
			exit_status=1
			cleanUpAction_Failure
		fi

		let StepNum=$StepNum+1
		echo "20 Fixing permissions on the application..." >&20
		sleep 0.5
		echo "[Stage ${StepNum}]: Adjusting permissions on ${appPath}, and removing quarantine flag"
		echo "40 Fixing permissions on the application..." >&20
		chown -R ${loggedInUser}:staff "${appPath}"
		chmod -R 755 "${appPath}"
		if [[ $(xattr -l "${appPath}" | grep "com.apple.quarantine") ]]; then
			echo "	Removing quarantine flag on ${appPath}"
			xattr -d com.apple.quarantine "${appPath}"
		fi
		sleep 0.5
		echo "60 Checking application..." >&20
		sleep 0.5
		echo "80 Installation complete. Please wait..." >&20
		sleep 0.5

		let StepNum=$StepNum+1
		echo "[Stage ${StepNum}]: Install done. Cleaning up..."
		echo "90 Cleaning up..." >&20
		echo "	Unmounting volume..."
		hdiutil detach -force "${updateVolName}"
		sleep 0.5
		echo "100 Checking new version for ${prpperName}..." >&20
		
		## Run the function to get the new version number
		getNewVers
	fi
fi

## If SelfService mode is not set, check to see if the target application is open
## Set a flag for later if the app is currently open

if [[ ! "$SelfService" ]]; then
	if [[ "$AppProc" != "" ]]; then
		appRunning="yes"
	fi

	## Copy the application from the mounted disk image to /Applications silently.
	## Note: This will overwrite the application in place, even while running.

	let StepNum=$StepNum+1
	echo "[Stage ${StepNum}]: Copying ${updateAPPName} to /Applications/..."

	cp -R "${updateVolName}/${updateAPPName}" "/Applications/"

	## Check to make sure the copy was successful
	if [[ ! -d "${appPath}" ]]; then
		echo "	${properName} app could not be copied to the Applications folder"
		exit_status=1
		cleanUpAction_Failure
	fi

	let StepNum=$StepNum+1
	echo "[Stage ${StepNum}]: Adjusting permissions on ${appPath}"
	chown -R ${loggedInUser}:staff "${appPath}"
	chmod -R 755 "${appPath}"
	if [[ $(xattr -l "${appPath}" | grep "com.apple.quarantine") ]]; then
		echo "	Removing quarantine flag on ${appPath}"
		xattr -d com.apple.quarantine "${appPath}"
	fi

	let StepNum=$StepNum+1
	echo "[Stage ${StepNum}]: Install done. Cleaning up..."
	echo "	Unmounting volume..."
	hdiutil detach -force "${updateVolName}"
	sleep 0.5
	
	## Run the function to get the new version number
	getNewVers
fi


}


function copyAPPUpdate1 ()
{

## Description: This function is called when the specified app is in an app bundle format.
## It first mounts the disk image, gets the application size, and then calls function copyAPPUpdate2.

let StepNum=$StepNum+1
echo "[Stage ${StepNum}]: Silently mounting the ${properName} disk image..."

if [ "$SelfService" ]; then
	echo "0 Accessing downloaded file..." >&20
fi

## Mount the disk image and capture the mounted volume's name
if [[ "${properName}" == "Flip Player" ]]; then
	updateVolName=$( echo "Y" | /usr/bin/hdiutil attach "/Library/Application Support/ITUpdater/Downloads/${properName}_${currVers}.dmg" -nobrowse -noverify -noautoopen 2>&1 | awk -F'[\t]' '/\/Volumes/{ print $NF }' )
else
	updateVolName=$( /usr/bin/hdiutil attach "/Library/Application Support/ITUpdater/Downloads/${properName}_${currVers}.dmg" -nobrowse -noverify -noautoopen 2>&1 | awk -F'[\t]' '/\/Volumes/{ print $NF }' )
fi
	
if [ "$?" == "0" ]; then
	## Get the package name in the mounted disk image
	updateAPPName=$( ls "$updateVolName" | grep ".app$" | grep -i "${installerString}" )

	if [ "$updateAPPName" ]; then
		echo "	A matching app bundle was found on the mounted volume - ${updateAPPName}"	
		if [ "$SelfService" ]; then
			echo "0 Checking application..." >&20
			origSize=$(du -sk "${updateVolName}/${updateAPPName}" | awk '{print $1}')

			echo "0 Checking to see if ${properName} is running..." >&20
			copyAPPUpdate2
		else
			copyAPPUpdate2
		fi
	else
		echo "	Mounting of the disk image failed. Exit"
		## We need to put some dialog here
		exit 1
	fi
else
	echo "	Couldn't locate an app bundle on the mounted volume. Exiting..."
	## We need to put some dialog here
	exit 1
fi

}


function installPKGUpdate ()
{

## Description: This function is called when the specified app is in a package install format and SelfService is not set.
## It first mounts the disk image, gets the volume name, then proceeds with the installation.

let StepNum=$StepNum+1
echo "[Stage ${StepNum}]: Silently mounting the ${properName} disk image..."

updateVolName=$( /usr/bin/hdiutil attach "/Library/Application Support/ITUpdater/Downloads/${properName}_${currVers}.dmg" -nobrowse -noverify -noautoopen 2>&1 | awk -F'[\t]' '/\/Volumes/{ print $NF }' )

if [[ "$?" == "0" ]]; then
	## Get the package name in the mounted disk image
	updatePKGName=$( ls "$updateVolName" | grep ".pkg$|.mpkg$" | grep -i "${installerString}" )

	if [[ ! -z "${updatePKGName}" ]]; then
		echo "	A package was located in the mounted volume. Getting package details..."

		sleep 1
		
		echo "Installing the ${properName} pkg update..."

		## If the update if for Office 2011, run a separate install loop that uses the NoQuit.xml
		## Check for the successful upgrade line to set the installation status
		if [[ "${properName}" == "Office 2011" ]]; then
			installStatus=1
			while read line; do
				if [[ $( echo "$line" | egrep "The upgrade was successful|The install was successful" ) ]]; then
					installStatus=0
				fi
			done < <(/usr/sbin/installer -pkg "${updateVolName}/${updatePKGName}" -tgt / -allowUntrusted -applyChoiceChangesXML "/Library/Application Support/ITUpdater/NoQuit.xml" -verboseR 2>&1)
		else
			## Install the pkg while reading output from installer
			## Check for the successful upgrade line to set the installation status
			installStatus=1
			while read line; do
				if [[ $( echo "$line" | egrep "The upgrade was successful|The install was successful" ) ]]; then
					installStatus=0
				fi
			done < <(/usr/sbin/installer -pkg "${updateVolName}/${updatePKGName}" -tgt / -allowUntrusted -verboseR 2>&1)
		fi
		
		## Pause 1 second to allow installation to finish out
		sleep 1

		## Unmount the volume (use -force flag in case of locked files)
		hdiutil detach "${updateVolName}" -force

		## Now check the installation results
		if [[ "$installStatus" == "0" ]]; then
			## Get the new version number
			getNewVers
		else
			## If we didn't get a status 0 returned from the installation, exit with an error code
			echo "Installation exited with an error code. Install failed..."
			exit_status=1

			cleanUpAction_Failure
		fi
	else
		echo "Could not locate the package in the mounted volume. There was a problem."
		exit_status=2

		cleanUpAction_Failure
	fi
else
	echo "Mounting of the disk image failed. Exit"
	exit_status=3

	cleanUpAction_Failure
fi

}


function installMSOUpdatesSS ()
{

## Description: This function is called when the application to be updated is Office 2011
## and the update requires both SP1 and the latest update, and the SelfService flag is set..
## This function loops through the installs, displaying status of each one.

## Create array with the DMG names
while read item; do
	MSODMGs+=("$item")
done < <(ls "/Library/Application Support/ITUpdater/Downloads/" | grep ".dmg$")

for DMG in "${MSODMGs[@]}"; do

	let StepNum=$StepNum+1
	echo "[Stage ${StepNum}]: Silently mounting the ${DMG} disk image..."
	echo "0 Accessing downloaded file..." >&20
	
	updateVolName=$( /usr/bin/hdiutil attach "/Library/Application Support/ITUpdater/Downloads/$DMG" -nobrowse -noverify -noautoopen 2>&1 | awk -F'[\t]' '/\/Volumes/{ print $NF }' )

	if [[ "$?" == "0" ]]; then
		## Get the package name in the mounted disk image
		updatePKGName=$( ls "$updateVolName" | egrep ".pkg$|.mpkg" | grep -i "${installerString}" )

		if [[ ! -z "${updatePKGName}" ]]; then
			echo "	A package was located in the mounted volume. Getting package details..."
			
			sleep 1
			echo "0 Preparing for installation..." >&20
			
			let StepNum=$StepNum+1
			echo "[Stage ${StepNum}]: Installing the ${properName} pkg update..."
			
			sleep 1
			
			## Install the pkg while reading output from installer
			## Check for the successful upgrade line to set the installation status
			installStatus=1
			while read line; do
				## Get updated percentage from current installation and send to progressbar
				thePct=$( echo "$line" | awk -F"%" '/%/{ print $2 }' | cut -d. -f1 | sed '/^$/d' )
				echo "$thePct ${thePct}% - Installing \"${updatePKGName}\"" >&20
				if [[ $( echo "$line" | egrep "The upgrade was successful|The install was successful" ) ]]; then
					installStatus=0
				fi
			done < <(/usr/sbin/installer -pkg "${updateVolName}/${updatePKGName}" -tgt / -allowUntrusted -applyChoiceChangesXML "/Library/Application Support/ITUpdater/NoQuit.xml" -verboseR 2>&1)

			## Pause 1 second to allow installation to finish out
			sleep 1
			## Unmount the volume (use -force flag in case of locked files)
			hdiutil detach "${updateVolName}" -force
			
		else
			echo "	Mounting of the disk image failed. Exit"
			## We need to put some dialog here
			exit_status=3
			
			cleanUpAction_Failure
		fi
	fi
done

sleep 1
## Now close the progress bar
exec 20>&-
rm -f /tmp/hpipe

## Now check the installation results
if [[ "$installStatus" == "0" ]]; then
	## Get the new version number
	getNewVers
else
	## If we didn't get a status 0 returned from the installation, exit with an error code
	echo "Installation exited with an error code. Install failed..."
	exit_status=1

	cleanUpAction_Failure
fi

}


function installMSOUpdates ()
{

## Description: This function is called when the application to be updated is Office 2011
## and the update requires both SP1 and the latest update, and the SelfService flag is not set.
## This function loops through the installs, checks for successful installation for each
## and finally checks the resulting version to ensure the application was updated.

## Create array with the DMG names
while read item; do
	MSODMGs+=("$item")
done < <(ls "/Library/Application Support/ITUpdater/Downloads/" | grep ".dmg$")

for DMG in "${MSODMGs[@]}"; do

	let StepNum=$StepNum+1
	echo "[Stage ${StepNum}]: Silently mounting the ${DMG} disk image..."
		
	updateVolName=$( /usr/bin/hdiutil attach "/Library/Application Support/ITUpdater/Downloads/$DMG" -nobrowse -noverify -noautoopen 2>&1 | awk -F'[\t]' '/\/Volumes/{ print $NF }' )

	if [[ "$?" == "0" ]]; then
		## Get the package name in the mounted disk image
		updatePKGName=$( ls "$updateVolName" | egrep ".pkg$|.mpkg" | grep -i "${installerString}" )

		if [[ ! -z "${updatePKGName}" ]]; then
			echo "	A package was located in the mounted volume. Getting package details..."

			sleep 1
			
			let StepNum=$StepNum+1
			echo "[Stage ${StepNum}]: Installing the ${properName} pkg update..."

			## Install the pkg while reading output from installer
			## Check for the successful upgrade line to set the installation status
			installStatus=1
			while read line; do
				if [[ $( echo "$line" | egrep "The upgrade was successful|The install was successful" ) ]]; then
					installStatus=0
				fi
			done < <(/usr/sbin/installer -pkg "${updateVolName}/${updatePKGName}" -tgt / -allowUntrusted -applyChoiceChangesXML "/Library/Application Support/ITUpdater/NoQuit.xml" -verboseR 2>&1)

			## Pause 1 second to allow installation to finish out
			sleep 1
			## Unmount the volume (use -force flag in case of locked files)
			hdiutil detach "${updateVolName}" -force
			
		else
			echo "Mounting of the disk image failed. Exit"
			## We need to put some dialog here
			exit_status=3
			
			cleanUpAction_Failure
		fi
	fi
done

## Now check the installation results
if [[ "$installStatus" == "0" ]]; then
	## Get the new version number
	getNewVers
else
	## If we didn't get a status 0 returned from the installation, exit with an error code
	echo "Installation exited with an error code. Install failed..."
	exit_status=1

	cleanUpAction_Failure
fi

}


function installPKGUpdateSS ()
{

## Description: This function is called when the specified app is in a package install format and the SelfService flag is set.
## It first mounts the disk image, gets the volume name, the enclosed pkg name, then proceeds with the installation.

let StepNum=$StepNum+1
echo "[Stage ${StepNum}]: Silently mounting the ${properName} disk image..."

echo "0 Accessing downloaded file..." >&20

updateVolName=$( /usr/bin/hdiutil attach "/Library/Application Support/ITUpdater/Downloads/${properName}_${currVers}.dmg" -nobrowse -noverify -noautoopen 2>&1 | awk -F'[\t]' '/\/Volumes/{ print $NF }' )

if [[ "$?" == "0" ]]; then
	## Get the package name in the mounted disk image
	updatePKGName=$( ls "$updateVolName" | egrep ".pkg$|.mpkg$" | grep -i "${installerString}" )

	if [[ ! -z "${updatePKGName}" ]]; then
		echo "	A package was located in the mounted volume. Getting package details..."

		sleep 1

		echo "0 Preparing for installation..." >&20
		
		let StepNum=$StepNum+1
		echo "[Stage ${StepNum}]: Beginning package installation..."

		sleep 1
		
		## If the update if for Office 2011, run a separate install loop that uses the NoQuit.xml
		## Check for the successful upgrade line to set the installation status
		if [[ "${properName}" == "Office 2011" ]]; then
			installStatus=1
			while read line; do
				## Get updated percentage from current installation and send to progressbar
				thePct=$( echo "$line" | awk -F"%" '/%/{ print $2 }' | cut -d. -f1 | sed '/^$/d' )
				echo "$thePct ${thePct}% - Installing \"${updatePKGName}\"" >&20
				if [[ $( echo "$line" | egrep "The upgrade was successful|The install was successful" ) ]]; then
					installStatus=0
				fi
			done < <(/usr/sbin/installer -pkg "${updateVolName}/${updatePKGName}" -tgt / -allowUntrusted -applyChoiceChangesXML "/Library/Application Support/ITUpdater/NoQuit.xml" -verboseR 2>&1)
		
		else
			
			## Install the pkg while reading output from installer
			## Check for the successful upgrade line to set the installation status
			installStatus=1
			while read line; do
				## Get updated percentage from current installation and send to progressbar
				thePct=$( echo "$line" | awk -F"%" '/%/{ print $2 }' | cut -d. -f1 | sed '/^$/d' )
				echo "$thePct ${thePct}% - Installing \"${updatePKGName}\"" >&20
				if [[ $( echo "$line" | egrep "The upgrade was successful|The install was successful" ) ]]; then
					installStatus=0
				fi
			done < <(/usr/sbin/installer -pkg "${updateVolName}/${updatePKGName}" -tgt / -allowUntrusted -verboseR 2>&1)
		fi
		## Pause 1 second to allow installation to finish out
		sleep 1

		## Now close the progress bar
		exec 20>&-
		rm -f /tmp/hpipe

		## Unmount the volume (use -force flag in case of locked files)
		hdiutil detach "${updateVolName}" -force

		## Now check the installation results
		if [[ "$installStatus" == "0" ]]; then
			## Get the new version number
			getNewVers
		else
			## If we didn't get a status 0 returned from the installation, exit with an error code
			echo "	Installation exited with an error code. Install failed..."
			exit_status=1

			cleanUpAction_Failure
		fi
	else
		echo "	Could not locate the package in the mounted volume. There was a problem."
		## We need to put some dialog here
		exit_status=2

		cleanUpAction_Failure
	fi
else
	echo "	Mounting of the disk image failed. Exit"
	## We need to put some dialog here
	exit_status=3

	cleanUpAction_Failure
fi

}


function dlMSOUpdates ()
{

## Description: This function is called if the application being updated is Office 2011
## and the Mac requires both SP1 and the latest update to be downloaded and installed

## Generate a NoQuit.xml to be used later in the install phase
echo '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
<dict>
<key>attributeSetting</key>
<integer>0</integer>
<key>choiceAttribute</key>
<string>selected</string>
<key>choiceIdentifier</key>
<string>quit</string>
</dict>
</array>
</plist>' > "/Library/Application Support/ITUpdater/NoQuit.xml"

## Get the MSO SP1 Update name
SP1UpdateLoc=$( curl -sf "http://www.microsoft.com/mac/autoupdate/0409MSOf14.xml" | awk -F'>|<' '/Location/{getline; print $3}' | grep "1410" )

## Build array of all required MSO update URLs
allMSOUpdates+=( "$SP1UpdateLoc" "${download_url}" )

## Get all required MSO update names
SP1UpdName=$( curl -s "${URL}" | awk -F'>|<' '/Title/{getline; print $3}' | head -1 )
currUpdName=$( curl -s "${URL}" | awk -F'>|<' '/Title/{getline; print $3}' | tail -1 )

## Build array of MSO update names
allUpdNames+=( "$SP1UpdName" "$currUpdName" )

if [ "$SelfService" ]; then
	## Set up progress bar elements
	exec 20>&-
	rm -f /tmp/hpipe
	mkfifo /tmp/hpipe
	sleep 0.2
	
	## Set up the progress bar
	"$cdPath" progressbar --title "" --text " Please wait. Preparing for downloads..." --width 500 --posY top --float \
	$iconType "$iconFile" --icon-height 40 --icon-width 40 < /tmp/hpipe &
	
	## Send progress through the named pipe
	exec 20<> /tmp/hpipe
	
	ix=0
	for update in "${allMSOUpdates[@]}"; do
		rawSize=$(curl -sI $curlFlag "${update}" | awk '/Content-Length/{print $NF}' | tail -1 | tr -cd [:digit:])
		adjSize=$(expr ${rawSize} / 1024)
		
		pct=0
		while [[ "$pct" -lt 100 ]]; do
			sleep 0.2
			dlSize=$(du -hk "/Library/Application Support/ITUpdater/Downloads/${allUpdNames[$ix]}.dmg" | awk '{print $1}' 2>/dev/null)
			if [ "$dlSize" != "" ]; then
				pct=$(expr ${dlSize} \* 100 / ${adjSize})
				echo "$pct ${pct}% -  Please wait. Downloading ${allUpdNames[$ix]}..." >&20
			fi
		done < <(curl -sf "$update" -o "/Library/Application Support/ITUpdater/Downloads/${allUpdNames[$ix]}.dmg")		
		let ix=$ix+1
	done

else
	## If SelfService is not set, download the updates silently
	ix=0
	for update in "${allMSOUpdates[@]}"; do
		curl -sf "$update" -o "/Library/Application Support/ITUpdater/Downloads/${allUpdNames[$ix]}.dmg"		
		if [ "$?" == "0" ]; then
			echo "${allUpdNames[$ix]}.dmg downloaded successfully..."
			let ix=$ix+1
		else
			echo "Error: could not download ${allUpdNames[$ix]}.dmg"
			exit 1
		fi
	done
fi

if [[ -e "/Library/Application Support/ITUpdater/Downloads/${allUpdNames[0]}.dmg"  && "/Library/Application Support/ITUpdater/Downloads/${allUpdNames[1]}.dmg" ]]; then
	echo "All MS Office downloads successful. Moving to installation"
	
	if [ "$SelfService" ]; then
		installMSOUpdatesSS
	else
		installMSOUpdates
	fi

else
	echo "Missing at least one download for MS Office. Canceling installation..."
	## Close the progress bar items
	exec 20>&-
	rm -f /tmp/hpipe
	exit 1
fi

}


function dlLatest ()
{

## Description: This function is used to download the current, or latest version of the specified product.
## This function gets the download_url string passed to it and use curl to pull down the update into
## the "/Library/Application Support/ITUpdater/Downloads/" directory

## First, check to see if the update is for Office 2011. if so, generate a NoQuit.xml

if [[ "${properName}" == "Office 2011" ]]; then

let StepNum=$StepNum+1
echo "[Stage ${StepNum}]: Installation is for Office 2011. Creating NoQuit.xml file..."

	echo '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
<dict>
<key>attributeSetting</key>
<integer>0</integer>
<key>choiceAttribute</key>
<string>selected</string>
<key>choiceIdentifier</key>
<string>quit</string>
</dict>
</array>
</plist>' > "/Library/Application Support/ITUpdater/NoQuit.xml"

fi

let StepNum=$StepNum+1

if [ "$SelfService" ]; then

	rawSize=$(curl -sI $curlFlag "${download_url}" | awk '/Content-Length/{print $NF}' | tail -1 | tr -cd [:digit:])
	adjSize=$(expr ${rawSize} / 1024)

	## Set up progress bar elements
	exec 20>&-
	rm -f /tmp/hpipe
	mkfifo /tmp/hpipe
	sleep 0.2

	## Set up the progress bar
	"$cdPath" progressbar --title "" --text " Please wait. Downloading the latest ${properName}..." --width 500 --posY top --float \
	$iconType "$iconFile" --icon-height 40 --icon-width 40 < /tmp/hpipe &

	## Wait just a half sec
	sleep 0.5

	## Send progress through the named pipe
	exec 20<> /tmp/hpipe

	echo "[Stage ${StepNum}]: Downloading the latest version of ${properName}..."

	## Start the download and push the process to the background
	curl -sf $curlFlag "${download_url}" -o "/Library/Application Support/ITUpdater/Downloads/${properName}_${currVers}.dmg" &

	## Wait a moment before beginning calculations
	sleep 0.2
	
	pct=0
	while [[ "$pct" -lt 100 ]]; do
		sleep 0.2
		dlSize=$(du -hk "/Library/Application Support/ITUpdater/Downloads/${properName}_${currVers}.dmg" | awk '{print $1}' 2>/dev/null)
		if [ "$dlSize" != "" ]; then
			pct=$(expr ${dlSize} \* 100 / ${adjSize})
			echo "$pct ${pct}% - Please wait. Downloading the latest ${properName}..." >&20
		fi
	done

	sleep 0.7
else
	## This curl command happens when SelfService is not set. It is not pushed to the background
	curl -sf $curlFlag "${download_url}" -o "/Library/Application Support/ITUpdater/Downloads/${properName}_${currVers}.dmg"
fi

if [[ -e "/Library/Application Support/ITUpdater/Downloads/${properName}_${currVers}.dmg" ]]; then
	echo "	Download of ${properName}_${currVers}.dmg was successful"

	if [[ "$installType" == "PKG" ]]; then
		echo "	Item is a package installer"
		if [ "$SelfService" ]; then
			installPKGUpdateSS
		else
			installPKGUpdate
		fi
	elif [[ "$installType" == "APP" ]]; then
		echo "	Item is an app bundle"
		copyAPPUpdate1
	fi
else
	echo "	Download of ${properName}_${currVers}.dmg failed. Exiting..."
	## Shutting down the progress bar
	echo "Closing progress bar."
	exec 20>&-
	rm -f /tmp/hpipe
	exit 1
fi

}


## Function block for comparing installed and current versions
## [---------------DO NOT MODIFY THIS FUNCTION --------------]
function compareVers ()
{

## Description: This function is run to compare the two version strings previously pulled and
## determine which is greater or if they are equal

let StepNum=$StepNum+1
echo "[Stage ${StepNum}]: Comparing versions..."

## Strip the version strings down to pure numbers
instVers_Int=$( echo "${instVers}" | tr -cd [:digit:] )
currVers_Int=$( echo "${currVers}" | tr -cd [:digit:] )

## Determine which integer string is the longest and assign its character length as a length variable
## Modify the shorter integer string to match the length of the longer integer by adding 0's and cut to the same length
if [ "${#instVers_Int}" -gt "${#currVers_Int}" ]; then
	length="${#instVers_Int}"
	currVers_N=$( printf "%s%0${length}d\n" $(echo "${currVers_Int}") | cut -c -${length} )
	instVers_N="${instVers_Int}"
elif [ "${#currVers_Int}" -gt "${#instVers_Int}" ]; then
	length="${#currVers_Int}"
	instVers_N=$( printf "%s%0${length}d\n" $(echo "${instVers_Int}") | cut -c -${length} )
	currVers_N="${currVers_Int}"
elif [ "${#instVers_Int}" -eq "${#currVers_Int}" ]; then
	instVers_N="${instVers_Int}"
	currVers_N="${currVers_Int}"
fi

## After exiting this process, we should have two integers of the same length to use for integer comparison

## Print back the actual version strings and the integer comparison strings
echo "	Current version of ${properName}:	${currVers}"
echo "	Installed version of ${properName}: 	${instVers}"
#echo "	Installed ${properName} (integer version):	${instVers_N}"
#echo "	Current ${properName} (integer version):	${currVers_N}"

let StepNum=$StepNum+1
echo "[Stage ${StepNum}]: Determining newer version of ${properName}..."

## Determine which is higher, then run an appropriate function
if [ "${currVers_N}" -gt "${instVers_N}" ]; then
	echo "[Stage ${StepNum} Result]: Version ${currVers} is newer than the installed version, ${instVers}"
	if [ "$SelfService" ]; then
		## Run the installUpdateRequest function
		installUpdateRequest
	else
		## Run the dlLatest function
		dlLatest
	fi
elif [ "${currVers_N}" -eq "${instVers_N}" ]; then
	echo "[Stage ${StepNum} Result]: The installed version (${instVers}) is current"

	## Run the upToDate function
	upToDate

else
	echo "[Stage ${StepNum} Result]: The installed version (${instVers}) is newer"

	## Run the newerInstalled function
	newerInstalled

fi

}


function SP1CheckReq ()
{

MSOSPVers=$( echo "$instVers" | cut -d. -f2 )

if [[ "$MSOSPVers" -lt "1" ]]; then
	SP1UpdtReq="Yes"
	## Print back the actual version strings for logging purposes
	echo "	Current version of ${properName}:	${currVers}"
	echo "	Installed version of ${properName}: 	${instVers}"
	if [ "$SelfService" ]; then
		installUpdateRequest
	else
		dlMSOUpdates
	fi
else
	compareVers
fi

}

## Generate User Agent string function
function genUAString ()
{

echo "[Stage ${StepNum}]: Generating UserAgent string..."
let StepNum=$StepNum+1

## Description: This function is called when its necessary to generate a valid User Agent string t obtain application information.
## These variables are used for generating the User Agent string to use in the curl command (if required)
## [------------------------- DO NOT MODIFY THESE VARIABLES OR THE FUNCTION ----------------------------]

## Get the full OS version
OSvers=$( sw_vers -productVersion )

## Generate OS version to be used with the UserAgent string
OSvers_UAGENT=$( echo "$OSvers" | sed 's/[.]/_/g' )

## Get the minor OS version number
OSvers_Minor=$( sw_vers -productVersion | cut -d. -f2 )

## Get Safari version
SafariVers=$( defaults read /Applications/Safari.app/Contents/Info.plist CFBundleShortVersionString )

## Get WebKit version
SafariWebKit=$( defaults read /Applications/Safari.app/Contents/version.plist CFBundleVersion | sed 's/'$OSvers_Minor'//' )

## Determine hardware type (Intel vs PPC)
HWArch=$( sysctl hw.machine | awk '{print $NF}' )
if [[ "$HWArch" =~ "x86" ]]; then
	ArchType="Intel"
else
	ArchType="PPC"
fi

## Dynamically generate the User Agent String from the above variables
UAGENT="Mozilla/5.0 (Macintosh; ${ArchType} Mac OS X ${OSvers_UAGENT}) AppleWebKit/${SafariWebKit} (KHTML, like Gecko) Version/${SafariVers} Safari/${SafariWebKit}"

## Run the assigned function
$runFunc

}


function MSONotInstalled ()
{

## Description: This function only gets called if the policy called for updating Office 2011 and the application was either not installed,
## or the version information could not be obtained. The policy can only be used to update an existing installation of Office 2011, not install it new

MSOnotInstText="${properName} could not be found installed on this Mac. This process can only be used to update an existing installation of ${properName}.

If you need this installed, please contact your local IT support for assistance."

if [ "$SelfService" ]; then
	"$cdPath" msgbox --title " " --text "${properName} is not installed" \
	--informative-text "${MSOnotInstText}" --icon info --button1 "    OK    " --width 400 --posY top
	
	exit 1
else
	echo "${properName} wasn't installed on this Mac. Exiting with error..."
	exit 1
fi

}


function notInstalled ()
{

## Description: This function is called when the target application or plug-in is not installed or not found on the client system

echo "	${properName} is not installed, or was not found on this system"		##Edited line

QIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/HelpIcon.icns"

if [ "$installNew" ]; then
	notFoundMsg="Version $currVers of ${properName} is available.
Would you like to install it now?"

else

	notFoundMsg="The ${properName} ${type} is not installed on your Mac. We expected to find it at:

	${appPath%.*}

This policy can only be used to update an existing installation."
fi

if [ "$SelfService" ]; then
	if [ "$installNew" ]; then
		installNewReq=$( "$cdPath" msgbox --title "${MsgTitle}" --text "${properName} can be installed" \
		--informative-text "${notFoundMsg}" --icon info --button1 "Install Now" --button2 "  Cancel  " --width 400 --posY top )

		if [[ "${installNewReq}" == "1" ]]; then
			echo "	User clicked \"Install Now\". Running install function..."
			updateMode="new"
			dlLatest
		else
			echo "[Final Result]: User clicked \"Cancel\". Exiting..."
			exit 0
		fi
	else
		echo "installNew flag is not set. Alert user and exit"
		"$cdPath" msgbox --title "${MsgTitle}" --text "${properName} is not installed" --informative-text "${notFoundMsg}" \
		--icon-file "$QIcon" --button1 "    OK    " --width 400 --posY top --quiet
		exit 0
	fi
elif [ "$installNew" == "Yes" ]; then
	echo "	The 'installNew' flag was set to 'Yes' so we are proceeding with installation"
	dlLatest
else
	echo "	The installNew flag was not set, so we are exiting silently"
	exit 0
fi

}


## Update Request function
function installUpdateRequest ()
{

## Description: This function is called if an update is available to be installed.
## It prompts user for an install confirmation in a dialog. Used only in SelfService mode.

updateReqMsg="We found an update to the ${properName} ${type} for your Mac, version ${currVers}. You have version ${instVers} installed now.

Would you like to update to the new version?"

installUpdate=$( "$cdPath" msgbox --title "${MsgTitle}" --text "$art ${properName} update is available" \
--informative-text "$updateReqMsg" --icon info --button1 "Update Now" --button2 "  Cancel  " --width 400 --height 175 --posY top )

if [[ "${installUpdate}" == "1" ]]; then
	echo "User chose to install the update"

	## If we are installing dual Office updates, run a specific function
	if [ "$SP1UpdtReq" ]; then
		updateMode="update"
		dlMSOUpdates
	else
		## Otherwise, run the dlLatest function to download the pkg/dmg
		updateMode="update"
		dlLatest	
	fi
else
	echo "[Final Result]: User chose to Cancel"
	exit 0
fi

}


function upToDate ()
{

## Description: This function is called when the application/plug-in is already up to the current version.
## It displays this in a dialog to the user if SelfService mode is enabled.

echo "[Final Result]: No new version of ${properName} is available for this Mac."

if [ "$SelfService" ]; then
	"$cdPath" msgbox --title "${MsgTitle}" --text "${properName} is already up to date" \
	--informative-text "There are no updates for the ${properName} ${type} available for your Mac. You're already up to date!" \
	--icon info --button1 " OK, thanks " --width 400 --height 175 --posY top --quiet
fi

exit 0

}


function newerInstalled ()
{

## Description: This function is called when the installed application appears newer than the current version.
## It displays this to the end user in a dialog if SelfService mode is enabled.

echo "[Final Result]: The installed version of ${properName} (${instVers}) is already newer than the current release located ($currVers)."

newerInstMsg="The ${properName} version installed on your Mac (${instVers}) appears newer than the current version we located ($currVers).
Its possible you have a beta version of the $type installed."

if [ "$SelfService" ]; then
	"$cdPath" msgbox --title "${MsgTitle}" --text "A newer version is already installed" \
	--informative-text "$newerInstMsg" --icon info --button1 " OK, thanks " --width 400 --height 175 --posY top --quiet
fi

exit 0

}


function getinstVersion ()
{

## Description: This function is called to get the installed application/plug-in version on disk.

let StepNum=$StepNum+1
echo "[Stage ${StepNum}]: Determining installed version of ${properName}..."

if [[ -e "${appPath}" ]]; then
	instVers=$( defaults read "${appPath}/Contents/Info.plist" ${CFVers} 2>/dev/null)

	if [[ ! -z "$instVers" ]]; then
		## If the assigned application has a versProcessor var assigned, run it to generate a modified version string
		if [[ ! -z "$versProcessor" ]]; then
			instVers=$( eval echo "$instVers" | $versProcessor )
		fi
		
		if [[ "${properName}" == "Office 2011" ]]; then
			SP1CheckReq
		else
			## Run the version comparison function
			compareVers
		fi
	else
		if [[ "${properName}" == "Office 2011" ]]; then
			MSONotInstalled
		fi
	fi
else
	instVers="0"

	if [[ "$properName" != "Office 2011" ]]; then
		## Run not installed function
		notInstalled
	elif [[ "$properName" == "Office 2011" ]]; then
		echo "Office 2011 is not installed on this Mac, or the version information couldn't be obtained"
		MSONotInstalled
	fi
fi

}


function dlError ()
{

## Description: This function is called when it was not possible to obtain the correct download location for the application or plug-in.
## It displays this to the end user in a dialog if SelfService mode is enabled.

dlProbMsg="We encountered a problem when trying to get the download location for ${properName}.
You can try running this policy again. If you continue to see this message appear, contact IT support to report it."

if [ "$SelfService" ]; then
	"$cdPath" msgbox --title "${MsgTitle}" --text "We ran into a problem" --informative-text "${dlProbMsg}" \
	--button1 "   OK   " --icon caution --width 400 --height 175 --posY top --quiet
fi

exit 1

}


function getVersErr ()
{

## Description: This function is called if we aren't able to gather current version information on the app/plug-in.
## Since the cause of the error can be because the OS is incompatible, or (more rarely) because no active internet connection
## we attempt to check for an active internet connection first, and display appropriate messaging based on the results.

noCurrVersTxt1="No version was found for your Mac"

noCurrVersMsg1="We weren't able to locate a version of ${properName} for your Mac.
This may be because the OS version is too old, or too new for this ${type}.
If you believe this is not correct, contact the Help Desk for assistance. Please be sure to include any details about your Mac that you can."

noCurrVersTxt2="No internet connection"

noCurrVersMsg2="We were not able to access the information we need. Please check to make sure you have an active internet connection and try again.

If you continue to experience a problem, contact the Help Desk for assistance."

## Check to make sure we have an active internet connection first
curl -sfI http://google.com

if [[ "$?" == "0" ]]; then
	echo "We have internet access, but couldn't pull version information for ${properName}."
	Text="$noCurrVersTxt1"
	Msg="$noCurrVersMsg1"
else
	echo "Somehow there is no active internet connection on this Mac."
	Text="$noCurrVersTxt2"
	Msg="$noCurrVersMsg2"
fi

if [ "$SelfService" ]; then
	"$cdPath" msgbox --title "$MsgTitle" --text "$Text" --informative-text "$Msg" \
	--button1 "    OK    " --width 400 --posY top --icon caution --quiet
fi

## We exit with error code 1 since we couldn't gather relevant information
exit 1

}


## [-------------------------------------------- APPLICATION/PLUG-IN VERSION GATHERING FUNCTIONS ---------------------------------------------]

function getJavaVersion ()
{

## Description: This function is called to get Oracle Java version and download URL

## If the Mac is running 10.10, we need to use a different check url for Java
if [[ $(sw_vers -productVersion | cut -d. -f2) == "10" ]]; then
	URL="http://java.com/en/download/index.jsp"
	echo "[Stage ${StepNum}]: Determining current version of ${properName}..."
	currVersBase=$( curl -sfA "${UAGENT}" "${URL}" 2>/dev/null | awk -F'[>|<]' '/Version/{print}' | sed 's/Version //;s/ Update /./' )
else
	echo "[Stage ${StepNum}]: Determining current version of ${properName}..."
	currVersBase=$( curl -sfA "${UAGENT}" "${URL}" 2>/dev/null | awk -F'[>|<]' '/Recommended Version/{print substr ($3,21,12)}' | sed -e 's/ Update /./;s/[ ]//' )
fi

if [[ ! -z "${currVersBase}" ]]; then

	## If the base version was found, assign the currVers string
	currVers="1.${currVersBase}"

	## Get the download location
	download_url=$( curl -sfA "${UAGENT}" "http://java.com/en/download/manual.jsp?locale=en" 2>/dev/null | awk -F'"' '/Download Java for Mac OS X.*http.*BundleId/{ for(i = 1; i <= NF; i++) { print $i; };exit }' | grep -m1 "^http:" )

	curl -sfIA "${UAGENT}" "${download_url}" 2>&1 > /dev/null

	if [[ "$?" == "0" ]]; then
		## Get the installed version
		getinstVersion
	else
		echo "Error when getting the download information"
		dlError
	fi
else
	## Else on error, run the getVersErr function
	getVersErr
fi

}


function getFlashVersion ()
{

## Description: This function is called to get current Adobe FlashPlayer version and download URL

echo "[Stage ${StepNum}]: Determining current version of ${properName}..."

currVers=$( curl -sf "${URL}" 2>/dev/null | xpath /XML/update[1] 2>&1 | awk -F'"' '{print $2}' | sed -e '/^$/d;s/,/./g' )

if [[ ! -z "${currVers}" ]]; then

	currMajVers=$(echo "$currVers" | cut -d. -f1)

	## Set the full download URL from the current version information pulled in the previous command
	download_url="http://fpdownload.macromedia.com/get/flashplayer/current/licensing/mac/install_flash_player_${currMajVers}_osx_pkg.dmg"

	## Check the URL to make sure its valid
	curl -sfI "$download_url" 2>&1 > /dev/null
	if [[ "$?" == "0" ]]; then
		## Get the installed version
		getinstVersion
	else
		echo "Error when getting the download information"
		dlError
	fi
else
	## Else on error, run the getVersErr function
	getVersErr
fi

}


function getSilverlightVersion ()

{

## Description: This function is called to get current Silverlight version and download URL

echo "[Stage ${StepNum}]: Determining current version of ${properName}..."

currVers=$( curl -sf "${URL}" 2>/dev/null | grep -m1 "Silverlight 5 Build" | awk -F'[>|<]' '{print $2}' | tr ' ' '\n' | awk '/Build/{getline; print}' )

if [[ ! -z "${currVers}" ]]; then
	## If we pulled back a current version, get the download location
	download_url=$( curl -sfA "$UGENT" "http://go.microsoft.com/fwlink/?LinkID=229322" | awk -F'"' '{print $2}' | sed '/^$/d' )

	## Check the URL to make sure its valid
	curl -sfI "$download_url" 2>&1 > /dev/null

	if [[ "$?" == "0" ]]; then
		## Get the installed version
		getinstVersion
	else
		echo "Error when getting the download information."
		dlError
	fi
else
	## Else on error, run the getVersErr function
	getVersErr
fi

}


function getFirefoxVersion ()
{

## Description: This function is called to get current Firefox version and download URL

echo "[Stage ${StepNum}]: Determining current version of ${properName}..."

## Get the current release version from Mozilla's FTP pages
currVers=$( curl -sf "${URL}" 2>/dev/null | awk -F'[>|<]' '/href.*dmg/{ for(i = 1; i <= NF; i++) { print $i; } }' | grep "^Firefox" | sed -e 's/Firefox //;s/esr//;s/.dmg//' )

if [[ ! -z "${currVers}" ]]; then
	## If we pulled back a current version, get the download location

	dmg_url_name=$( curl -sf "${URL}" 2>/dev/null | tr '<' '\n' | awk -F'"' '/a href.*.dmg/{print $2}' )
#	download_url="https://download-installer.cdn.mozilla.net/pub/firefox/releases/latest/mac/en-US/$dmg_url_name"
	download_url="${URL}${dmg_url_name}"

	## Check to make sure the URL is valid
	curl -sfI "$download_url" 2>&1 > /dev/null

	if [[ "$?" == "0" ]]; then
		## Get the installed version
		getinstVersion
	else
		echo "Error when getting the download information."
		dlError
	fi
else
	## Else on error, run the getVersErr function
	getVersErr 
fi

}


function getFlipPlayerVersion ()
{

## Description: This function is called to get current free Flip Player version and download URL

echo "[Stage ${StepNum}]: Determining current version of ${properName}..."

## Get the current version from the Flip4Mac download page link
currVers=$(curl -sfL "${URL}" 2>/dev/null | awk -F"'" '/window.location/{print $2}' | awk -F'/' '{print $NF}' | sed -e 's/Flip-Player-//;s/.dmg$//')

if [[ ! -z "${currVers}" ]]; then

	download_url=$( curl -sf "${URL}" | awk -F"'" '/window.location/{print $2}' )
	
	## Check to make sure the URL is valid	
	curl -sfI "${download_url}" 2>&1 > /dev/null

	if [[ "$?" == "0" ]]; then
		## If we pulled back a current version, get the installed version
		getinstVersion
	else
		echo "Error when getting the download information."
		dlError
	fi	
else
	## Else on error, run the getVersErr function
	getVersErr 
fi

}

function getVLCVersion ()
{

## Description: This function is called to get the current VLC version

echo "[Stage ${StepNum}]: Determining current version of ${properName}..."

## Get the current version from the VLC Changelog xml page
currVers=$( curl -sf "${URL}" 2>/dev/null | awk -F'[>|<]' '/title/{print substr ($3,9,8)}' | tail -1 )

if [[ ! -z "${currVers}" ]]; then

	download_url=$( curl -sf "${URL}" | awk -F'"' '/url/{print $2}' | tail -1 )

	## Check to make sure the URL is valid	
	curl -sfI "${download_url}" 2>&1 > /dev/null

	if [[ "$?" == "0" ]]; then
		## If we pulled back a current version, get the installed version
		getinstVersion
	else
		echo "Error when getting the download information."
		dlError
	fi	
else
	## Else on error, run the getVersErr function
	getVersErr 
fi

}


function getRdrVersion ()
{

echo "[Stage ${StepNum}]: Determining current version of ${properName}..."

## Description: This function is called to get the current Adobe Reader version

## Get the current version from the get.adobe.com/reader page
currVers=$( curl -sfA "${UAGENT}" "${URL}" 2>/dev/null | awk -F'[(|)]' '/<strong>Version/{print $2}' )

if [[ ! -z "${currVers}" ]]; then
	## Build a few variables needed for the URL string
	currMajVers=$(echo "${currVers}" | cut -d. -f1)
	currVersString=$(echo "${currVers}" | sed 's/[.]//g')

	## Set up the download URL
	## Edited 12-12-14 to use generic URL for all localizations
	download_url="http://ardownload.adobe.com/pub/adobe/reader/mac/${currMajVers}.x/${currVers}/misc/AdbeRdrUpd${currVersString}.dmg"

	## Check to see if the URL is valid
	curl -sfI "${download_url}" 2>&1 > /dev/null

	if [[ "$?" == "0" ]]; then
		## If we pulled back a current version, get the installed version
		getinstVersion
	else
		echo "Error when getting the download information."
		dlError
	fi
else
	## Else on error, run the getVersErr function
	getVersErr
fi

}


function getOfficeVersion ()
{

echo "[Stage ${StepNum}]: Determining current version of ${properName}..."

## Description: This function is called to get the current Microsoft Office 2011 version

## Get the current version from the Microsoft AutoUpdate xml
currVers=$( curl -sf "${URL}" 2>/dev/null | awk -F'>|<' '/Payload/{getline; print $3}' | tail -1 | awk '{print $3}' )

if [[ ! -z "${currVers}" ]]; then

	download_url=$( curl -sf "${URL}" | awk -F'>|<' '/Location/{getline; print $3}' | tail -1 )

	## Check to see if the URL is valid
	curl -sfI "${download_url}" 2>&1 > /dev/null

	if [[ "$?" == "0" ]]; then
		## If we pulled back a current version, get the installed version
		getinstVersion
	else
		echo "Error when getting the download information."
		dlError
	fi
else
	## Else on error, run the getVersErr function
	getVersErr
fi

}

## [---------------------------------------- END - APPLICATION/PLUG-IN VERSION GATHERING FUNCTIONS ---------------------------------------------]

StepNum=1

## If Self Service mode is set, gather the current user's UI settings (Appearance color theme and Keyboard access mode)
## Then duplicate these settings to the root account's setting so the UI elements match the user environment

if [ "$SelfService" ]; then

	## Determine the logged in user
	loggedInUser=$( ls -l /dev/console | awk '{print $3}' )
	
	## Determine logged in user's home directory path
	homeDir=$( dscl . read /Users/$loggedInUser NFSHomeDirectory | awk '{ print $NF }' )

	## Get logged in user's Appearance color settings
	aquaColor=$( defaults read $homeDir/Library/Preferences/.GlobalPreferences AppleAquaColorVariant 2> /dev/null )

	## If user has not changed their settings, value will be null. Set to default 'Aqua' color
	if [ "$aquaColor" == "" ]; then
		aquaColor="1"
	else
		aquaColor="$aquaColor"
	fi

	## Get logged in user's Keyboard access settings
	keybdMode=$( defaults read $homeDir/Library/Preferences/.GlobalPreferences AppleKeyboardUIMode 2> /dev/null )

	## If user has not changed their settings, value will be null. Set to default 'Text boxes and lists only'
	if [ "$keybdMode" == "" ]; then
		keybdMode="0"
	else
		keybdMode="$keybdMode"
	fi

	## Set the root account environment settings to match current logged in user's
	defaults write /private/var/root/Library/Preferences/.GlobalPreferences AppleAquaColorVariant -int "$aquaColor"
	defaults write /private/var/root/Library/Preferences/.GlobalPreferences AppleKeyboardUIMode -int "$keybdMode"
	killall cfprefsd
	
fi


## Determine if we need a User Agent string before moving to the curl command
if [ "$UAReq" == "Yes" ]; then
	## If, Yes, run the function
	echo ""
	genUAString
else
	## Otherwise, move straight to the version gathering function
	echo ""
	$runFunc
fi
