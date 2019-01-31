# Get-HID
Identifies connected USB devices based on their VID/PID.

This tool was created in an attempt and identify RF keyboards and Mice. It will identify any HID device with an entry in:http://www.linux-usb.org/usb.ids. It has been broadened to identify any USB device in the database.

.Synopsis
   Identifies a devices vendor and product name based on its VID/PID. Helps ID devices when their manufacturer specific driver has not been installed. Command allows searching by keywords such as; transceiver,wireless, etc. Commandlet is useful finding devices that don't match you companies policy.
.DESCRIPTION
   This commandlet identifies enumerated devices containing a VID & PID. It is dependent upon the download of a USB device database from linux-usb.org/usb.ids.
    This DB is updated regularly. However, it is not a complete database for all known VID/PIDs. That database resides with USB.org but they want monies to access it.
    

.EXAMPLE

   Get-UsbID -DeviceID USB\VID_0DC3&PID_1004\6887070814 -MasterList Download
   
   Get-UsbID -DeviceID $entUsbIDList -MasterList Local -Keywords wireless,transceiver,radio
   
   Get-UsbID -DeviceID (gwmi win32_pnpentity|select deviceid) -MasterList Local
   
   Get-UsbID -DeviceID $entUsbIDList -MasterList Local -MasterFilePath C:\prevDB.dat
   
   
.INPUTS
   System.String
.OUTPUTS
   System.Collections.ArrayList
.NOTES
   When looking at devices connected to windows -Especially Human Interaction Devices (HIDS)- if the manufacturers driver is not installed many of the details a system admin
   might use to identify it are not installed. For example, when a wireless mouse/keyboard combo is connected to windows a generic HID driver is used for communication to the 3 devices.
   Each device, keyboard/mouse/RF transceiver each get the generic HID driver to communicate. I have found nothing that identifies them as wireless until the manufacturers driver
    is installed. 
    
   On most enterprise networks users are not allowed to install drivers, so you'll never see the word "wireless" associated with the device. This commandlet tries to fill
   this gap. When a company creates a USB device they are supposed to give it a VID\PID identifier and regiser it with USB.org. Wireless mice and keyboard RF receivers are 
   usually registered as a "Transceiver". Looking for these will find your wireless devices.

   Devices that come back as "Unknown" may help you find cheap and questionable devices such as bulk produced keyboards from china that have "Extra" features.

   All of this is subject to change following the internets judgment and wisdom. Please be nice, submit pull request to DarthCyber/Get-HID (soon to be Get-UsbId).
