#!/bin/bash

## Script:			  install_select_SS_plug-ins.sh
## Author:			  Mike Morales
## Last change:		2015-01-13

## Path to cocoaDialog. Configure for your environment
cdPath="/library/Application Support/JAMF/bin/cocoaDialog.app/Contents/MacOS/cocoaDialog"

## Common strings used in dialogs. Customize to your needs
msgTitle="Self Service Sidebar Shortcuts"
SSIcon="/Applications/Self Service.app/Contents/Resources/Self Service.icns"

## Paths to various directories
tmpPluginsDir="/private/tmp/plug-ins_for_install"
SSRootDir="/Library/Application Support/JAMF/Self Service/"
SSPluginsDir="/Library/Application Support/JAMF/Self Service/Plug-ins/"

## Sanity check. Make sure the tmpPluginsDir is there, or else alert and exit
if [ ! -d "$tmpPluginsDir" ]; then
	echo "The folder with Plug-ins was not found in the expected location. The installer pkg may have failed"
	
	"$cdPath" msgbox \
		--title "$msgTitle" \
		--text "There was a problem" \
		--informative-text "$(echo -e "It looks like the installation failed.\nYou can try running the policy again.\n\nIf you continue to see this error, contact the Help Desk for assistance.")" \
		--button1 "   OK   " \
		--icon caution \
		--width 400 \
		--posY top \
		--quiet
	
	exit 1
fi

## Generate two arrays based on the plist files located in the tmp directory
for plist in $(ls "${tmpPluginsDir}" | grep "plist$"); do
	## Get the file name and title from each plist
	ID=$(basename "$plist")
	Title=$(defaults read "${tmpPluginsDir}/${plist}" title)
	## Generate the two arrays from the above information
	plugInIDs+=("$ID")
	plugInTitles+=("$Title")
done

labelText="Choose the Self Service URLs you would like to install from the items below."

## Display the selections to the user
userChoices=$("$cdPath" checkbox \
	--title "$msgTitle" \
	--items "${plugInTitles[@]}" \
	--label "$labelText" \
	--button1 " Choose " \
	--button2 " Cancel " \
	--cancel "button2" \
	--value-required \
	--empty-text "At least one item must be checked before clicking \"Choose\". Or, click \"Cancel\" if you want to exit." \
	--icon-file "$SSIcon" \
	--width 400 \
	--posY top)

## Get the button clicked and the boxes checked
buttonClicked=$(echo "$userChoices" | awk 'NR==1 {print}')
boxesChecked=($(echo "$userChoices" | awk 'NR > 1 {print}'))

## Loop through resulting array and drop any checked items into final array
index=0
if [ "$buttonClicked" == "1" ]; then
	## Create a new array with only the selected items
	for item in ${boxesChecked[@]}; do
		if [ "$item" == "1" ]; then
			enabledOpts+=(${plugInIDs[$index]})
			enabledOptsTitles+=("	• ${plugInTitles[$index]}")
		fi
		((index++))
	done
else
	echo "User canceled. Exit"
	exit 0
fi

## If we got this far, the user has made some choices in the dialog.
## Check to see if the /Self Service/Plug-ins folder exists. If not, create it

if [ -d "$SSRootDir" ]; then
	if [ -d "$SSPluginsDir" ]; then
		echo "The Plug-ins folder exists. Moving on to copying plists into place..."
	else
		mkdir "$SSPluginsDir"
		chown root:admin "$SSPluginsDir"
		chmod 755 "$SSPluginsDir"
	fi
else
	echo "The Self Service and Plug-ins folders must be created..."
	mkdir -p "$SSPluginsDir"
	chown -R root:admin "$SSRootDir"
	chmod -R 755 "$SSRootDir"
fi

## Copy checked plist files into /Self Service/Plug-ins/
for item in "${enabledOpts[@]}"; do
	cp "${tmpPluginsDir}/$item" "$SSPluginsDir"
done

## Final dialog
text="The following Self Service URLs were installed:

$(printf '%s\n' "${enabledOptsTitles[@]}")

You can install additional ones by running this policy again."

"$cdPath" msgbox \
	--title "$msgTitle" \
	--text "Installation complete" \
	--informative-text "$text" \
	--icon-file "$SSIcon" \
	--button1 "   OK   " \
	--width 400 \
	--posY top \
	--quiet

## Clean up files in tmp
rm -Rfd "$tmpPluginsDir"
