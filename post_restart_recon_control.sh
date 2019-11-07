#!/bin/bash

## Script Name:     post_restart_recon_control.sh
## Version:         1.1
## Authored by:     Mike Morales (mm2270 - JamfNation)
## Change Log:
##  2019-Sept-03:   Initial script creation
##  2019-Nov-05:    Added maxAttempts variable to allow for a more/less number of reconnection attempts to be set
##                  Added additional comments to explain some of the script better


## Purpose: to deploy (create) a LaunchDaemon and companion local script to a Mac that can be called into action later thru the use of a control plist file
##
## How this script works:
## • A local script and LaunchDaemon are both created using the included information in this script.
## • The scripts name is set to "postrestart.recon.sh" and is created in /private/var/
## • It is partially customized at the time of creation by using the 2 variables below, 'yourOrg' and 'maxAttempts'
## • The LaunchDaemon's identifier is partially customized on creation using the 'yourOrg' variable below
## • The LaunchDaemon is not loaded after creation (it will load automatically on the next reboot)


## How the post reboot recon process works once in place:
## 1. The LaunchDaemon calls the script on initial run (only runs once), which typically means after a restart.
## 2. The script looks for a local plist file (/Library/Preferences/com.$yourOrg.postrestart.reconcontrol.plist) The plist has a simple boolean value for a post reboot recon.
## 3a. If the value is set to TRUE or 1, the script will attempt to connect to the machine's Jamf Pro server and perform a recon. (See point 4 for alternate response)
## 3b. It will loop up to 30 times, pausing 1 second between each attempt while trying to connect to the Jamf Pro server. If it cannot connect in 30 attempts, it exits.
## 3c. If connection is successful, the recon is performed and the plist value is changed to FALSE or 0.
## 4. If the plist does not exist, the script performs the same steps as above, a recon but then creating a new plist and setting the value to FALSE or 0.
##
## After initial deployment, and first use, the LaunchDaemon remains active, and the LaunchDaemon and script remain on the computer.
## They only spring into action if the control plist is modified through some other means, such as a command run at the completion of a Jamf Pro policy.


## Usage:
## The plist value can be changed with a simple shell command added to a policy to set the plist value to TRUE, which means a recon will be attempted after the next restart.
##
## Example of shell command to enable a post reboot recon (entered into the EXECUTE COMMAND field in a Jamf policy):
## 		/usr/bin/defaults write /Library/Preferences/com.acme.postrestart.reconcontrol.plist PerformRecon -bool TRUE
##
## Note: the 'acme' portion of the plist name must be changed to the shortname of your organization entered below in the 'yourOrg' value


## Set a value for your organization name. Keep this short, like an acronym if possible.
## No special characters as they might cause a problem with the final xml file.
## Lowercase text works best but is not a requirement.
yourOrg="acme"


## The value below determines how many connection attempts to the Mac's Jamf Pro server the script should make before finally giving up.
## The default is 30, which comes to approximately 30 seconds of attempts. If you feel this is too short, enter a higher integer value here. Enter a whole number only, such as "60"
## Considerations:
## Please keep in mind to put in a reasonable value, so the LaunchDaemon is not retrying to connect endlessly, eating up resources.
## Likewise, be cautious not to set this too low. Since the script is called by a LaunchDaemon, it will fire up right after the Mac starts up. If the Mac doesn't connect to an
## internet connection until after it gets to the Desktop (ex: Wi-Fi), setting this too low may cause the recon to never occur.
maxAttempts="30"


####################################################################################################################################################################################
## Items below this line should not be altered, unless you are sure of what changes you need to make
####################################################################################################################################################################################


## Data for the LaunchDaemon
LAUNCHD_PLIST='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.'${yourOrg}'.postrestart.recon</string>
	<key>ProgramArguments</key>
	<array>
		<string>/private/var/postrestart.recon.sh</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
</dict>
</plist>'

## Path to the local control plist file
CONTROL_PLIST="/Library/Preferences/com.${yourOrg}.postrestart.reconcontrol.plist"

## Path to the local script that is run by the LaunchDaemon
LOCAL_SCRIPT_LOCATION="/private/var/postrestart.recon.sh"

## Data for the local script to be created
LOCAL_SCRIPT='#!/bin/bash

CONTROL_PLIST="/Library/Preferences/com.'${yourOrg}'.postrestart.reconcontrol.plist"

function reconLoop ()
{

SERVER_TEST=$(/usr/local/bin/jamf checkJSSConnection 2>&1 > /dev/null; echo $?)

## The script will make up to '${maxAttempts}' attempts to contact the Jamf server before exiting, or will perform the recon once it establishes a connection
until [[ $x -eq '${maxAttempts}' ]]; do
	## If the jamf checkJSSConnection exited with a 0 status, perform a recon...
	if [[ "$SERVER_TEST" == 0 ]]; then
		/usr/local/bin/jamf recon
		sleep 1
		## Update the plist value to false to prevent an additional unintended run
		/usr/bin/defaults write "$CONTROL_PLIST" PerformRecon -bool FALSE
		## Make sure the plist can be written to later with a policy
		chmod 755 "$CONTROL_PLIST"
		exit 0
	else
		## If the jamf checkJSSConnection did not exit 0, wait 1 second before looping
		echo "Pausing 1 second to wait for Jamf server to be available"
		sleep 1
	fi
	((x++))
done

}

## Check if the plist file exists, and if a value can be pulled from it
if [ -e "$CONTROL_PLIST" ]; then
	VALUE=$(/usr/bin/defaults read "$CONTROL_PLIST" PerformRecon 2>/dev/null)
	## If the value is set to true, or there was no value set...
	if [[ "$VALUE" == "1" ]] || [[ -z "$VALUE" ]]; then
		## ...set an initial loop integer value, and move on to the recon loop function
		x=1
		reconLoop
	else
		## If the value is set to anything other than true or not null, exit the process without performing a recon
		echo "No post restart recon required. Exiting..."
		exit 0
	fi
else
	echo "No plist file found. Performing a recon loop just in case. The plist file will be created after completion"
	reconLoop
fi'

## Create the local script
cat << EOS > "$LOCAL_SCRIPT_LOCATION"
${LOCAL_SCRIPT}
EOS

## Ensuree the local script is executable
/bin/chmod +x "$LOCAL_SCRIPT_LOCATION"

## Create the LaunchDaemon
cat << EOD > /Library/LaunchDaemons/com.${yourOrg}.postrestart.recon.plist
${LAUNCHD_PLIST}
EOD

## Set the proper owner/group and POSIX permissions on the LaunchDaemon plist
/usr/sbin/chown root:wheel /Library/LaunchDaemons/com.${yourOrg}.postrestart.recon.plist
/bin/chmod 644 /Library/LaunchDaemons/com.${yourOrg}.postrestart.recon.plist

echo "LaunchDaemon and script creation completed."
exit 0
