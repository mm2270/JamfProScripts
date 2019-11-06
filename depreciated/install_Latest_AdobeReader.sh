#!/bin/bash

## Script Name:		install_Latest_AdobeReader.sh
## Author:			Mike Morales
## Last Change:		2014-05-16
## Compatibility:	Intel OS X (10.6.x - 10.9.x)

## IMPORTANT: This script assumes installation of the Intel version of Adobe Reader on an Intel based Mac.
## It does not do architecture checking in the script, although I may possibly include such a check in a future version.

## Set this flag to "yes" if you would like new installs of Adobe Reader on systems that do not currently have
## any version of Adobe Reader installed. If you leave it blank or set it to 'no' it will skip the installation.
installNew="yes"

## Function section for downloading the latest Flash Player installer and running the installation
function downloadAR ()
{

# Download latest Adobe Reader DMG to a file in /tmp/
echo "Download URL set to: http://ardownload.adobe.com/pub/adobe/reader/mac/${ARCurrMajVers}.x/${ARCurrVersFull}/misc/${AR_DMG}"
echo "Downloading Adobe Reader DMG..."

## Download the DMG using curl and the URL set
curl -s -f "http://ardownload.adobe.com/pub/adobe/reader/mac/${ARCurrMajVers}.x/${ARCurrVersFull}/misc/${AR_DMG}" -o "/tmp/${AR_DMG_DL}"

## Check the exit status of the curl command
if [[ "$?" != "0" ]]; then
	echo "Curl operation failed. Site may be blocked or unavailable right now. Exiting with code 1..."
	exit 1
fi

## Mount the downloaded disk image and capture the mounted volume name as a variable we can use for the next steps
echo "Silently mounting Adobe Reader Installer disk image..."
ARInstallVol=$( /usr/bin/hdiutil attach "/tmp/${AR_DMG_DL}" -nobrowse -noverify -noautoopen 2>&1 | awk -F'[\t]' '/\/Volumes/{ print $NF }' )

## Check the exit status of the mount operation
if [[ "$?" == "0" ]]; then
	## Get the pkg name from the mounted volume
	AR_PKG=$( ls "${ARInstallVol}" | grep ".pkg$" )
	
	echo "Silently installing Adobe Reader from pkg..."

	## Install the Adobe Reader pkg while reading output from installer
	## Check for the successful upgrade line to set the installation status
	installStatus=1
	while read line; do
		echo "	$line"
		if [[ $( echo "$line" | egrep "The upgrade was successful|The install was successful" ) ]]; then
			installStatus=0
		fi
	done < <(/usr/sbin/installer -pkg "${ARInstallVol}/${AR_PKG}" -tgt / 2>&1)

	## Pause 2 seconds to allow installation to finish out
	sleep 2

	## Now check the installation results
	if [[ "$installStatus" == "0" ]]; then
		echo "Adobe Reader installation was successful. Checking new version for confirmation..."

		## Get the new version number from disk to ensure it matches the expected current version
		AR_newVers=$( /usr/bin/defaults read "/Applications/Adobe Reader.app/Contents/Info" CFBundleShortVersionString )

		if [[ "${AR_newVers}" == "${ARCurrVersFull}" ]]; then
			echo "Confirmed current version is now ${ARCurrVersFull}..."
			exit_status=0
		else
			echo "New version and latest version do not match. Installation may have failed..."
			exit_status=1
		fi
	else
		## If we didn't get a status 0 returned from the installation, exit with an error code
		echo "Installation exited with an error code. Install failed..."
		exit_status=1
	fi

	## Clean up (we do this regardless of the installation result so as not to leave downloads around in /tmp/)

	echo "Cleaning up. Force ejecting the Adobe Reader install volume..."
	/usr/bin/hdiutil eject -force "${ARInstallVol}"

	echo "Deleting downloaded disk image..."
	rm -rf "/tmp/${AR_DMG_DL}"

	exit $exit_status

else

	## If mounting the disk image failed, clean up partial/broken download and exit until next run
	echo "Could not mount the downloaded disk image. Cleaning up and exiting with status 1..."
	rm -rf "/tmp/${AR_DMG_DL}"
	exit 1
fi

}


## Script starts here

## Get OS version and adjust for use with the URL string
OSvers_URL=$( sw_vers -productVersion | sed 's/[.]/_/g' )

## Set the User Agent string for use with curl
userAgent="Mozilla/5.0 (Macintosh; Intel Mac OS X ${OSvers_URL}) AppleWebKit/535.6.2 (KHTML, like Gecko) Version/5.2 Safari/535.6.2"

## Get the current release version from Adobe by curling the site as a browser
ARCurrVersFull=$( curl -s -A "$userAgent" http://get.adobe.com/reader/ | grep "<strong>Version" | awk -F'[(|)]' '{print $2}' )

## Get the installed version string
ARVersFull=$( defaults read /Applications/Adobe\ Reader.app/Contents/Info CFBundleShortVersionString 2> /dev/null )

## Check to see if we got any version returned. If not, set it to "0"
if [[ -z "${ARVersFull}" ]]; then
	ARVersFull="0"
fi

## Get the first set of digits from the current version string
ARCurrMajVers=$( echo "${ARCurrVersFull}" | cut -d. -f1 )
echo "The Adobe Reader major version number is:		$ARCurrMajVers"

## Echo back what we pulled
echo "The Adobe Reader current released version is: 		$ARCurrVersFull"
echo "The Adobe Reader current installed version on disk is:	$ARVersFull"

## Normalize the version strings for use in integer comparison
ARCurrVersNormalized=$( echo "$ARCurrVersFull" | sed 's/[.]//g' )
ARVersNomalized=$( echo "$ARVersFull" | sed 's/[.]//g' )

## Debug lines
echo "${ARCurrVersNormalized}"
echo "${ARVersNomalized}"

## Set the DMG name based on the available information and the file name we will curl to
AR_DMG="AdbeRdrUpd${ARCurrVersNormalized}.dmg"
AR_DMG_DL="AdobeReader.dmg"

## Check to see if the version was set to "0" meaning not installed and also if we set the installNew flag and take appropriate next steps
echo "Determining any version difference..."

## Using the normalized version strings, check to see if the installed version is somehow higher than the current public release version.
## This can happen if someone is signed up with Adobe Labs to install beta versions of FlashPlayer. We don't want to downgrade them ;)
if [[ "${ARVersNomalized}" -gt "${ARCurrVersNormalized}" ]]; then
	echo "Installed version, ${ARVersNomalized} is higher than the public version, ${ARCurrVersNormalized}. This Mac may be running a beta release. Exiting..."
	exit 0
fi

## If the version is "0", then Flash Player is not installed
if [[ "${ARVersFull}" == "0" ]]; then
	## Check to see what the installNew flag is set to
	if [[ "$installNew" == "yes" ]]; then
		## installNew flag is set, so download and install it
		echo "Adobe Reader is not currently installed on this Mac. Downloading and installing..."
		downloadAR
	else
		## installNew flag was not set, so exit
		echo "Adobe Reader is not currently installed on this Mac, but we are instructed to skip new installs. Exiting..."
		exit 0
	fi
fi

if [[ "${ARVersNomalized}" -lt "${ARCurrVersNormalized}" ]]; then
	## Adobe Reader is installed, but is not up to date. Download and install
	echo "Adobe Reader is not up to date. Downloading and installing..."
	downloadAR
fi

if [[ "${ARVersFull}" == "${ARCurrVersFull}" ]]; then
	## Adobe Reader is installed, but matches the current release. Up to date, so exit
	echo "Adobe Reader is installed and already up to date. Exiting..."
	exit 0
fi
