Function Percentcal {
    param(
    [parameter(Mandatory = $true)]
    [int]$InputNum1,
    [parameter(Mandatory = $true)]
    [int]$InputNum2)
    $InputNum1 / $InputNum2*100
}

#email account setting
$mailUsername = "yourname@gmail.com";
$mailPassword = "password_of_gmail.com";

function Send-ToEmail([string]$email, [string]$mailContent,[string]$mailMessageheader){
    $message = new-object Net.Mail.MailMessage;
    $message.From = "tonyxiaojinwu@gmail.com";
    $message.To.Add($email);
    #$message.CC.Add("tonyxiaojinwu@gmail.com");
    $message.Subject = $mailMessageheader;
    $message.Body = $mailContent;

    $smtp = new-object Net.Mail.SmtpClient("smtp.gmail.com", "587");
    $smtp.EnableSSL = $true;
    
    $smtp.Credentials = New-Object System.Net.NetworkCredential($mailUsername, $mailPassword);
    $smtp.send($message);
    write-host "Mail Sent"; 
 }
#set the Read-Only attribute of the shared folder
function SetRO-ShareFolderACL([string] $filesharename, [string] $scopename,[string] $accountname)
{
Grant-SmbShareAccess -Name $filesharename -ScopeName $scopename  -AccountName $accountname -AccessRight Read -Force
}

function AllowFull-ShareFolderACL([string] $filesharename,[string] $scopename, [string] $accountname)
{
Grant-SmbShareAccess -Name $filesharename -ScopeName $scopename -AccountName $accountname -AccessRight Full -Force
} 

#connect to vCenter
Set-PowerCLIConfiguration -DefaultVIServerMode Multiple -Scope AllUsers -InvalidCertificateAction Ignore -ProxyPolicy NoProxy -Confirm:$false -ParticipateInCEIP $true
$user="vc_username"
$password="vc_password"
$host1="vc_ip_address"
Connect-VIServer  -Server $host1 -User $user -Password $password
#report space of vSANdatastore
$vSANdatastore = Get-Datastore | where Name -Like 'vsanDatastore'
$PercentFree = Percentcal $vSANdatastore.FreeSpaceMB $vSANdatastore.CapacityMB
$PercentFree = “{0:N2}” -f $PercentFree
$vSANdatastore | Add-Member -type NoteProperty -name PercentFree -value $PercentFre
$UsedSpaceGB = $datastores | Select @{N=”UsedSpaceGB”;E={[Math]::Round(($_.ExtensionData.Summary.Capacity – $_.ExtensionData.Summary.FreeSpace)/1GB,0)}}
$TotalSpaceGB = $datastores |Select @{N=”TotalSpaceGB”;E={[Math]::Round(($_.ExtensionData.Summary.Capacity)/1GB,0)}} 

#set share folder 
$myscopename_on_FS="Scope_name_of_shared_folder"
$mysharedfoldername_on_FS="shared_folder_name"
$myshareusername_on_FS="domain_user_name"

if ($PercentFree -lt 80) {
    write-host "vSAN datastore usage is less 80 percent, grant full control of the large shared folder.";
    AllowFull-ShareFolderACL -filesharename $mysharedfoldername_on_FS -scopename $myscopename_on_FS -accountname $myshareusername_on_FS
}
elseif ($PercentFree -gt 80 -and $PercentFree -lt 90){
    $warningMailMessage= "vSAN datastore usage is $Current_vSAN_Usage_inGB (GB) and the usage is over 80 percent but less than 90 percent, send email to administrator";
    Send-ToEmail  -email "admin@vmware.com" -mailContent $warningMailMessage -mailMessageheader "Warning message from vSAN datastore usage by Admin";
    AllowFull-ShareFolderACL -filesharename $mysharedfoldername_on_FS -scopename $myscopename_on_FS -accountname $myshareusername_on_FS
    }
    else {
    $errorMailMessage= "vSAN datastore usage is $Current_vSAN_Usage_inGB (GB) and the usage is over 90 percent, set the shared folder to read-only";
    Send-ToEmail  -email "admin@vmware.com" -mailContent $errorMailMessage -mailMessageheader "Critical message from vSAN datastore usage by Admin";
    SetRO-ShareFolderACL -filesharename $mysharedfoldername_on_FS -scopename $myscopename_on_FS -accountname $myshareusername_on_FS
    }

