### WIRELESS keyboard/mice buster 1000 ###

##0x4461727468204379626572
##0x3434203631203732203734203638203230203433203739203632203635203732
<#CLSID for USB HUB / USB Controller {36FC9E60-C465-11CF-8056-444553540000}

Human Interface Devices (HID)
Class = HIDClass
ClassGuid = {745a17a0-74d3-11d0-b6fe-00a0c90f57da}

IrDA Devices
Class = Infrared
ClassGuid = {6bdd1fc5-810f-11d0-bec7-08002be2092f}
This class includes infrared devices. Drivers for this class include Serial-IR and Fast-IR NDIS miniports, but see also the Network Adapter class for other NDIS network adapter miniports.

Keyboard
Class = Keyboard
ClassGuid = {4d36e96b-e325-11ce-bfc1-08002be10318}
This class includes all keyboards. That is, it must also be specified in the (secondary) INF for an enumerated child HID keyboard device.

Class = Mouse
ClassGuid = {4d36e96f-e325-11ce-bfc1-08002be10318}
This class includes all mouse devices and other kinds of pointing devices, such as trackballs. That is, this class must also be specified in the (secondary) INF for an enumerated child HID mouse device.


#logitech relevant VID/PIDS
http://www.the-sz.com/products/usbid/index.php?v=0x046D
#>

#parsed structure of file

#VID
 #prop 1 = [hash] VID - NAME
 #prop 2 = [hash] PID - NAME



function Identify-USBDevice {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]$DeviceID,
        
        [Parameter(Mandatory=$true, Position=1, ValueFromPipeline=$false)]
        [ValidateSet("Local", "Download")]
        [string]$MasterList,

        [Parameter(Mandatory=$false)]
        [ValidateScript({Test-Path $_})]
        [string]$MasterFilePath
    )

#### Begin Begin ####
    begin {

            $pidcount = 0

        #new VID entry function
            function New-VID {
                param(
                $Number,
                $Name
                )

                #create custom object to be returned
                
                $pidsHashtable = New-Object -TypeName hashtable

                $newVID = New-Object -TypeName psobject
                Add-Member -InputObject $newVID -MemberType NoteProperty -Name vidNumber -Value $Number
                Add-Member -InputObject $newVID -MemberType NoteProperty -Name vidName -Value $Name
                Add-Member -InputObject $newVID -MemberType NoteProperty -Name pids -Value $pidsHashtable

                return $newVID
            }

            function New-Culprit {

                param(
                $cVID,
                $cPID,
                $cPIDName
                )

                $newCulprit = New-Object -TypeName psobject               
                Add-Member -InputObject $newCulprit -MemberType NoteProperty -Name vid -Value $cVID
                Add-Member -InputObject $newCulprit -MemberType NoteProperty -Name pid -Value $cPID
                Add-Member -InputObject $newCulprit -MemberType NoteProperty -Name PIDName -Value $cPIDName

                return $newCulprit

            }
        
            #check if ml has already been downloaded
            $mlTestPath = Test-Path ($home + '\downloads\usbIDs.db')

            #check for previous parsed list
            $mlParsed = Test-Path Variable:parsedDatabase

            #filepath of usbIDS.db
            $outputPath = $home + '\downloads\usbIDs.db'

            ### download db from linux-usb.org/usb.ids ###
            #download id repository if not local file

            $usbIdURL = 'http://www.linux-usb.org/usb.ids'
            $outputPath = $home + '\downloads\usbIDs.db'

                if($MasterList -eq "Download"){

                    if($mlTestPath -eq $true){$userInput = Read-Host -Prompt "File already download do you want to redownload? y/n"}
                    switch($userInput){
                        'y'{
                            #download db
                            (New-Object -TypeName System.Net.WebClient).DownloadFile($usbIdURL,$outputPath)
                        }
                        'n'{continue}
                    }

                }
            

        
        if($mlParsed -eq $false){

            ############# parse Database ##############
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
    
#### Begin Process ####
    process {
                
        $pc = 0
        foreach($device in $DeviceID){

            Write-Progress -Activity 'Analyzing devices' -Status "Looking up $pc" -PercentComplete ($pc/$DeviceID.Length*100)
            $pc += 1

            #extract and format vid/pid from deviceid
            $device -match "vid_...." | Out-Null
            $v = $Matches[0].TrimStart('VID_') 
            $v = $v.ToLower()

            $device -match "pid_...." | Out-Null
            $p = $Matches[0].TrimStart('PID_') 
            $p = $p.ToLower()
            
            $index = $stringsParsedDatabase.BinarySearch($v)

            if($index -lt 0){Write-Host "$v not found in database" ; continue}
            
            if($index -ge 0){$vInQ = $parsedDatabase[$index]
                $vInQ = $parsedDatabase[$index]

                switch($vInQ.pids.ContainsKey($p)){
                    $true{$identifiedDevices.Add($(New-Culprit -cVID $v -cPID $p -cPIDName $vInQ.pids.Item($p))) | Out-Null}
                    $false{Write-Host "$p is not in the database"}
                }
            }
        }
    }#EO process

#### Begin End ####    
    end {
        
        return $identifiedDevices
        
    }#EO end
    

#EO Function
}