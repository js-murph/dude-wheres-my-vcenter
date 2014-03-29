Description:
Locate which ESX server your vCenter server is currently on and send that information to Nagios so that in the event that the server goes down or the vCenter application stops working you are able to find it.

Download:
http://roshamboot.org/main/wp-content/uploads/2014/03/DWMVC.zip

Known Issues:
- Large numbers of ESX servers will probably cause bad things to happen as it currently attempts to connect to all found ESX servers simultaneously… which is ok if you have less than 30.

Project Status:
Unfinished

Patch Notes:
v0.1:
- First release

Usage:
1. Extract the zip file to a location on your vCenter server(s).
2. Fill in the fields in the INI file.
3. Configure a scheduled task on each server to run the script no more than every 30 minutes (I recommend once an hour).
-help
Display this help text and version number.
