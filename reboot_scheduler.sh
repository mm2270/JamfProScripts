#!/bin/bash

## Script name:		reboot_scheduler.sh
## Script author:	Mike Morales
## Last change:		2015-06-04

## Synopsis:

## reboot_scheduler is intended to be used after software updates have been installed on a Mac
## that require a reboot.
## Rather than initiating an immediate reboot of the Mac, or only allowing a short grace period
## before a reboot occurs, the script can be used to prompt the logged in user to select a reboot time
## from a few options in a dialog. (uses cocoaDialog)
##
## Alternately, when the script is being run from a Casper Suite policy, a value in minutes can also be
## passed to the script in Parameter 4 ($4), which will set up a future reboot schedule. In this mode,
## the user is notified of when the 5 minute countdown will begin before their Mac reboots.
##
## In either situation, a LaunchDaemon with a specific StartCalendarInterval and a script will then 
## be created. The LaunchDaemon is set up to run the script at the appointed StartCalendarInterval time,
## which will then start a 5 minute countdown, but only if the Mac has not already been rebooted in
## the interim by the user.

## 	Script exit codes
##
## 0	Script exited successfully
## 1	Some date parameters necessary for the LaunchDaemon could not be determined
## 2	The LaunchDaemon and/or the script could not be created
## 3	The LaunchDaemon could not be loaded (launchctl error)
## 4	cocoaDialog could not be found in the specified location


## Path to cocoaDialog (Edit to match your environment)
cdPath="/Library/Application Support/JAMF/bin/cocoaDialog.app/Contents/MacOS/cocoaDialog"

## The value for mins to reboot. If left blank, we will get the selection from user input or passed in Parameter 4.
mins=""

## If Parameter 4 was assigned a value in the policy, check to see if its a whole integer.
## If true, override the above blank value for hrs with the value assigned to $4.
## If false, retain a blank assignment for the hrs value (user will be prompted to select)

## ***** VERY IMPORTANT!! PLEASE READ *****
## While not a strict requirement, it is recommended that you use values in minutes that are divisible by 60
## to equal whole hours, (ex: For 2 hours, enter "120" for 120 minutes)
##
## If a value is used that is not divisible by 60, the script will use a decimal value to display
## in the dialog presented to the user.
## (ex: 150 minutes will be converted to 1.5 hours as shown to the user)

## 1. 	ONLY PASS A VALUE THAT IS CONVERTED TO MINUTES (ex: To set a value for 2 hours, enter "120" for 120 minutes)
## 2. 	Values passed above 10 will result in a scheduled reboot using the LaunchDaemon.
## 3.   Values passed at or below 10 will result in a reboot timer appearing immediately to the user with a countdown

if [ ! -z "$4" ]; then
	## Check to make sure a whole integer was passed
	if [[ $(echo "$4 / $4" | bc) == "1" ]]; then
		mins="$4"
		echo "Pre-assigned minutes value was assigned: $mins"
	else
		mins=""
	fi
fi

## Set the minutes deferral optons here. Only used if a 'mins' value is not assigned in Parameter 4.
## These are used both in the dialogs and in the resulting scheduled time to reboot.

## ***** VERY IMPORTANT!! PLEASE READ *****
## 1. 	ONLY USE VALUES IN MINUTES FOR ALL THREE 'deferOpt' ITEMS BELOW
## 2. 	ONLY change the values between the quote marks. Do NOT change the values between the brackets []
## 	(Failure to recalculate into a minutes value will result in odd or very short deferrals for reboots occurring)
## 3. 	Start with the longest deferral value and work down. The final value can be set to 10 or lower to initiate an immediate reboot countdown

## Example: To set your longest deferral option to 8 hours, enter a value of "480" for 'deferOpt[0]'

deferOpt[0]="120"		## Longest deferral option (usually results in 'hours')
deferOpt[1]="30"		## Shorter deferral option (still usually results in 'hours')
deferOpt[2]="5"			## Reboot soon option. Recommended not to exceed 10 (minutes). If value is above "10" it will revert to a normal delayed reboot

## Create an array with the assigned values
deferOpts=(${deferOpt[0]} ${deferOpt[1]} ${deferOpt[2]})

## Path to the log file
rdlog="/private/var/log/rdlog.log"

## Start new log file entry with date stamp
echo -e "Start timestamp:	$(date)" | tee -a "$rdlog"

## Sanity check for cocoaDialog
if [ ! -e "$cdPath" ]; then
	echo -e "Error 4: cocoaDialog could not be found at: $cdPath. Exiting...\n" | tee -a "$rdlog"
	exit 4
fi

## Beginning of setDeferral function
function setDeferral ()
{

## Time conversions are done below, based on the value passed in parameter 4
## 1. Calculate specified mins in seconds
hrsSecs=$((mins*60))
#hrsSecs=$((hrs*60))		## Uncomment this variable for testing purposes. Sets scheduled reboot time to minutes instead of hrs
## 2. Get the current time in seconds
currSecs=$(date +"%s")
## 3. Generate scheduled reboot date (current time in seconds + hrs in seconds) in seconds
futureSecs=$((currSecs+hrsSecs))
## 4. Convert scheduled reboot date into 'day_hour_minute_month' format
rDate=$(date -jf "%s" "$futureSecs" +"%d_%H_%M_%m")
## 5. Convert scheduled reboot date into readable format for dialog
rDateFormat=$(date -jf "%s" "$futureSecs" +"%B %d, %Y at %I:%M %p")

## Now use the rDate variable and extract the individual strings to use for the LaunchDaemon
Day=$(echo "$rDate" | awk -F_ '{print $1}' | sed 's/^0//')
Hour=$(echo "$rDate" | awk -F_ '{print $2}' | sed 's/^0//')
Minute=$(echo "$rDate" | awk -F_ '{print $3}' | sed 's/^0//')
MinuteR=$(echo "$rDate" | awk -F_ '{print $3}')
Month=$(echo "$rDate" | awk -F_ '{print $4}' | sed 's/^0//')

## Check all StartCalendarInterval strings to make sure they were generated
if [[ ! -z "$Day" ]] && [[ ! -z "$Hour" ]] && [[ ! -z "$Minute" ]] && [[ ! -z "$Month" ]]; then
	echo -e "Values needed for the LaunchDaemon have been determined" | tee -a "$rdlog"
	echo -e "Values to be used for the LaunchDaemon's StartCalendarInterval:
Day:	$Day
Hour:	$Hour
Minute:	$Minute
Month:	$Month" | tee -a "$rdlog"
	
	echo -e "This Mac will be set to reboot on ${Month}/${Day} at ${Hour}:${MinuteR}:00" | tee -a "$rdlog"
else
	echo -e "Error 1: Some paramaters for the LaunchDaemon StartCalendarInterval could not be obtained. Exiting...\n"  | tee -a "$rdlog"
	exit 1
fi

echo -e "Creating the LaunchDaemon..." | tee -a "$rdlog"
## Create the restart LaunchDaemon using the above values

echo '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.org.rd</string>
	<key>Program</key>
	<string>/private/var/rtimer.sh</string>
	<key>RunAtLoad</key>
	<false/>
	<key>StartCalendarInterval</key>
	<dict>
		<key>Day</key>
		<integer>'$Day'</integer>
		<key>Hour</key>
		<integer>'$Hour'</integer>
		<key>Minute</key>
		<integer>'$Minute'</integer>
		<key>Month</key>
		<integer>'$Month'</integer>
	</dict>
</dict>
</plist>' > "/Library/LaunchDaemons/com.org.rd.plist"


######################################### Begin script creation stage #########################################

## Create a local script for the LaunchDaemon to use
echo "#!/bin/sh

## Set creation date and scheduled reboot timestamp values
cTime=$(date +\"%s\")
rTime=\"$((futureSecs-60))\"

rdlog=\"/private/var/log/rdlog.log\"

## Path to cocoaDialog. Customize path to your needs
cdPath=\"/Library/Application Support/JAMF/bin/cocoaDialog.app/Contents/MacOS/cocoaDialog\"

mins=\"$mins\"

## Calculate specified time in seconds
hrsSecs=\$((mins*60))
#hrsSecs=\$((hrs*60))		## Testing purposes. Comment out
lastReboot=\$(sysctl kern.boottime | awk '{print \$5}' | sed 's/,$//')
currTime=\$(date +\"%s\")
timeDiff=\$((currTime-lastReboot))

function rebootAlert ()
{

echo \"Executing a 5 minute reboot delay...\" | tee -a \"\$rdlog\"
## Begin a 5 minute delayed restart and push to the background
/sbin/shutdown -r +5 &

echo \"Delayed restart exit status: \$(echo \$?)\" | tee -a \"\$rdlog\"

msgText=\"Important software updates were installed on your Mac $rMin $rInc ago that require a reboot to complete.

The grace period for a reboot chosen has now expired and your Mac must reboot to finish these updates.
Please save any open work within the next 5 minutes to avoid any data loss. Your Mac will automatically reboot once 5 minutes has passed.\"

buttonLabel=\"    OK    \"

icon=\"/System/Library/CoreServices/loginwindow.app/Contents/Resources/Restart.tiff\"

## Show the reboot required message with a 5 minute countdown
\"\$cdPath\" msgbox --title \"\" --text \"Your Mac's reboot grace period has expired\" --informative-text \"\$msgText\" --width 450 --icon-file \"\$icon\" --button1 \"\$buttonLabel\" --posY top --timeout 297 --quiet

echo \"Cleaning up. Deleting LaunchDaemon...\" | tee -a \"\$rdlog\"
rm -f \"/Library/LaunchDaemons/com.org.rd.plist\"
rm -f \"\$0\"

exit 0

}

function cleanUp ()
{

echo \"Cleaning up...\\n\" | tee -a \"\$rdlog\"

rm -f \"/Library/LaunchDaemons/com.org.rd.plist\"
/bin/launchctl remove com.org.rd.plist
rm -f \"\$0\"

exit 0

}

## Find out if we actually need to reboot the Mac by checking how long the Mac's been up.
## 1. Compare the last boot time in seconds with the creation timestamp of the script (in Unix seconds).
## 		a) 	If the creation timestamp value is lower than the last boot time, it means the Mac has been
## 			rebooted since the script was created. There is no need for a reboot. Move to cleanup stage.
## 		b)	If the creation timestamp value is higher than the last boot time, the Mac has not been
##			rebooted since the script creation date. Move to step 2...
## 2. Check the current time in seconds to see if it is lower or higher than the scheduled reboot time.
##		a)	If the current time in seconds is less than the scheduled reboot time, exit.
##		b)	If the current time in seconds is equal or higher than the scheduled reboot time, we need to
##			reboot the Mac. Begin the rebootAlert function.

if [[ \"\$cTime\" -lt \"\$lastReboot\" ]]; then
	echo \"This Mac has been rebooted within the last $rMin $rInc. No action required. Cleaning up silently...\" | tee -a \"\$rdlog\"
	cleanUp
elif [[ \"\$(date +\"%s\")\" -lt \"\$rTime\" ]]; then
	echo \"We haven't reached the time to reboot. Exiting...\\n\" | tee -a \"\$rdlog\"
	exit 0
else
	echo \"This Mac has not been rebooted within the last $rMin $rInc. Action required. Starting reboot process...\" | tee -a \"\$rdlog\"
	rebootAlert
fi" > /private/var/rtimer.sh

######################################### End of script creation stage #########################################

## Finish up by checking status of LaunchDaemon and local script and load the LaunchDaemon
if [[ -e "/Library/LaunchDaemons/com.org.rd.plist" ]] && [[ -e "/private/var/rtimer.sh" ]]; then
	## Set permissions on the plist
	echo -e "LaunchDaemon and script were successfully created. Correcting permissions on LaunchDaemon..." | tee -a "$rdlog"
	chown root:wheel "/Library/LaunchDaemons/com.org.rd.plist"
	chmod 644 "/Library/LaunchDaemons/com.org.rd.plist"
	chflags hidden "/Library/LaunchDaemons/com.org.rd.plist"
	
	## Make the script executable
	echo -e "Making the script executable..." | tee -a "$rdlog"
	chmod +x "/private/var/rtimer.sh"
	
	## Now unload and load the LaunchDaemon
	## (We do an unload in the event the new LaunchDaemon is overwriting an older one. This ensures the new job settings are properly loaded into launchd)
	/bin/launchctl unload "/Library/LaunchDaemons/com.org.rd.plist" 2>/dev/null
	/bin/launchctl load "/Library/LaunchDaemons/com.org.rd.plist"
	
	if [ "$?" == "0" ]; then
		echo -e "LaunchDaemon loaded successfully" | tee -a "$rdlog"
	else
		echo -e "Error 3: LaunchDaemon could not be loaded. launchctl error code: $?" | tee -a "$rdlog"
		exit 3
	fi
else
	echo -e "Error 2: LaunchDaemon or script could not be created. Exiting...\n" | tee -a "$rdlog"
	exit 2
fi

if [ "$preassigned" ]; then

	header="A required reboot has been scheduled"
	
	rebootSetText="Your administrator has installed important updates on your Mac that require a reboot.

However, to give you a grace period on this reboot, your Mac has been set up to reboot $mins minutes ($rMin $rInc) from now, on $rDateFormat. You will see a reminder 5 minutes before the reboot to give you time to close any open work.

If you reboot your Mac prior to this date, you will not be asked to reboot again at the appointed time."


else

	header="A reboot deferral has been set"
	
	rebootSetText="Thank you!

Your Mac has been set up to reboot ${deferOpt[$userSelection]} minutes ($rMin $rInc) from now, on $rDateFormat. You will see a reminder 5 minutes before the reboot to give you time to close any open work.

If you reboot your Mac prior to this date, you will not be asked to reboot again at the appointed time."

fi

"$cdPath" msgbox \
	--title "" \
	--text "$header" \
	--informative-text "$rebootSetText" \
	--button1 "    OK    " \
	--width 450 \
	--posY top \
	--icon info \
	--quiet

exit 0

}
## End of setDeferral function

## Beginning of rebootSoon function
function rebootSoon ()
{

## Convert the mins var into seconds for the timeout of the dialog
timeoutSecs=$(($mins*60))

icon="/System/Library/CoreServices/loginwindow.app/Contents/Resources/Restart.tiff"

if [ "$preassigned" ]; then
	rebootSoonHead="Your Mac has been scheduled to reboot soon"
	
	rebootSoonText="Important updates have been installed on your Mac that require a reboot, which your administrator has scheduled to occur in the next $mins minutes.

Please save any open work within the next $mins minutes to avoid any data loss. You can choose to leave this window open, or close it. The $mins minute countdown will continue in the background."

	rDelayTime="${deferOpt[$userSelection]}"
	echo "reboot delay is ${rDelayTime}"
else
	rebootSoonHead="You chose to reboot in $mins minutes" | tee -a "$rdlog"
	
	rebootSoonText="Please save any open work within the next $mins minutes to avoid any data loss. You can choose to leave this window open, or close it. The $mins minute countdown will continue in the background."
	
	rDelayTime="$mins"
	echo "reboot delay is ${rDelayTime}" | tee -a "$rdlog"
fi

echo -e "Beginning ${rDelayTime} minute reboot delay" | tee -a "$rdlog"

## Begin delayed restart and push to the background
/sbin/shutdown -r +${rDelayTime} &

"$cdPath" msgbox \
	--title "" \
	--text "$rebootSoonHead" \
	--informative-text "$rebootSoonText" \
	--width 450 \
	--icon-file "$icon" \
	--button1 "    OK    " \
	--posY top \
	--timeout "$timeoutSecs" \
	--quiet

exit

}

## A couple of sanity checks are performed to see if we need to actually schedule anything

## Get the logged in user name and UID
loggedInUser=$(ls -l /dev/console | awk '{print $3}')
loggedInID=$(id "$loggedInUser" | tr ' ' '\n' | awk -F'[=|(]' '/uid/{print $2}')

## Check to see if someone is actually logged in
if [[ "$loggedInUser" == "root" ]] && [[ "$loggedInID" == "0" ]]; then
	echo -e "No user is currently logged in on this Mac. We can reboot immediately" | tee -a "$rdlog"
	
	## If the Mac is sitting at a login screen, just reboot right away
	shutdown -r now
else
	echo -e "A user \"$loggedInUser\" is logged in on this Mac. Proceeding..." | tee -a "$rdlog"
fi

## Check to see if a previous scheduled reboot has been set up
if [ -e "/Library/LaunchDaemons/com.org.rd.plist" ]; then
	if [[ $(/bin/launchctl list | grep "com.org.rd") != "" ]]; then
		echo -e "This Mac has already been set up to reboot at a future date. We will not create an additional schedule." | tee -a "$rdlog"
		exit 0
	fi
fi


## Set up text for dialog
askRebootText="Important Software Updates were just installed on your Mac. Some of these updates require a reboot to complete.

However, you have the option of deferring the reboot to one of the options below. Please make a choice and click Continue."

if [ -z "$mins" ]; then

	## Loop over array and create strings and variables to use for dialog
	NO=0
	for OPT in "${deferOpts[@]}"; do
		if [[ "$OPT" -gt "60" ]]; then
			incW[$NO]="hours"
			deferRaw=$(echo "scale=1; $OPT/60" | bc)
			if [[ "${deferRaw##*.}" == "0" ]]; then
				defer[$NO]="${deferRaw%.*}"
			else
				defer[$NO]="${deferRaw}"
			fi
		elif [[ "$OPT" == "60" ]]; then
			incW[$NO]="hour"
			defer[$NO]=$((OPT/60))
		else
			incW[$NO]="minutes"
			defer[$NO]="$OPT"
		fi
		NO=$((NO+1))
	done
	
	echo -e "No pre-assigned deferral was set for the script. Prompting user for input..." | tee -a "$rdlog"
	userChoice=$( "$cdPath" radio \
		--title "" \
		--label "$askRebootText" \
		--button1 "Continue" \
		--items "${defer[0]} ${incW[0]} from now" "${defer[1]} ${incW[1]} from now" "${defer[2]} ${incW[2]} from now" \
		--width 450 \
		--posY top \
		--icon caution \
		--value-required \
		--empty-text "Choose one of the deferral options before clicking \"Continue\"" \
		--timeout 300 \
		--timeout-format " " )

	userSelection=$( echo "$userChoice" | awk 'NR==2{print}' )

	if [ ! -z "$userSelection" ]; then
		mins="${deferOpt[$userSelection]}"
		rMin="${defer[$userSelection]}"
		rInc="${incW[$userSelection]}"
		echo -e "User chose a $mins minute deferral for reboot" | tee -a "$rdlog"
		
		if [[ "$mins" -gt 10 ]]; then
			setDeferral
		else
			rebootSoon
		fi
	else

		## If the cocoaDialog message was quit by the user without making a selection
		## set a default value equal to the longest allowed deferral and create the LaunchDaemon/script
		mins="${deferOpt[0]}"
		rMin="${defer[0]}"
		rInc="${incW[0]}"
		echo -e "The dialog exited (timed out or user quit), so we're setting a default $mins minute deferral" | tee -a "$rdlog"
		setDeferral
	fi
	
else

	## If we got a pre-assigned mins value, skip user input, create some variables, and display the restart set dialog
	preassigned="yes"
	echo -e "A pre-assigned value was defined by \$4" | tee -a "$rdlog"
	
	if [[ "$mins" -gt "60" ]]; then
		rMinRaw=$(echo "scale=1; $mins/60" | bc)
		if [[ "${rMinRaw##*.}" == "0" ]]; then
			rMin="${rMinRaw%.*}"
		else
			rMin="${rMinRaw}"
		fi
		rInc="hours"
	elif [[ "$mins" == "60" ]]; then
		rMin=$((mins/60))
		rInc="hour"
	elif [[ "$mins" -lt "60" ]]; then
		rMin="$mins"
		rInc="minutes"
	fi
	
	if [[ "$mins" -gt 10 ]]; then
		setDeferral
	else
		echo "A pre-assigned value was passed to the script that was at or below 10 minutes." | tee -a "$rdlog"
		rebootSoon
	fi
fi
