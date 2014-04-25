#!/bin/bash

## Script name:
## installLatestFlashPlayer.sh
##
## Script author:
## Mike M (@mm2270 on JAMFNation) email: mm2270 [at] me [dot] com
## 
## Acknowledgements:
## This script is based on the general concept developed by Rich Trouton in his script at:
## https://github.com/rtrouton/rtrouton_scripts/blob/master/rtrouton_scripts/install_latest_adobe_flash_player/install_latest_adobe_flash_player.sh
##
## The XML URL for determining the current release Flash Player version was taken from the work
## done by the AutoPkg team in their FlashPlayer recipe
##
## Description:
## This script will update FlashPlayer to the latest public release from Adobe by getting the
## release version information from Adobe's site, and comparing it to the installed version
## (even if its not installed), and if necessary, pull down the latest install DMG from Adobe,
## silently mounting and running the pkg install and finally, comparing the end results to
## ensure the installation succeeded.
##
## Notes:
## 1) 	If you prefer not to install Flash Player on a system that does not currently have any
## 		version installed, simply set the "installNew" flag appropriately. See description below.
##
## 2)	For any Macs that may actually have a newer version of FlashPlayer installed than the public
## 		release, such as anyone signed up with Adobe to test beta releases, the script will skip
## 		installing an older version, thus avoiding downgrading the client.
##
## 3)	This script makes use of the Adobe Flash Player distribution URL for downloading a
## 		deployable pkg installer. You must sign up with Adobe for a license to use this installation at:
## 		http://www.adobe.com/products/players/flash-player-distribution.html
##		IMPORTANT: I am not responsible for your use of this script WITHOUT signing up for Adobe's
##		distribution license. It is YOUR responsibility to make sure you are remaining legal.

## Start of script

## Set the flag for installing Flash Player "new" on systems rather than just upgrades.
## Usage:	Set the flag to "yes" (case sensitive) to allow new FlashPlayer installations.
## 			Set the flag to "no" (case insensitive), leave it blank, or enter any other string
##			besides "yes" if you would like to skip new installs
##
installNew="yes"

## Function section for downloading the latest Flash Player installer and running the installation
function downloadFP ()
{

# Download latest Flash Player DMG to a file in /tmp/
echo "Downloading Flash Player DMG..."
/usr/bin/curl -s "$FP_downloadURL" -o /tmp/InstallFlashPlayer.dmg

## Mount the downloaded disk image and capture the mounted volume name as a variable we can use for the next steps
echo "Silently mounting Flash Player Installer disk image..."
FPInstallVol=$( /usr/bin/hdiutil attach /tmp/InstallFlashPlayer.dmg -nobrowse -noverify -noautoopen 2>&1 | awk -F'[\t]' '/\/Volumes/{ print $NF }' )

echo "Silently installing Flash Player from pkg..."

## Install the FlashPlayer pkg while reading output from installer
## Check for the successful upgrade line to set the installation status
installStatus=1
while read line; do
	echo "	$line"
	if [[ $( echo "$line" | egrep "The upgrade was successful|The install was successful" ) ]]; then
		installStatus=0
	fi
done < <(/usr/sbin/installer -pkg "${FPInstallVol}/Install Adobe Flash Player.pkg" -tgt / 2>&1)

## Pause 2 seconds to allow installation to finish out
sleep 2

## Now check the installation results
if [[ "$installStatus" == "0" ]]; then
	echo "Flash Player installation was successful. Checking new version for confirmation..."
	
	FP_newVers=$( /usr/bin/defaults read /Library/Internet\ Plug-Ins/Flash\ Player.plugin/Contents/Info CFBundleShortVersionString )
	
	if [[ "${FP_newVers}" == "${FP_releasedVers}" ]]; then
		echo "Confirmed current version is now ${FP_releasedVers}..."
		exit_status=0
	else
		echo "New version and latest version do not match. Installation may have failed..."
		exit_status=1
	fi
else
	echo "Installation exited with an error code. Install failed..."
	exit_status=1
fi
		
## Clean up (we do this regardless of the installation result so as not to leave downloads around in /tmp/)

echo "Cleaning up. Force ejecting the 'Flash Player' volume..."
/usr/bin/hdiutil eject -force "${FPInstallVol}"

echo "Deleting downloaded disk image..."
rm -rf "/tmp/InstallFlashPlayer.dmg"

exit $exit_status

}


## Get the current version for flash from the Adobe website
echo "Getting the current version of FlashPlayer from Adobe..."
FP_releasedVers=$( curl -s http://fpdownload2.macromedia.com/get/flashplayer/update/current/xml/version_en_mac_pl.xml | xpath /XML/update[1] 2>&1 | awk -F'"' '{print $2}' | sed -e '/^$/d;s/,/./g' )

echo "Current Flash Player version from Adobe's site is: ${FP_releasedVers}..."

## Extract the major version number from the long version string
echo "Getting the majpr FlashPlayer version number..."
FP_majVers=$( echo "$FP_releasedVers" | cut -d. -f1 )

## Set the download URL
echo "Setting the FlashPlayer download URL..."
FP_downloadURL="http://fpdownload.macromedia.com/get/flashplayer/current/licensing/mac/install_flash_player_${FP_majVers}_osx_pkg.dmg"
echo "Download URL set to ${FP_downloadURL}..."

echo "Checking the installed version of Flash Player on this Mac..."
## Get the currently installed version of FlashPlayer
if [[ -e "/Library/Internet Plug-Ins/Flash Player.plugin" ]]; then
	FP_installedVers=$( /usr/bin/defaults read "/Library/Internet Plug-Ins/Flash Player.plugin/Contents/Info" CFBundleShortVersionString )
	echo "Installed Flash Player plug-in version is: ${FP_installedVers}..."
else
	FP_installedVers="0"
fi

## Here we generate two normalized version strings that can be used in an integer comparison later.
## These variables help account for some Adobe numbering oddities that would otherwise make it impossible to do a correct version comparison
FP_installedNormalized=$( printf "%s%02d\n" $(echo "$FP_installedVers" | sed -e 's/00//;s/[.]//g') | cut -c 1-7 )
FP_releasedNormalized=$( printf "%s%02d\n" $(echo "$FP_releasedVers" | sed -e 's/00//;s/[.]//g') | cut -c 1-7 )

echo "Normalized installed version is: $FP_installedNormalized"
echo "Normalized released version is: $FP_releasedNormalized"

## Check to see if the version was set to "0" meaning not installed and also if we set the installNew flag and take appropriate next steps
echo "Determining any version difference..."

	## Using the normalized version strings, check to see if the installed version is somehow higher than the current public release version.
	## This can happen if someone is signed up with Adobe Labs to install beta versions of FlashPlayer. We don't want to downgrade them ;)
	if [[ "${FP_installedNormalized}" -gt "${FP_releasedNormalized}" ]]; then
		echo "Installed version, ${FP_installedVers} is higher than the public version, ${FP_releasedVers}. This Mac may be running a beta release. Exiting..."
		exit 0
	fi
	
	## If the version is "0", then Flash Player is not installed
	if [[ "${FP_installedVers}" == "0" ]]; then
		## Check to see what the installNew flag is set to
		if [[ "$installNew" == "yes" ]]; then
			## installNew flag is set, so download and install it
			echo "Flash Player is not currently installed on this Mac. Downloading and installing..."
			downloadFP
		else
			## installNew flag was not set, so exit
			echo "Flash Player is not currently installed on this Mac, but we are instructed to skip new installs. Exiting..."
			exit 0
		fi
	fi
	
	
	if [[ "${FP_installedNormalized}" -lt "${FP_releasedNormalized}" ]]; then
		## Flash Player is installed, but is not up to date. Download and install
		echo "Flash Player is not up to date. Downloading and installing..."
		downloadFP
	fi
	
	if [[ "${FP_installedVers}" == "${FP_releasedVers}" ]]; then
		## Flash Player is installed, but matches the current release. Up to date, so exit
		echo "Flash Player is installed and already up to date. Exiting..."
		exit 0
	fi