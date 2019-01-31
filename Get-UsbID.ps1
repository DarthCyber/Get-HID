<#
.Synopsis
   Identifies a devices vendor and product name based on its VID/PID. Helps ID devices when their manufacturer specific driver has not been installed. Command allows searching by keywords such as; transceiver,wireless, etc. Commandlet is useful finding devices that don't match you companies policy.
.DESCRIPTION
   This commandlet identifies enumerated devices containing a VID & PID. It is dependent upon the download of a USB device database from linux-usb.org/usb.ids.
    This DB is updated regularly. However, it is not a complete database for all known VID/PIDs. That database resides with USB.org but they want monies to access it.
    
    While you can manually enter a device ID using VID_xxxxPID_xxxx syntax it is recommended to pipe the deviceid property or an object with the deviceid property
    directly to the commandlet. It is also recommended that once the database has been downloaded you change the option to local.

    See Notes for more info (add -full to get-help command)

.EXAMPLE
   Get-UsbID -DeviceID USB\VID_0DC3&PID_1004\6887070814 -MasterList Download
.EXAMPLE
   Get-UsbID -DeviceID $entUsbIDList -MasterList Local -Keywords wireless,transceiver,radio
.EXAMPLE
   Get-UsbID -DeviceID (gwmi win32_pnpentity|select deviceid) -MasterList Local
.EXAMPLE
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
#>

function Get-UsbID {
    [CmdletBinding()]
    param (
        
        #DeviceID paramater, must be present, can be piped from any class containing a deviceID property. Can be single or an array of ids.
        [Parameter(Mandatory=$true, 
                   Position=0, 
                   ValueFromPipeline=$true, 
                   ValueFromPipelineByPropertyName=$true)]
        [string[]]$DeviceID,
        
        #USBID database parameter, must be present. Local=local file somewhere, Download=go get from interwebs.
        [Parameter(Mandatory=$true, 
                   Position=1, 
                   ValueFromPipeline=$false)]
        [ValidateSet("Local", "Download")]
        [string]$MasterList,

        #Filepath to local usbid.db file, not mandatory. if -local is present but no -masterfilepath provided the commandlet will default
        #to the users downloads directory for a file named usbids.db path checked below to  allow for custom error message
        [Parameter(Mandatory=$false)]
        [string]$MasterFilePath,

        #keywords! can be single keyword or many comma seperated.
        [Parameter(Mandatory=$false)]
        [string[]]$keywords
    )
    
#####################
#### Begin Begin ####
#####################

    begin {
            


            #counter used for progress bar
            $pidcount = 0

            #New VID function, used to create custom objects when parsing the usbids.db file into an pslist
            function New-VID {
                param(
                $Number,
                $Name
                )

                #create hashtable to be used for pids of each VID object             
                $pidsHashtable = New-Object -TypeName hashtable

                $newVID = New-Object -TypeName psobject
                Add-Member -InputObject $newVID -MemberType NoteProperty -Name vidNumber -Value $Number
                Add-Member -InputObject $newVID -MemberType NoteProperty -Name vidName -Value $Name
                Add-Member -InputObject $newVID -MemberType NoteProperty -Name pids -Value $pidsHashtable

                return $newVID
            }

            #function to create new objects that are found in the database. These objects are added to the $identifedDevices array
            function New-Culprit {

                param(
                $cVID,
                $cVIDName,
                $cPID,
                $cPIDName
                )

                $newCulprit = New-Object -TypeName psobject               
                Add-Member -InputObject $newCulprit -MemberType NoteProperty -Name vid -Value $cVID
                Add-Member -InputObject $newCulprit -MemberType NoteProperty -Name vidName -Value $cVIDName
                Add-Member -InputObject $newCulprit -MemberType NoteProperty -Name pid -Value $cPID
                Add-Member -InputObject $newCulprit -MemberType NoteProperty -Name pidName -Value $cPIDName

                return $newCulprit

            }
        

            #filepath of usbIDS.db
            $outputPath = $home + '\downloads\usbIDs.db'

            ### download db from linux-usb.org/usb.ids ###
            #download id repository if not local file
            
                #parsed structure of file

                #VID
                 #prop 1 = [hash] VID - NAME
                 #prop 2 = [hash] PID - NAME


            $usbIdURL = 'http://www.linux-usb.org/usb.ids'
            $outputPath = $home + '\downloads\usbIDs.db'
            $mlparsed = $false

                if($MasterList -eq "Download"){
                    
                    #Checks if parsed version exist in memory
                    #Ask user if they really want to download and reparse. 
                    if((Test-Path Variable:parsedDatabase) -eq $true -or (Test-Path $outputPath) -eq $true){                                           
                        $userInput = Read-Host -Prompt "File already downloaded do you want to redownload? y/n"                                            
                        }                   

                    #do stuff based on the humans input
                    switch($userInput){
                        'y'{
                            #Create web client
                            $webC = New-Object -TypeName System.Net.WebClient

                            #Use default credentials for any web proxies
                            $webC.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

                            #download db
                            $webC.DownloadFile($usbIdURL,$outputPath)
                            $mlparsed = $false
                            }
                        'n'{
                            if(Test-Path Variable:parsedDatabase){
                                $mlParsed = $true
                                }
                            else{$mlParsed = $false}
                            }
                        }
                    }

                if($MasterList -eq "Local"){
                    
                    if($MasterFilePath -eq ""){
                        
                        $defaultCheck = Test-Path $outputPath
                        
                        if($defaultCheck -eq $true -and $(Test-Path Variable:parsedDatabase) -eq $true){$mlparsed = $true}
                        if($defaultCheck -eq $true -and $(Test-Path Variable:parsedDatabase) -eq $false){$mlparsed = $false}
                        if($defaultCheck -eq $false){Throw "Database file not present in default directory, download or add -masterfilepath to specify"}

                    }

                    if($MasterFilePath -ne ""){
                        if((Test-Path $MasterFilePath) -eq $true -and (Test-Path Variable:parsedDatabase) -eq $true ){$mlparsed -eq $true}
                        if((Test-Path $MasterFilePath) -eq $true -and (Test-Path Variable:parsedDatabase) -eq $false ){$mlparsed -eq $false}
                        if((Test-Path $MasterFilePath) -eq $false){throw "Filepath $MasterFilePath is invalid, try again human"}

                        ##### Check file format is correct
                        }
                    

                }


###########################################
############# parse Database ##############
###########################################   
     
        if($mlParsed -eq $false){

            [System.Collections.ArrayList]$global:parsedDatabase = @()

            $rawDatabase = Get-Content $outputPath
            
                $pc = 0
                foreach($line in $rawDatabase){
                    
                    Write-Progress -Activity 'Parsing USB Database' -Status "parsing line $pc" -PercentComplete ($pc/$rawDatabase.Length*100)
                    $pc += 1
                    #exit before irrelevant data
                    if($line -eq '# List of known device classes, subclasses and protocols'){break}
                    
                    #skip comment lines
                    if($line[0] -eq [char]35){continue}

                    #create new object based on first char of line being ascii decimal tab
                    if($line[0] -ne [char]9){
                        
                        #indexs 4-5 will be space characters everytime
                        $currentVID = -join $line[0..3]
                        $currentVIDName = -join $line[6..($line.length)]

                        $parsedDatabase.Add((New-VID -Number $currentVID -Name $currentVIDName)) | Out-Null
                        
                        #skip to next line
                        continue

                    }
                    
                    #properties of previous item
                    if($line[0] -eq [char]9){
                        
                        $currentPID = -join $line[1..4]
                        $currentPIDName = -join $line[7..($line.length)]
                        
                        $parsedDatabase[($parsedDatabase.Count - 1)].pids.Add($currentPID,$currentPIDName)
                        $pidcount += 1 

                    }#EO foreach line in database
            }#EO parsing foreach
            
            #output parsing results for the human
            write-host `n '  Parsed Database Complete'
            Write-Host '############################'
            write-host 'Raw file lines parsed:      ' $rawDatabase.Count
            write-host 'Number of VIDS in database: ' $parsedDatabase.Count
            write-host 'Number of PIDS in database: ' $pidcount
        
        #EO mlparsed if
        }

        #Sort database. This allows the use of binary search
        Sort-Object -InputObject $parsedDatabase -Property vidNumber | Out-Null
        
        #create strings array of parsed database. Couldn't do binary search by property of an object so this array was
        #created to allow searching by the vid property of each custom object.
        [System.Collections.ArrayList]$stringsParsedDatabase = $parsedDatabase.vidNumber
        [System.Collections.ArrayList]$global:identifiedDevices = @()
    #EO begin
    }

#######################
#### Begin Process ####
#######################

    process {
                
        $pc = 0
:device     foreach($device in $DeviceID){

            Write-Progress -Activity 'Analyzing devices' -Status "Looking up $pc" -PercentComplete ($pc/$DeviceID.Length*100)
            $pc += 1

            #extract and format vid/pid from deviceid
            #$device -match "vid_...." | Out-Null
            
            $m = $device -match "vid_...."
            if($m -eq $true){
                $v = $Matches[0].TrimStart('VID_') 
                $v = $v.ToLower()
            }

            $mm = $device -match "pid_...."
            if($m -eq $true){            
                $p = $Matches[0].TrimStart('PID_') 
                $p = $p.ToLower()
            }
            if($m -eq $false -and $mm -eq $false){continue}

            #skip duplicate vid&pid instances
            foreach($entry in $identifiedDevices){
                if($entry.vid -eq $v -and $entry.pid -eq $p){continue device; break}
                }


            $index = $stringsParsedDatabase.BinarySearch($v)

            if($index -lt 0){
                                $identifiedDevices.Add($(New-Culprit -cVID $v -cVIDName "Unknown" -cPID $p -cPIDName "unknown")) | Out-Null
                                continue
                            }
            
            if($index -ge 0){$vInQ = $parsedDatabase[$index]
                $vInq = $parsedDatabase[$index]

                switch($vInQ.pids.ContainsKey($p)){
                    $true{


                            $identifiedDevices.Add($(New-Culprit -cVID $v -cVIDName $vInq.vidName -cPID $p -cPIDName $vInQ.pids.Item($p))) | Out-Null
                          }

                    $false{
                            $identifiedDevices.Add($(New-Culprit -cVID $v -cVIDName $vInq.vidName -cPID $p -cPIDName "Unknown")) | Out-Null                          
                           }
                }
            }
        }
    }#EO process

###################
#### Begin End ####
###################
    
    end {
         #Add keyword regex here
            
            #No keywords
            if($keywords -eq $null){
                          
                return $identifiedDevices
                
            }


            #Keywords
            if($keywords -ne $null){
                [System.Collections.ArrayList]$keywordIdentifiedDevices = @()
                
                foreach($word in $keywords){
                    foreach($device in $identifiedDevices){
                       $mResult = $(-join $device.psobject.properties.value[1,3]) -match $word
                       if($mResult -eq $true){
                            $keywordIdentifiedDevices.Add($device) | Out-Null
                       }

                    }
                    

                }


                if($keywordIdentifiedDevices.Count -eq 0){Write-Host "`n###########`nNo keyword matches, here are results`n###########`n" ; return $identifiedDevices}

                if($keywordIdentifiedDevices.Count -ne 0){
                    Write-Host "Keyword Matches"
                    return $keywordIdentifiedDevices
                }


            }

    }#EO end
    

#EO Function
}
