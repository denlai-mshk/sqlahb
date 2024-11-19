# Steps to check Azure Hybrid Benefit for all SQL servers in your subscription
This Powershell scripts are designed for changing the license type from Azure Hybrid Benefit to Pay as You Go.


##  Step 1: Install the Azure PowerShell Module
    If you haven't already installed the Azure PowerShell module, you can do so using the following command:
```
    Install-Module -Name Az.Accounts -AllowClobber -Force
    Install-Module -Name Az.Sql -AllowClobber -Force
```

##  Step 3: Verify the Installation
You can verify that the module is installed and the cmdlets are available by listing the commands:
```
Get-Module -ListAvailable -Name Az.Sql
Get-Module -ListAvailable -Name Az.Accounts
```   

##  Step 3: Verify the Installation
Sign on with your browser, you need to have Azure Subscription Owner role

```
Connect-AzAccount -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx"
``` 

##  Step 4: Modify the sublist.txt
You can change all SQL servers deployed in multiple subscriptions with one go. Edit the **sublist.txt** and place your subscription name and id under the 1st header row "SubscriptionName", "SubscriptionId"
```
"SubscriptionName", "SubscriptionId"
your-sub-name, xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx
```  

##  Step 5: Execute the checksqlahb.ps1 for checking
Open powershell, locate to the script folder, execute  [checksqlahb](checksqlahb.ps1)
``` 
.\checksqlahb.ps1
``` 

Set license change may takes 1-2 minutues for each SQL Server approximately. Please be patient if your subscriptions have a lot of SQL Server.

After you see "Discovery and disablement completed", you can check the **findallsqlsvr.txt** for all SQL Servers discovery. You also can check the findahbonly.txt which only list out the SQL Server with Azure Hybrid Benefit enabled.    

##  Step 6: Execute the confirmsqlahb.ps1 for change all Azure Hybrid Benegfit to PayGO
If you confirm to change all the SQL Servers listed in the **findallsqlsvr.txt** from Azure Hybrid Benefit to Pay as you go, then execute  [confirmsqlahb](confirmsqlahb.ps1)

``` 
.\confirmsqlahb.ps1
``` 

After you see "Discovery and disablement completed", you can check the **resultpaygo.txt** for the result