#!/bin/bash

##	Script Name:		Selectable_SoftwareUpdate.sh
##	Script Author:		Mike Morales, @mm2270 on JAMFNation
##	Last Update:		2016-01-20

##	Last Update:
##	Included 'Reboot Now' button, when a reboot is required after installed updates,
##	which waits 4 seconds, then does an immediate reboot when clicked.

##	Path to cocoaDialog (customize to your own location)
cdPath="/Library/Application Support/JAMF/bin/cocoaDialog.app/Contents/MacOS/cocoaDialog"

##	Quick sanity check to make sure cocoaDialog is installed in the path specified
if [ ! -e "$cdPath" ]; then
	echo "cocoaDialog was not found in the path specified. It may not be installed, or the path is wrong. Exiting..."
	exit 1
else
	## If cocoaDialog was found, check to make sure its the 3.0 beta 7 version
	exePath=$(echo ${cdPath#$(dirname "$(dirname "$cdPath")")/})
	cDInfoPath="$(echo "$cdPath" | sed "s|$exePath||")Info.plist"
	if [[ $(defaults read "$cDInfoPath" CFBundleShortVersionString) != "3.0-beta7" ]]; then
		echo "The version of cocoaDialog installed is not 3.0-beta 7. The 3.0-beta7 version is required for proper functioning of this script."
		exit 1
	fi
fi

##	Set the installAllAtLogin flag here to 'yes' or leave it blank (equivalent to 'no')
##	Function: When the script is run on a Mac that is at the login window, if the flag is set to 'yes',
##	it will lock the login window to prevent unintended logins and proceed to install all available updates.
##	Once completed, the login window will either be unlocked in the case of no restarts needed,
##	or a restart will be done immediately to complete the installations.

installAllAtLogin="yes"

##	Get minor version of OS X
osVers=$( sw_vers -productVersion | cut -d. -f2 )

##	Set appropriate Software Update icon depending on OS version
if [[ "$osVers" -lt 8 ]]; then
	swuIcon="/System/Library/CoreServices/Software Update.app/Contents/Resources/Software Update.icns"
else
	swuIcon="/System/Library/CoreServices/Software Update.app/Contents/Resources/SoftwareUpdate.icns"
fi

##	Set appropriate Restart icon depending on OS version
if [[ "$osVers" == "9" ]]; then
	restartIcon="/System/Library/CoreServices/loginwindow.app/Contents/Resources/Restart.tiff"
else
	restartIcon="/System/Library/CoreServices/loginwindow.app/Contents/Resources/Restart.png"
fi

##	Start - Check Casper Suite script parameters and assign any that were passed to the script

##	PARAMETER 4: Set the Organization/Department/Division name. Used in dialog titles
##	Default string of "Managed" is used if no script parameter is passed
if [[ "$4" != "" ]]; then
	orgName="$4"
else
	orgName="Managed"
fi

##	PARAMETER 5: Set to "no" (case insensitive) to show a single progress bar update for all installations.
##	Default value of "yes" will be used if no script parameter is passed
if [[ "$5" != "" ]]; then
	shopt -s nocasematch
	if [[ "$5" == "no" ]]; then
		showProgEachUpdate="no"
	else
		showProgEachUpdate="yes"
	fi
	shopt -u nocasematch
else
	showProgEachUpdate="yes"
fi

##	PARAMETER 6: Set the number of minutes until reboot (only used if installations require it)
##	Default value of 5 minutes is assigned if no script parameter is passed
##	Special note: Only full integers can be used. No decimals.
##	If the script detects a non whole integer, it will fall back on the default 5 minute setting.
if [[ "$6" != "" ]]; then
	## Run test to make sure we have a non floating point integer
	if [[ $(expr "$6" / "$6") == "1" ]]; then
		minToRestart="$6"
	else
		echo "Non integer, or a decimal value was passed. Setting reboot time to default (5 minutes)"
		minToRestart="5"
	fi
else
	minToRestart="5"
fi

##	Parameter 7: Set to the full path of an icon or image file for any dialogs that are not using the
##	Apple Software Update icon. This could be a company logo icon for example
##	Default icon is set in the following manner:
##		If no script parameter is passed, or the icon/image can not be found and JAMF Self Service is present on the Mac, its icon will be used
## 		If Self Service is not found, the Software Update icon will be used
if [[ "$7" != "" ]]; then
	if [[ -e "$7" ]]; then
		echo "A custom dialog icon was set: $7"
		msgIcon="$7"
	else
		if [[ -e "/Applications/Self Service.app/Contents/Resources/Self Service.icns" ]]; then
			##	Self Service present. Use a default Self Service icon if the file specified could not be found
			msgIcon="/Applications/Self Service.app/Contents/Resources/Self Service.icns"
		else
			##	Icon file not found, and Self Service not present. Set icon to Software Update
			msgIcon="$swuIcon"
		fi
	fi
else
	if [[ -e "/Applications/Self Service.app/Contents/Resources/Self Service.icns" ]]; then
		##	Self Service present. Use a default Self Service icon if no parameter was passed
		msgIcon="/Applications/Self Service.app/Contents/Resources/Self Service.icns"
	else
		##	No parameter passed, and Self Service not present. Set icon to Software Update
		msgIcon="$swuIcon"
	fi
fi

##	End - Check Casper Suite script parameters


##	Text displayed in dialog prompting for selections. Customize if desired.
##	Two versions:
##		One,for when reboot *required* updates are found.
##		Two,for when only non-reboot updates are found.
swuTextReboots="Select the Apple Software Update items you would like to install now from the list below.

◀  =  Indicates updates that will REQUIRE a reboot of your Mac to complete.

To install all updates that will not require a reboot, click \"Install No Reboot Updates\"

"

swuTextNoReboots="Select the Apple Software Update items you would like to install now from the list below.

"

################################################## ENV VARIABLES #####################################################
##																													##
##	These variables are gathered to set up the visual environment of the messaging to match the logged in user's	##
##	settings. We gather the settings, then change the root account's settings to match.								##
##																													##
######################################################################################################################

## Get current logged in user name
loggedInUser=$( ls -l /dev/console | /usr/bin/awk '{ print $3 }' )
echo "Current user is: $loggedInUser"

##	Determine logged in user's home directory path
HomeDir=$( dscl . read /Users/$loggedInUser NFSHomeDirectory | awk '{ print $NF }' )

##	Get logged in user's Appearance color settings
AquaColor=$( defaults read "$HomeDir/Library/Preferences/.GlobalPreferences" AppleAquaColorVariant 2> /dev/null )

##	If user has not changed their settings, value will be null. Set to default 'Aqua' color
if [[ -z "$AquaColor" ]]; then
	AquaColor="1"
else
	AquaColor="$AquaColor"
fi

##	Get logged in user's Keyboard access settings
KeybdMode=$( defaults read "$HomeDir/Library/Preferences/.GlobalPreferences" AppleKeyboardUIMode 2> /dev/null )

##	If user has not changed their settings, value will be null. Set to default 'Text boxes and lists only'
if [[ -z "$KeybdMode" ]]; then
	KeybdMode="0"
else
	KeybdMode="$KeybdMode"
fi

##	Set the root account environment settings to match current logged in user's
defaults write /private/var/root/Library/Preferences/.GlobalPreferences AppleAquaColorVariant -int "${AquaColor}"
defaults write /private/var/root/Library/Preferences/.GlobalPreferences AppleKeyboardUIMode -int "${KeybdMode}"

##	Restart cfprefsd so new settings will be recognized
killall cfprefsd

################################# Do not modify below this line ########################################

##	Function to run when installations are complete
doneRestart ()
{

doneMSG="The installations have completed, but your Mac needs to reboot to finalize the updates.
	
Your Mac will automatically reboot in $minToRestart minutes. Begin to save any open work and close applications now."

##	Display initial message for 30 seconds before starting the progress bar countdown
userSelection=$("$cdPath" msgbox \
	--title "$orgName Software Update > Updates Complete" \
	--text "Updates installed successfully" \
	--informative-text "$doneMSG" \
	--button1 "    OK    " \
	--button2 "Reboot Now" \
	--icon-file "$msgIcon" \
	--posY top \
	--width 450 \
	--timeout 30 \
	--timeout-format " ")
	
	if [[ "$userSelection" == "1" ]]; then
		echo "User clicked OK button. Continuing with reboot countdown..."
	elif [[ "$userSelection" == "2" ]]; then
		echo "User clicked Reboot Now. Initiating reboot in 4 seconds..."
		sleep 4
		/sbin/shutdown -r now
	else
		echo "Dialog timed out. Continuing with reboot countdown..."
	fi

	##	Sub-function to (re)display the progressbar window. Developed to work around the fact that
	##	CD responds to Cmd+Q and will quit. The script continues the countdown. The sub-function
	##	causes the progress bar to reappear. When the countdown is done we quit all CD windows
	showProgress ()
	{
	
	##	Display progress bar
	"$cdPath" progressbar --title "" --text " Preparing to restart this Mac..." \
	--width 500 --height 90 --icon-file "$restartIcon" --icon-height 48 --icon-width 48 < /tmp/hpipe &
	
	##	Send progress through the named pipe
	exec 20<> /tmp/hpipe
	
	}

##	Close file descriptor 20 if in use, and remove any instance of /tmp/hpipe
exec 20>&-
rm -f /tmp/hpipe

##	Create the name pipe input for the progressbar
mkfifo /tmp/hpipe
sleep 0.2

## Run progress bar sub-function
showProgress

echo "100" >&20

timerSeconds=$((minToRestart*60))
startTime=$( date +"%s" )
stopTime=$((startTime+timerSeconds))
secsLeft=$timerSeconds
progLeft="100"

while [[ "$secsLeft" -gt 0 ]]; do
	sleep 1
	currTime=$( date +"%s" )
	progLeft=$((secsLeft*100/timerSeconds))
	secsLeft=$((stopTime-currTime))
	minRem=$((secsLeft/60))
	secRem=$((secsLeft%60))
	if [[ $(ps axc | grep "cocoaDialog") == "" ]]; then
		showProgress
	fi
	echo "$progLeft $minRem minutes, $secRem seconds until reboot. Please save any work now." >&20
done

echo "Closing progress bar."
exec 20>&-
rm -f /tmp/hpipe

## Close cocoaDialog. This block is necessary for when multiple runs of the sub-function were called in the script
for process in $(ps axc | awk '/cocoaDialog/{print $1}'); do
	/usr/bin/osascript -e 'tell application "cocoaDialog" to quit'
done

##	Clean up by deleting the SWUList file in /tmp/
rm /tmp/SWULIST

##	Delay 1/2 second, then force reboot
sleep 0.5
shutdown -r now

}

##	Function to install selected updates, updating progress bar with information
installUpdates ()
{

if [[ "${restartReq}" == "yes" ]]; then
	installMSG="Installations are now running. Please do not shut down your Mac or put it to sleep until the installs finish.

IMPORTANT:
Because you chose some updates that require a restart, we recommend saving any important documents now. Your Mac will reboot soon after the installations are complete."

elif [[ "${restartReq}" == "no" ]] || [[ "${restartReq}" == "" ]]; then
	installMSG="Updates are now installing. Please do not shut down your Mac or put it to sleep until the installs finish."
fi

	##	Sub-function to display both a button-less CD window and a progress bar
	##	This sub routine gets called by the enclosing function. It can also be called by
	##	the install process if it does not see 2 instances of CD running
	showInstallProgress ()
	{

	##	Display button-less window above progress bar, push to background
	"$cdPath" msgbox --title "$orgName Software Update > Installation" --text "Installations in progress" \
	--informative-text "${installMSG}" --icon-file "${msgIcon}" --width 450 --height 184 --posY top &

	##	Display progress bar
	echo "Displaying progress bar window."
	"$cdPath" progressbar --title "" --text " Preparing to install selected updates..." \
	--posX "center" --posY 198 --width 450 --float --icon installer < /tmp/hpipe &

	##	Send progress through the named pipe
	exec 10<> /tmp/hpipe

	}

##	Close file descriptor 10 if in use, and remove any instance of /tmp/hpipe
exec 10>&-
rm -f /tmp/hpipe

##	Create the name pipe input for the progressbar
mkfifo /tmp/hpipe
sleep 0.2

## Run the install progress sub-function (shows button-less CD window and progressbar
showInstallProgress

if [[ "$showProgEachUpdate" == "yes" ]]; then
	echo "Showing individual update progress."
	##	Run softwareupdate in verbose mode for each selected update, parsing output to feed the progressbar
	##	Set initial index loop value to 0; set initial update count value to 1; set variable for total updates count
	i=0;
	pkgCnt=1
	pkgTotal="${#selectedItems[@]}"
	for index in "${selectedItems[@]}"; do
		UpdateName="${progSelectedItems[$i]}"
		echo "Now installing ${UpdateName}..."
		/usr/sbin/softwareupdate --verbose -i "${index}" 2>&1 | while read line; do
			##	Re-run the sub-function to display the cocoaDialog window and progress
			##	if we are not seeing 2 items for CD in the process list
			if [[ $(ps axc | grep "cocoaDialog" | wc -l | sed 's/^ *//') != "2" ]]; then
				killall cocoaDialog
				showInstallProgress
			fi
			pct=$( echo "$line" | awk '/Progress:/{print $NF}' | cut -d% -f1 )
			echo "$pct Installing ${pkgCnt} of ${pkgTotal}: ${UpdateName}..." >&10
		done
		let i+=1
		let pkgCnt+=1
	done
else
	## Show a generic progress bar that progresses through all installs at once from 0-100 %
	echo "Parameter 5 was set to \"no\". Showing single progress bar for all updates"
	softwareupdate --verbose -i "${SWUItems[@]}" 2>&1 | while read line; do
		##	if we are not seeing 2 items for CD in the process list
		if [[ $(ps axc | grep "cocoaDialog" | wc -l | sed 's/^ *//') != "2" ]]; then
			killall cocoaDialog
			showInstallProgress
		fi
		pct=$( echo "$line" | awk '/Progress:/{print $NF}' | cut -d% -f1 )
		echo "$pct Installing ${#SWUItems[@]} updates..." >&10
	done
fi

echo "Closing progress bar."
exec 10>&-
rm -f /tmp/hpipe

##	Close all instances of cocoaDialog
echo "Closing all cocoaDialog windows."
for process in $(ps axc | awk '/cocoaDialog/{print $1}'); do
	/usr/bin/osascript -e 'tell application "cocoaDialog" to quit'
done

##	If any installed updates required a reboot...
if [[ "${restartReq}" == "yes" ]]; then
	## ...then move to the restart phase
	doneRestart
##	If no installed updates required a reboot, display updates complete message instead
elif [[ "${restartReq}" == "no" ]]; then
	echo "Showing updates complete message."
	doneMSG="The installations have completed successfully. You can resume working on your Mac."
	"$cdPath" msgbox --title "$orgName Software Update > Updates Complete" \
	--text "Updates installed successfully" --informative-text "$doneMSG" \
	--button1 "    OK    " --posY top --width 450 --icon-file "$msgIcon"
	
	## Clean up by deleting the SWUList file in /tmp/ before exiting the script
	echo "Cleaning up SWU list file."
	rm /tmp/SWULIST
	exit 0
fi

}

##	Function to assess which items were checked, and create new arrays
##	used for installations and other functions
assessChecks ()
{

##	Check to see if the installNoReboots flag was set by the user
if [[ "$installNoReboots" == "yes" ]]; then
	echo "User chose to install all non reboot updates. Creating update(s) array and moving to install phase"
	##	If flag was set, build update arrays from the noReboots array
	for index in "${noReboots[@]}"; do
		selectedItems+=( "${SWUItems[$index]}" )
		hrSelectedItems+=( "${SWUList[$index]}" )
		progSelectedItems+=( "${SWUProg[$index]}" )
	done
	
	##	Automatically set the restart required flag to "no"
	restartReq="no"
	
	##	Then move on to install updates function
	installUpdates
fi

##	If installNoReboots flag was not set, generate array of formatted
##	checkbox indexes for parsing based on the selections from the user
i=0;
for state in ${Checks[*]}; do
	checkboxstates=$( echo "${i}-${state}" )
	let i+=1
  	##	Set up an array we can read through later with the state of each checkbox
	checkboxfinal+=( "${checkboxstates[@]}" )
done

for check in "${checkboxfinal[@]}"; do
	if [[ "$check" =~ "-1" ]]; then
		##	First, get the index of the checked item
		index=$( echo "$check" | cut -d- -f1 )
		##	Second, generate 3 new arrays:
		##	1) Short names of the updates for the installation
		##	2) Names of updates as presented in the dialog (for checking restart status)
		##	3) Names of the updates for updating the progress bar
		selectedItems+=( "${SWUItems[$index]}" )
		hrSelectedItems+=( "${SWUList[$index]}" )
		progSelectedItems+=( "${SWUProg[$index]}" )
	fi
done

echo "The following updates will be installed:	${progSelectedItems[@]}"

##	Determine if any of the checked items require a reboot
restartReq="no"
for item in "${hrSelectedItems[@]}"; do
	if [[ $(echo "${item}" | grep "^◀") != "" ]]; then
		echo "At least one selected update will require reboot. Setting the restartReq flag to \"yes\""
		restartReq="yes"
		break
	fi
done

echo "Restart required?:	${restartReq}"

##	If we have some selected items, move to install phase
if [[ ! -z "${selectedItems[@]}" ]]; then
	echo "Updates were selected"
	installUpdates
fi

}

##	The initial message function
startDialog ()
{

##	Generate array of SWUs for dialog
while read SWU; do
	SWUList+=( "$SWU" )
done < <(echo "${readSWUs}")

##	Generate array of SWUs for progress bar
while read item; do
	SWUProg+=( "${item}" )
done < <(echo "${progSWUs}")

##	Generate array of SWUs for installation
while read swuitem; do
	SWUItems+=( "$swuitem" )
done < <(echo "${installSWUs}")

##	Generate an array of indexes for any non-reboot updates
for index in "${!SWUList[@]}"; do
	if [[ $(echo "${SWUList[$index]}" | grep "^◀") == "" ]]; then
		noReboots+=( "$index" )
	fi
done

##	Show dialog with selectable options
if [[ ! -z "${noReboots[@]}" ]]; then
	echo "There are some non reboot updates available. Showing selection screen to user"
	SWUDiag=$( "$cdPath" checkbox --title "$orgName Software Update" --items "${SWUList[@]}" \
	--label "$swuTextReboots" --button1 " Install " --button2 " Cancel " --button3 "Install No Reboot Updates" --cancel "button2" \
	--icon-file "$swuIcon" --icon-height 80 --icon-width 80 --width 500 --posY top )

	##	Get the button pressed and the options checked
	Button=$( echo "$SWUDiag" | awk 'NR==1{print $0}' )
	Checks=($( echo "$SWUDiag" | awk 'NR==2{print $0}' ))
	##	Set up a non array string from the checkboxes returned
	ChecksNonArray=$( echo "$SWUDiag" | awk 'NR==2{print $0}' )
	
	##	If the "Install" button was clicked
	if [[ "$Button" == "1" ]]; then
		echo "User clicked the \"Install\" button."
		##	Check to see if at least one box was checked
		if [[ $( echo "${ChecksNonArray}" | grep "1" ) == "" ]]; then
			echo "No selections made. Alerting user and returning to selection screen."
			"$cdPath" msgbox --title "$orgName Software Update" --text "No selections were made" \
			--informative-text "$(echo -e "You didn't select any updates to install.\n\nIf you want to cancel out of this application, click the \"Cancel\" button in the window instead, or press the Esc key.\n\nThe Software Update window will appear again momentarily.")" \
			--button1 "    OK    " --timeout 10 --timeout-format " " --width 500 --posY top --icon caution
			##	Because we are restarting the function, first empty all previously built arrays
			##	Credit to Cem Baykara (@Cem - JAMFNation) for discovering this issue during testing
			SWUList=()
			SWUProg=()
			SWUItems=()
			##	Now restart this function after the alert message times out
			startDialog
		else
			##	"Install" button was clicked and items checked. Run the assess checkbox function
			echo "Selections were made. Moving to assessment function..."
			assessChecks
		fi
	elif [[ "$Button" == "3" ]]; then
		##	"Install No Reboot Updates" button was clicked. Set the installNoReboots flag to "yes" and skip to check assessment
		echo "User clicked the \"Install No Reboot Updates\" button."
		installNoReboots="yes"
		assessChecks
	else
		echo "User chose to Cancel. Exiting..."
		exit 0
	fi
	
else
	##	No non-reboot updates were available. Display a different dialog to the user
	echo "No non-reboot updates found, but other updates available. Showing selection dialog to user"
	SWUDiag=$( "$cdPath" checkbox --title "$orgName Software Update" --items "${SWUList[@]}" \
	--label "$swuTextNoReboots" --button1 " Install " --button2 " Cancel " --cancel "button2" \
	--icon-file "$swuIcon" --icon-height 80 --icon-width 80 --width 500 --posY top --value-required \
	--empty-text "$(echo -e "You must check at least one item before clicking \"Install\".\n\nIf you want to exit, click \"Cancel\" or press the esc key.")" )
	
	##	Get the button pressed and the options checked
	Button=$( echo "$SWUDiag" | awk 'NR==1{print $0}' )
	Checks=($( echo "$SWUDiag" | awk 'NR==2{print $0}' ))
	
	if [[ "$Button" == "1" ]]; then
		##	"Install" button was clicked. Run the assess checkbox function
		echo "User clicked the \"Install\" button"
		assessChecks
	else
		echo "User chose to Cancel from the selection dialog."
		echo "Cleaning up SWU list file. Exiting..."
		rm /tmp/SWULIST
		exit 0
	fi
fi

}

##	Function to lock the login window and install all available updates
startLockScreenAgent ()
{

##	Note on this function: To make the script usable outside of a Casper Suite environment,
##	we are using the Apple Remote Management LockScreen.app, located inside the AppleVNCServer bundle.
##	This bundle and corresponding app is installed by default in all recent versions of OS X

##	Set a flag to yes if any updates in the list will require a reboot
while read line; do
	if [[ $(echo "$line" | grep "^◀") != "" ]]; then
		rebootsPresent="yes"
		break
	fi
done < <(echo "$readSWUs")

## Define the name and path to the LaunchAgent plist
PLIST="/Library/LaunchAgents/com.LockLoginScreen.plist"

## Define the text for the xml plist file
LAgentCore="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
	<key>Label</key>
	<string>com.LockLoginScreen</string>
	<key>RunAtLoad</key>
	<true/>
	<key>LimitLoadToSessionType</key>
	<string>LoginWindow</string>
	<key>ProgramArguments</key>
	<array>
		<string>/System/Library/CoreServices/RemoteManagement/AppleVNCServer.bundle/Contents/Support/LockScreen.app/Contents/MacOS/LockScreen</string>
		<string>-session</string>
		<string>256</string>
		<string>-msg</string>
		<string>Updates are currently being installed on this Mac. It will automatically be restarted or returned to the login window when installations are complete.</string>
	</array>
</dict>
</plist>"

## Create the LaunchAgent file
echo "Creating the LockLoginScreen LaunchAgent..."
echo "$LAgentCore" > "$PLIST"

## Set the owner, group and permissions on the LaunchAgent plist
echo "Setting proper ownership and permissions on the LaunchAgent..."
chown root:wheel "$PLIST"
chmod 644 "$PLIST"

## Use SIPS to copy and convert the SWU icon to use as the LockScreen icon

## First, back up the original Lock.jpg image
echo "Backing up Lock.jpg image..."
mv /System/Library/CoreServices/RemoteManagement/AppleVNCServer.bundle/Contents/Support/LockScreen.app/Contents/Resources/Lock.jpg \
/System/Library/CoreServices/RemoteManagement/AppleVNCServer.bundle/Contents/Support/LockScreen.app/Contents/Resources/Lock.jpg.bak

## Now, copy and convert the SWU icns file into a new Lock.jpg file
## Note: We are converting it to a png to preserve transparency, but saving it with the .jpg extension so LockScreen.app will recognize it.
## Also resize the image to 400 x 400 pixels so its not so honkin' huge!
echo "Creating SoftwareUpdate icon as png and converting to Lock.jpg..."
sips -s format png "$swuIcon" --out /System/Library/CoreServices/RemoteManagement/AppleVNCServer.bundle/Contents/Support/LockScreen.app/Contents/Resources/Lock.jpg \
--resampleWidth 400 --resampleHeight 400

## Now, kill/restart the loginwindow process to load the LaunchAgent
echo "Ready to lock screen. Restarting loginwindow process..."
kill -9 $(ps axc | awk '/loginwindow/{print $1}')

## Install all available Software Updates
echo "Screen locked. Installing all available Software Updates..."
/usr/sbin/softwareupdate --install --all

if [ "$?" == "0" ]; then
	## Delete LaunchAgent and reload the Login Window
	echo "Deleting the LaunchAgent..."
	rm "$PLIST"
	sleep 1

	if [[ "$rebootsPresent" == "yes" ]]; then
		## Put the original Lock.jpg image back where it was, overwriting the SWU Icon image
		echo "The rebootsPresent flag was set to 'yes' Replacing Lock.jpg image and immediately rebooting the Mac..."
		mv /System/Library/CoreServices/RemoteManagement/AppleVNCServer.bundle/Contents/Support/LockScreen.app/Contents/Resources/Lock.jpg.bak \
		/System/Library/CoreServices/RemoteManagement/AppleVNCServer.bundle/Contents/Support/LockScreen.app/Contents/Resources/Lock.jpg
	
		## Kill the LockScreen app and restart immediately
		killall LockScreen
		/sbin/shutdown -r now
	else
		## Put the original Lock.jpg image back where it was, overwriting the SWU Icon image
		echo "The rebootsPresent flag was not set. Replacing Lock.jpg image and restoring the loginwindow..."
		mv /System/Library/CoreServices/RemoteManagement/AppleVNCServer.bundle/Contents/Support/LockScreen.app/Contents/Resources/Lock.jpg.bak \
		/System/Library/CoreServices/RemoteManagement/AppleVNCServer.bundle/Contents/Support/LockScreen.app/Contents/Resources/Lock.jpg

		## Kill/restart the login window process to return to the login window
		kill -9 $(ps axc | awk '/loginwindow/{print $1}')
	fi

else

	echo "There was an error with the installations. Removing the Agent and unlocking the login window..."
	
	rm "$PLIST"
	sleep 1
	
	mv /System/Library/CoreServices/RemoteManagement/AppleVNCServer.bundle/Contents/Support/LockScreen.app/Contents/Resources/Lock.jpg.bak \
	/System/Library/CoreServices/RemoteManagement/AppleVNCServer.bundle/Contents/Support/LockScreen.app/Contents/Resources/Lock.jpg
	
	## Kill/restart the login window process to return to the login window
	kill -9 $(ps axc | awk '/loginwindow/{print $1}')
	exit 0
fi

}

##	The script starts here

##	Gather available Software Updates and export to a file
echo "Pulling available Software Updates..."
/usr/sbin/softwareupdate -l > /tmp/SWULIST
echo "Finished pulling available Software Updates into local file"

echo "Checking to see what updates are available..."
##	Generate list of readable items and installable items from file
readSWUs=$( cat /tmp/SWULIST | awk -F"," '/recommended/{print $2,$1}' | sed -e 's/[0-9]*K \[recommended\][ *]//g;s/\[restart\] */◀ /g' | sed 's/[	]//g' )
progSWUs=$( cat /tmp/SWULIST | awk -F"," '/recommended/{print $2,$1}' | sed -e 's/[0-9]*K \[recommended\][ *]//g;s/\[restart\] *//g' | sed 's/[	]//g' )
installSWUs=$( cat /tmp/SWULIST | grep -v 'recommended' | awk -F'\\* ' '/\*/{print $NF}' )

##	First, make sure there's at least one update from Software Update
if [[ -z "$readSWUs" ]]; then
	echo "No pending Software Updates found for this Mac. Exiting..."
	exit 0
elif [[ ! -z "$readSWUs" ]] && [[ "$loggedInUser" != "root" ]]; then
	echo "Software Updates are available, and a user is logged in. Moving to initial dialog..."
	startDialog
elif [[ ! -z "$readSWUs" ]] && [[ "$loggedInUser" == "root" ]]; then
	if [ "$installAllAtLogin" == "yes" ]; then
		echo "SWUs are available, no-one logged in and the installAllAtLogin flag was set. Locking screen and installing all updates..."
		startLockScreenAgent
	else
		echo "SWUs are available, no-one logged in but the installAllAtLogin flag was not set. Exiting..."
		exit 0
	fi
fi
