<#
.Synopsis
   Extract HL7 configuration from Titanium database and generate SQL so it can be inserted somewhere else.
.DESCRIPTION
   Convert existing HL7 configuration into a sql insert script (as with SSMS 'Generate scripts' functionality).
.EXAMPLE
   
   GetHL7Mappings -ServerInstance MyServer -Database MyDB -OutputFile MyMappings.sql
   
.INPUTS
   -ServerInstance <string>
    The SQL Server instance name, which the query will connect to

   -Database <string>
    The target SQL Server database, against which the query will run
   
   -OutputFile <string>
    File name to save the SQL script into (will clobber existing files) - defaults to "HL7Mappings.sql".
.OUTPUTS
   a .sql file containing insert statements for the specified HL7 configuration (will clobber existing files)
.NOTES
   Author: Ben Roper, 2017/01/09   
   
#>
[CmdletBinding()]
Param
(
	# SQL Server instance name, default to local server
	[Parameter(Mandatory=$true, 
	           Position=0)]
	[Alias("S")] 
	[string]$ServerInstance=$env:ComputerName,

	# Database Name
	[Parameter(Mandatory=$false,
	           ValueFromPipeline=$true,
	           Position=1)]

	[AllowEmptyCollection()]
	[string] $Database='master',
	
	# Output file name
	[Parameter(Mandatory=$false,
				ValueFromPipeline=$true,
				Position=2)]
	[string] $OutputFile="HL7Mappings.hl7"
)
. (Join-Path $PSScriptRoot ExtractHL7script.ps1)

# begin by removing existing data
$deletetables = "-- Delete existing HL7 mappings
DELETE HL7_FIELD_MAPPINGS
DELETE HL7_GROUP
DELETE HL7_LINKEDTABLES
DELETE HL7_MAPS
DELETE HL7_MAPTABLE
DELETE HL7_MESSAGES
DELETE HL7_MESSAGE_EVENTS
DELETE HL7_SEGMENT
DELETE HL7_SEGMENTTABLES
"

$deletetables | Out-File -FilePath $OutputFile -Force

Convert-QueryDataToSQL -ServerInstance $ServerInstance -Database $Database -Query "select * from dbo.HL7_FIELD_MAPPINGS" | out-file -Append -FilePath $OutputFile 
Convert-QueryDataToSQL -ServerInstance $ServerInstance -Database $Database -Query "select * from dbo.HL7_GROUP" | out-file -Append -FilePath $OutputFile 
Convert-QueryDataToSQL -ServerInstance $ServerInstance -Database $Database -Query "select * from dbo.HL7_LINKEDTABLES" | out-file -Append -FilePath $OutputFile 
Convert-QueryDataToSQL -ServerInstance $ServerInstance -Database $Database -Query "select * from dbo.HL7_MAPS" | out-file -Append -FilePath $OutputFile 
Convert-QueryDataToSQL -ServerInstance $ServerInstance -Database $Database -Query "select * from dbo.HL7_MAPTABLE" | out-file -Append -FilePath $OutputFile 
Convert-QueryDataToSQL -ServerInstance $ServerInstance -Database $Database -Query "select * from dbo.HL7_MESSAGES" | out-file -Append -FilePath $OutputFile 
Convert-QueryDataToSQL -ServerInstance $ServerInstance -Database $Database -Query "select * from dbo.HL7_MESSAGE_EVENTS" | out-file -Append -FilePath $OutputFile 
Convert-QueryDataToSQL -ServerInstance $ServerInstance -Database $Database -Query "select * from dbo.HL7_SEGMENT" | out-file -Append -FilePath $OutputFile 
Convert-QueryDataToSQL -ServerInstance $ServerInstance -Database $Database -Query "select * from dbo.HL7_SEGMENTTABLES" | out-file -Append -FilePath $OutputFile 
echo "Done!"
