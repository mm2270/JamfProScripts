JamfProScripts
==================

A collection of scripts I have worked on to be used with Jamf Pro (formerly 'Casper Suite'), and in some cases, which can be used with other Mac management tools.

### Current scripts
[create_ARD_computer_list.sh](#create_ard_computer_listsh)  
[reboot_scheduler.sh](#reboot_schedulersh)  
[create_SelfService_Plug-in.sh](#create_selfservice_plug-insh)  
[install_select_SS_plug-ins.sh](#install_select_ss_plug-inssh) *(Companion script for create_SelfService_Plug-in.sh)*  
[offer2AddIcon-v4.sh](#offer2addicon-v4sh)  
[post_restart_recon_control.sh](#post_restart_recon_controlsh)  
[selectable-SoftwareUpdate.sh](#selectable-softwareupdatesh)  
[download_jss_scripts.sh](#download_jss_scriptssh)

[Update_Core_Apps.sh] - deprecated  
[install_Latest_GoogleChrome-SelfService.sh] - deprecated  
[repair_permissions.sh] - deprecated  

#### **create_ARD_computer_list.sh**<br>
**create_ARD_computer_list.sh** was designed to assist with converting a Casper Suite Smart or Static Computer group into an Apple Remote Desktop computer list.  
The script will present an Applescript dialog with a listing of all computer groups from your JSS to select from. Your selection will be accessed using the JSS API, pulled down into an xml file, then converted into an ARD computer list plist file for import into Apple Remote Desktop.  
The API account used with this script must have the following read access at a minimum to function:  
- Computers  
- Smart Computer Groups  
- Static Computer Groups  

No "Create", "Update" or "Delete" access needs to be given to the API account to use this. It only reads these objects.

Special note: Because Smart and Static Computer groups don't contain the last reported IP address for computers in them, the script must loop over a list of all JSS computer IDs from the group chosen to get each Mac's IP address for the plist file. Because of this, the script can take several minutes to complete, even with modest sized computer groups. Its not recommended to use this on very large computer groups, such as one that has 1000 or more members in it.  

##### **Basic usage**
1. Edit the required items in the script for API Username, API Password and JSS URL.  
2. Save the script and ensure it is executable: `chmod +x /path/to/create_ARD_computer_list.sh`  
3. Run the script in Terminal or by other means and follow the instructions.  

Feel free to report any issues.  
<br>

#### **reboot_scheduler.sh**<br>
**reboot_scheduler.sh** was designed to be used in instances where system updates have been installed silently on a Mac that require a reboot of the Mac.  
Instead of simply rebooting the Mac immediately, or only allowing a single option for reboot (for ex. "Your Mac will reboot in 5 minutes") which could interrupt a user while they are in the middle of a presentation or some other important business, the script allows you to send up options for the user to schedule the reboot at a later time, or optionally reboot soon.  

##### Requirements:  
- The latest beta version of cocoaDialog (uses radio button and standard msgbox dialog styles)

##### Synopsis:  
The script works in two modes:  

1. If no value (integer) in minutes is passed to the script in Parameter 4 when its run, it will send up a dialog with cocoaDialog with pre-defined reboot options that the user can choose from. For example, you may give the user the option of rebooting "2 hours from now" "30 minutes from now" or "5 minutes from now"  
2. If a value (integer) in minutes is passed to the script in Parameter 4, it will instead auto schedule the reboot accordingly in the future exactly the number of minutes that was passed in the parameter.  
 * In either case, the schedule is created dynamically with a LaunchDaemon that uses the user selected value (when no pre-defined minutes value is passed), or with the pre-defined minutes value, and also creates a companion script, both of which are created at the time the script runs.  
 * The script is then called by the LaunchDaemon at the appointed time and presents a final 5 minute countdown when the Mac is going to reboot. This gives the user a final grace period to close out any open applications and save unsaved work before reboot time occurs.  
 * If the script is ever run in any way prior to the StartCalendarInterval schedule in the LaunchDaemon, it checks to see if the scheduled reboot time has arrived or has recently passed. If it has not, the script will log this in the companion rdlog.log file and exit silently. This prevents any unwanted premature reboots from occurring if the script gets run accidentally. If the scheduled reboot time has arrived it displays the final 5 minute countdown to the user.
 * If the Mac is rebooted manually prior to the scheduled reboot time, the LaunchDaemon and script are automatically cleaned up from the Mac, thus preventing another (unnecessary) reboot from occuring.  
 * If the dialog is quit by the user without selecting a value, the longest deferral option is automatically assigned and the LaunchDaemon / script are created and the user is notified of this.  
 * If no user is logged in at the time the script runs, it will start an immediate reboot of the Mac to satisfy the reboot requirement without needing to schedule it for a later time.  

##### Using the script:
Basic usage  
`sudo /path/to/reboot_scheduler.sh`  

When the script is added to a policy, you can optionally add a value in minutes to Paramater 4 ($4) to pass to it at run time.
You may also edit the values in the script for the reboot time options (currently on lines 75 thru 78)  

An example usage simulating a policy with a value passed to parameter 4 (using the jamf binary)  
`sudo jamf runScript -script reboot_scheduler.sh -path /path/to/script/ -p1 120`  

The above would auto schedule a reboot to occur 120 minutes from the runtime of the script, and display an alert showing the exact date and time the reboot has been scheduled to the current user.
As an example, if the script is run using a value of '120' passed to Parameter 4, and the current date and time is:  
`June 10, 2015 11:47 PM`  
the script will create a LaunchDaemon with a CalendarStartInterval setting of:  
`June 10, 2015 01:47 PM`  
and display this date and time in the dialog.

For more details on usage, please read through the script comments.  

##### What it creates:  
The LaunchDaemon is created in the path: `/Library/LaunchDaemons/com.org.rd.plist`  
The script is created in the path: `/private/var/rtimer.sh`  
A log file that captures information about the process is created and updated at `/private/var/log/rdlog.log`
<br>

#### **create_SelfService_Plug-in.sh**<br>
This script can be used to create Casper Suite Self Service Plug-ins on the fly, without needing to create them first within the JSS, then pulling them down with the management framework. Useful for quick testing when creating new Plug-ins, before actually setting them up within the JSS. Also useful for environments that wish to 'scope' URL Plug-ins and not auto deploy all new Plug-ins to all managed Macs.

Details on the script:  

1. The script must be run as root (sudo)
2. The script is interactive. It will 'guide' you on what you need to enter each step of the way.
3. The script clearly indicates what items are **Required** versus those that are **Optional**.
4. The script can accept images to use for the icon and convert them into the correct binary format
5. The script will create SS URL plug-ins with unique IDs that start in the 1000+ range. This is done so (hopefully) none of the ones you create with the script will conflict with any you created in your JSS.  
  *Note: the JSS will start with ID 1 and increment up, even if you delete any plug-ins later (IDs don't get reused).*
6. The script will create the necessary folder hierarchy on a Casper managed Mac, and save it to the appropriate location, making it immediately available in Self Service.app.
 * If used on a non managed Mac, it will save the resulting plug-in plist to your Desktop
7. The script notes the resulting Plug-in's ID (same as file name) and save path, so it should be easy to locate and wrap into a package later for deployment.  

##### Basic usage
`sudo /path/to/create_SelfService_Plug-in.sh`  
Enter your administrator password, and follow the on screen instructions
<br>
<br>

#### **install_select_SS_plug-ins.sh**<br>
This script is a companion script to [create_SelfService_Plug-in.sh](#create_selfservice_plug-insh), and is intended to be used from a Casper Suite Self Service policy to allow end users to select the URL plug-ins they wish to install.  

To effectively use this script, the following workflow is recommended:  

1. Create any Self Service URL Plug-ins you wish to offer for installation. You can use any method you want for this, but it is recommended to use the [create_SelfService_Plug-in.sh](#create_selfservice_plug-insh) script to make them.  
2. Create a new directory in `/private/tmp/` called **plug-ins_for_install**  
3. Copy the URL Plug-ins you created in Step 1 from `/Library/Application\ Support/JAMF/Self\ Service/Plug-ins/` to the folder you created in `/private/tmp/`   
4. Using Composer.app, or the packaging tool of your choice, create a deployable package (.pkg or .dmg) of the **plug-ins_for_install** directory and the plists inside it.  
5. Upload the package to your Casper repository as you would any new package.  
6. Create a new script in your Casper Suite JSS using the **install_select_SS_plug-ins.sh** as the code source.  
7. Create a Self Service policy with the package created in Step 4 and the script created in Step 6. Set the script to run as "After".  
<br>
When the policy is run, the package is downloaded and installed. The installation creates the directory with the URL Plug-ins in `/private/tmp/`  
The script runs next and reads the information from each plug-in plist and generates the appropriate dialog for the user running the policy.  
The choices made by the user are captured and only the selected URL plug-ins are copied to `/Library/Application\ Support/JAMF/Self\ Service/Plug-ins/`. They become available immediately in Self Service.  
<br>


#### **offer2AddIcon-v4.sh**<br>
This script was originally written in 2012 and subsequently updated in 2013, then again in 2014. Its being published here due to some interest in the script expressed by others who may be looking for a similar solution.  

The script is designed to be used in conjunction with Casper Suite Self Service policies that install an application which can be added to a user's Dock. The script should get run in an "After" state. Instead of using the built in Dock icon functionality in a policy, which forces the icon in the user's Dock, the script will utilize cocoaDialog or jamfHelper to prompt the client if they would like the icon for the just installed application in their Dock.  

**Requirements for the script:**  
- Parameter 4 (Application Name only)  
- Parameter 5 (Dock icon ID from the JSS - used as a backup if dockutil is not installed)  
- Parameter 6 (Full application path for the icon to be added)  

**Optional items:**  
- Parameter 7 (Add "after" icon - determines if the icon should try to be added after an existing icon in the Dock)  
- dockutil installed on the Mac - this provides the best experience, but its possible to use just the built in Casper Suite Dock icon ID and the jamf binary  

**How it works**  
The script does some basic checking before sending up a dialog.  
First, it checks to see if the target application (passed to the script in Parameter 6 ($6) is present, then checks to see if the icon already exists in the current user's Dock.plist. If its already present it will simply display a dialog that the installation (presumably an update to an existing installation) has completed.  
If the icon *isn't* present in their Dock, it will offer to add the icon for them. The user can click **Yes** or **No**. If they click "No", the script exits and leaves their Dock as is. If they click "Yes", it will attempt to add the icon for the application to their Dock. If dockutil is installed and the path to the binary has been set up within the script, it will use that binary to add the Dock icon. If dockutil isn't installed or the script cannot find it, it falls back to using the jamf binary's update Dock functionality. This is where Parameter 6 comes in, since it will use the Dock icon ID from the JSS for this.  
Paramater 7 is an optional item that can be passed to the script which will use dockutil's ability to add an icon after an existing one in the Dock. For example, if using the script with a Firefox or Chrome installation policy, you may want to pass "Safari" to Parameter 7, which will tell dockutil to try to add the icon after Safari if its present in the Dock. In cases where the icon passed to Parameter 7 isn't in the Dock, it defaults to adding the icon at the end of the Dock.  

I developed this script because I felt that a user's Dock is a personal item. Everyone manages their Dock differently. I didn't feel comfortable with forcing an icon to a user's Dock without giving them to the option to bypass it. However, we did want to give clients the ability to automatically add the newly installed application to their Dock if they wanted it. The Casper Suite doesn't have built in functionality to prompt the user for a choice for Dock icons unless its run as a separate policy along with User Interaction options set up.

<br>  

#### **post_restart_recon_control.sh**<br>

Purpose: to deploy (create) a LaunchDaemon and companion local script to a Mac that can be called into action later thru the use of a control plist file

#### How it works:  
- A local script and LaunchDaemon are both created using the included information in this script.  
- The scripts name is set to "postrestart.recon.sh" and is created in /private/var/  
- It is partially customized at the time of creation by using the 2 variables in the script, 'yourOrg' and 'maxAttempts'  
- The LaunchDaemon's identifier is partially customized on creation using the 'yourOrg' variable within the script  
- The LaunchDaemon is not loaded after creation (it will load automatically on the next reboot)  


#### How the post reboot recon process works once in place:
- The LaunchDaemon calls the script on initial run (only runs once), which typically means after a restart.  
- The script looks for a local plist file (/Library/Preferences/com.$yourOrg.postrestart.reconcontrol.plist) The plist has a simple boolean value for a post reboot recon.  
- If the value is set to TRUE or 1, the script will attempt to connect to the machine's Jamf Pro server and perform a recon. (See point 4 for alternate response)  
- It will loop up to the max times specified by the `maxAttempts` variable in the initial creation script (default is 30), pausing 1 second between each attempt while trying to connect to the Jamf Pro server. If it cannot connect in the maximum number of attempts, it exits.  
- If connection is successful, the recon is performed and the plist value is changed to FALSE or 0.  
- If the plist does not exist, the script performs the same steps as above, a recon is performed and then creating a new plist and setting the value to FALSE or 0.  

After initial deployment, and first use, the LaunchDaemon remains active, and the LaunchDaemon and script remain on the computer. They only spring into action if the control plist is modified through some other means, such as a command run at the completion of a Jamf Pro policy.  

#### Usage:
The plist value can be changed with a simple shell command added to a policy to set the plist value to TRUE, which means a recon will be attempted after the next restart.  

Example of shell command to enable a post reboot recon (entered into the EXECUTE COMMAND field in a Jamf Pro policy):  
   `/usr/bin/defaults write /Library/Preferences/com.acme.postrestart.reconcontrol.plist PerformRecon -bool TRUE`

Note: the 'acme' portion of the plist name must be changed to the shortname of your organization entered in the 'yourOrg' value in the script
<br>
<br>


#### **selectable-SoftwareUpdate.sh**<br>

- Requires the current beta release of cocoaDialog to be installed on the target Mac.  
- Displays a checkbox dialog with available Software Updates to be installed.  
- Provides feedback on installations as they run with a moving progress bar.  


<br>


#### **download_jss_scripts.sh**<br>
This script, which is designed to be used with a Casper Suite JSS version 9.x, can be used to download all scripts located on the JSS into a directory. Each script is downloaded with the display name as shown for it in the JSS. The script contents are cleaned after saving, to remove any web formatted characters which would prevent the script from being usable.

##### Basic usage:  
The script can be run directly in Terminal, or via the jamf binary. To use it you must pass an API read username and password to it to use for API commands. A third parameter that can be passed is the JSS URL. This is optional if running the script from a Mac that is currently enrolled in the target JSS.  

##### Examples:  
`sudo jamf runScript -script download_jss_scripts.sh -path /Users/me/Desktop/ -p1 apiuser -p2 apipassword [optional] -p3 https://my.jss.org:8443`  

Or  

`sudo /Users/me/Desktop/download_jss_scripts.sh -a apiuser -p apipassword -s https://my.jss.org:8443`  

##### To show a help page for the script, in Terminal:  
`/path/to/script/download_jss_scripts.sh -h`  
<br>
<br>

#### **installLatestFlashPlayer-v1.sh**<br>
(This script has been replaced by Update_Core_Apps.sh)

#### **install_Latest_AdobeReader.sh**   (_New_)<br>
(This script has been replaced by Update_Core_Apps.sh)


#### **Update_Core_Apps.sh**<br>
**IMPORTANT: This script has been depreciated and is no longer being maintained. Most of it will not work on current versions of macOS or is no longer relevant. Use at your own risk!**<br>
The Update_Core_Apps script can be used to update many common free applications and Plug-ins. Despite the word "Update" in its name, it can also be used to install most of these applications and Plug-ins new on a target Mac.

Details on the script are as follows:
- Requires the current beta release of cocoaDialog to be installed on the target Mac if using Self Service mode (see below)
- Can update any of the following applications and plug-ins:
  * **Adobe Reader**
  * **Adobe Flash Player**
  * **Cyberduck**
  * **Dropbox**
  * **Firefox**
  * **Firefox ESR**
  * **Flip Player** (free version)
  * **Microsoft Lync** (updates only)
  * **Microsoft Office 2011** (updates only)
  * **Oracle Java**
  * **Silverlight**
  * **VLC**  
  
- Can be used in a "silent" mode to update apps/Plug-ins silently on a target Mac, or "Self Service" mode to prompt an end user to install an update and show them both download and install progress, new version information, and success or failure notifications.
- Has built in version checking against installed applications (if its installed), by comparing it to the latest release from the vendor. The version checking can handle odd version naming conventions, so that it ensures it is only "upgrading" a client, not downgrading it.
- Office 2011 updates utilize a noquit.xml file to suppress the built in quit apps function of these updates. This allows these updates to install either silently, or via Self Service, without forcing the client to shut down the open applications. In both silent and Self Service modes, a dialog will alert the client of any applications that were open that should be quit and relaunched after installation.
- The script accepts two Parameters passed to it from a Casper Suite policy:
  * Parameter 4 ($4) is mandatory, and accepts a number of different strings for the app or Plug-in to check for updates. (For a full listing of acceptable strings, see how to display the help page for the script below).
  * Parameter 5 ($5) is optional, and can accept any string to enable Self Service mode.
  * Strings are case insensitive.
- The script replaces both the **installLatestFlashPlayer-v1.sh** and **install_Latest_AdobeReader.sh** scripts.

##### Basic usage  
1. To test the script from Terminal on a Casper Suite managed Mac:  
`sudo jamf runScript -script Update_Core_Apps.sh -path /path/to/script/ -p1 "app or plugin name"` _(mandatory)_ `-p2 "any string to enable Self Service"` _(optional)_  

2. When adding the script to a Casper Suite policy, add a string to Parameter 4 and optionally Paramater 5.

##### To show a help page for the script, in Terminal:  
`/path/to/script/Update_Core_Apps.sh`  
<br>


#### **install_Latest_GoogleChrome-SelfService.sh**<br>
**IMPORTANT: This script has been depreciated and is no longer being maintained. Most of it will not work on current versions of macOS or is no longer relevant. Use at your own risk!**<br>
This script is intended to be used within Self Service. The script will operate in one of three ways, dynamically determined based on conditions.  
- If the Google Chrome browser is already installed on the Mac in the standard `/Applications/` path, it will attempt to locate the Google Software Update mechanism and run it as the user to check for, and install, any updates to Chrome. A final dialog will display if the browser was updated, or if it was already up to date.  
- If it cannot locate the Google Software Update tools on the Mac, it will offer to download the latest release and install it.  
- If Google Chrome is not installed or not located in `/Applications/`, it will offer to download the latest release and install it.  

Progress is shown when appropriate. In all cases, the final success dialogs will display the installed or updated version of Google Chrome to the user running the policy.  

Requirements:
- Current beta release of cocoaDialog to be installed on the target Mac  
<br>


<br>
#### **repair_permissions.sh**<br>
**IMPORTANT: This script has been depreciated and is no longer being maintained. Most of it will not work on current versions of macOS or is no longer relevant. Use at your own risk!**<br>
- Requires the current beta release of cocoaDialog to be installed on the target Mac.
- Optionally displays a 'preamble' message to the user before running the disk permissions repair.
- Optionally allows the user to 'opt out' of future preamble messages with a checkbox.
- When disk permissions repair is run, accurate progress is displayed with a cocoaDialog progress bar.
- At the completion of the disk permissions repair, a final textbox style dialog appears with the repair results.
- If any repair problems are detected, it brings this to the attention of the user in the textbox dialog heading.
- If the option is enabled within the script with a variable, and problems are detected, an email can be sent to an admin or group email address with details on the Mac that ran the policy, plus the results of the repair. Note that this function uses the standard Unix mail function. This may not always work in all environments depending on firewall restrictions.

Please read the notes contained within the script for instructions on how to use the various options, and be sure to add a valid email address to it before deploying.  
Currently this script does not use Casper Suite script parameters. If I receive enough feedback on wanting this functionality, I will add it in. In the interim, feel free to modify the script to use passed parameters for some of the options.  
