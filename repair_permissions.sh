#!/bin/bash

## Script name:		repair_permissions.sh
## Script author:	Mike Morales
## Last change:		2015-03-04

## Path to cocoaDialog and the Disk Utility icon (used in the progress bar)
cdPath="/Library/Application Support/JAMF/bin/cocoaDialog.app/Contents/MacOS/cocoaDialog"
diskUtilIcon="/Applications/Utilities/Disk Utility.app/Contents/Resources/DFA.icns"

## The next 3 variables can be set to:
##	a) show a pre message to the user running the policy (showPreamble)
##	b) allow the user to opt out of seeing the pre message for future runs of the policy (allowOptOut)
##	c) send an email to an address or mailing list of any permissions problems that diskutil could not repair (sendMail)
##
## In addition, the emailAddress variable should be set if using option (c) to send email on errors.
## It will be ignored if the sendMail variable is not set to "yes"

## Set the "showPreamble" variable below to "yes" to show a pre message to the user explaining that
## disk permissions repair is not an exact science.
## If you would rather the script skip this message and go straight to running the repair, simply set
## the string for showPreamble to any other value or comment out the line.

showPreamble="yes"

## Set the "allowOptOut" variable below to "yes" to allow the end user to opt out of any future pre message display when they run the
## policy again the next time. With the opt out option enabled by the user, the policy will go straight to the repair process when run again. 

allowOptOut="yes"

## Set the "sendMail" variable below to "yes" to have the script send an email to the email address listed
## under the "emailAddress" variable. Note that this only sends an email in the event the script has detected
## an issue with disk permissions that could not be repaired. Otherwise the script runs the repair and reports
## the results to the end user and exits silently.
## To prevent any emails from being sent, simply set the "sendMail" string to any other value or comment out the line.

sendMail="yes"

## Set the "emailAddress" string below to a valid email or mailing list address to send emails to. Note that this
## variable works in conjunction with the above "sendMail" option. The email will be ignored if sendMail is not set to "yes"

emailAddress="someone@somecompany.com"

## Set the text between the quotes below to what you would like to display to the user as a preamble message.
## The text below can be left in place, or edited to your needs.

startText="Before you begin, its important to understand the following items:

• Some system items may report that they needed a permissions repair repeatedly.
  (This is normal and NOT a cause for concern for your Mac)
• This will only correct permissions in the OS and some applications.
• It will NOT fix permission problems for your account.

If you would like to continue with the repair, click \"Continue\" below. Otherwise, click \"Cancel\" to exit."

## Set the plist name to use for storing the user level setting related to the allowOptOut option above
## Note that this will be ignored if allowOptOut is not set to "yes"

Plist="com.mm2270.dprsetting.plist"

########################################## End of initial script variables ###########################################

## Get the Startup Volume name
startupVol=$( diskutil info / | awk -F':' '/Volume Name/{print $NF}' | sed 's/^ *//' )

## Get the logged in username
loggedInUser=$( ls -l /dev/console | awk '{print $3}' )

function startRepair ()
{

## Set up progress bar elements
exec 20>&-
rm -f /tmp/hpipe
mkfifo /tmp/hpipe
sleep 0.2

## Set up the progress bar
"$cdPath" progressbar --title "" --text " Please wait. Starting repair permissions for \"${startupVol}\"" --width 550 --posY top --float \
--icon-file "$diskUtilIcon" --icon-height 40 --icon-width 40 < /tmp/hpipe &

## Wait just a half sec
sleep 0.5

## Send progress through the named pipe
exec 20<> /tmp/hpipe

/usr/sbin/diskutil repairPermissions -plist "/Volumes/${startupVol}" > /private/tmp/repairdiskprogress.plist &

pct=0
until [[ "$pct" -eq 100 ]]; do
	 sleep 1
	 if [[ $(echo "$dots" | wc -c | sed 's/^ *//') -gt "7" ]]; then
	 	dots=""
	 else
	 	dots="${dots}. "
	 fi
	 pct=$(awk -F'>|<' '/PercentComplete/{getline; print $3}' /private/tmp/repairdiskprogress.plist | tail -1 | cut -d. -f1)
	 if [ ! -z "$pct" ]; then
	 	echo "$pct Please wait. Now repairing permissions for \"${startupVol}\"${dots}" >&20
	 fi
done


if [[ $(awk -F'>|<' '/PercentComplete/{getline; print $3}' /private/tmp/repairdiskprogress.plist | tail -1 | cut -d. -f1) == "100" ]]; then
	## Close the progress bar
	exec 20>&-
	rm -f /tmp/hpipe
	
	## Output a status file of any permissions that were repaired
	awk -F'>|<' '/Status/{getline; print $3}' /private/tmp/repairdiskprogress.plist > "/private/tmp/repairdiskstatusoutput.txt"

## Check for keywords in the status output and set problem flag if any repairs could not be done
	while read status; do
		if [[ $(echo "$status" | egrep -i "could not| not |error|fail") != "" ]]; then
			repairStatus="problem"
		fi
	done < <(cat "/private/tmp/repairdiskstatusoutput.txt")
	
	if [[ "$repairStatus" == "problem" ]] && [[ "$sendMail" == "yes" ]]; then
		textMsg="Disk permissions repair completed for \"${startupVol}\". We detected some problems. A report of this repair has been emailed to your IT administrator.
The information below lists the results:"

	elif [[ "$repairStatus" == "problem" ]] && [[ "$sendMail" != "yes" ]]; then
		textMsg="Disk permissions repair completed for \"${startupVol}\". We detected some problems.
The information below lists the results:"

	else
		textMsg="Disk permissions repair has completed for \"${startupVol}\"
The information below lists the results of the repair:"

	fi
	
	## If any problems were detected and the sendMail option is enabled, send email with details
	
	if [[ "$repairStatus" == "problem" ]] && [[ "$sendMail" ]]; then
		
		## Gather some system details for the email
		MacName=$( scutil --get ComputerName )
		serialNo=$( ioreg -rd1 -c IOPlatformExpertDevice | awk -F'"' '/IOPlatformSerialNumber/{print $4}' )
		
		mailDetails="Disk permissions repair was run from Self Service on ${MacName}.
Problems were detected. Details are below:
		
Mac Name:	${MacName}
Serial Number:	${serialNo}
User:		${loggedInUser}

The repair operation reported:

$(cat /private/tmp/repairdiskstatusoutput.txt)"

		## Send the email with details
		echo "$mailDetails" | mail -s "Disk Permissions Repair problem detected" "$emailAddress"
	fi

	"$cdPath" textbox \
		--title "" \
		--text-from-file "/private/tmp/repairdiskstatusoutput.txt" \
		--informative-text "$textMsg" \
		--button1 "   OK   " \
		--icon info \
		--width 600 \
		--quiet
	
	## Clean up the files created by the repair process
	rm -f "/private/tmp/repairdiskprogress.plist"
	rm -f "/private/tmp/repairdiskstatusoutput.txt"
fi

}


function showPreamble ()
{

## Get user's home directory path
userHome=$( dscl . read /Users/${loggedInUser} NFSHomeDirectory | awk '{print $NF}' )
optOutSetting=$( /usr/bin/defaults read "${userHome}/Library/Preferences/${Plist}" showPreamble 2>/dev/null )

if [[ "$optOutSetting" == "1" ]]; then
	startRepair
fi

if [[ "$allowOptOut" == "yes" ]]; then

	userChoice=$( "$cdPath" checkbox \
		--title "Disk Permissions Repair" \
		--label "$(echo -e "Do you want to start the repair?\n\n$startText")" \
		--items "I understand. Please skip this message next time" \
		--button1 "Continue" \
		--button2 "Cancel" \
		--cancel "button2" \
		--width 550 \
		--posY top \
		--icon info )
else
	userChoice=$( "$cdPath" msgbox \
		--title "Disk Permissions Repair" \
		--text "Do you want to start the repair?" \
		--informative-text "$startText" \
		--button1 "Continue" \
		--button2 "Cancel" \
		--cancel "button2" \
		--width 550 \
		--posY top \
		--icon info )
fi

buttonClicked=$( echo "$userChoice" | awk 'NR==1{print}' )
boxChecked=$( echo "$userChoice" | awk 'NR==2{print}' )

if [[ "$buttonClicked" == "1" ]]; then
	if [[ "$boxChecked" == "1" ]]; then
		/usr/bin/defaults write "${userHome}/Library/Preferences/${Plist}" showPreamble -int 1
		startRepair
	else
		startRepair
	fi
else
	exit 0
fi

}

if [ "$showPreamble" == "yes" ]; then
	showPreamble
else
	startRepair
fi
