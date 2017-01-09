<#
.Synopsis
   Convert a database query result set to t-sql select script
.DESCRIPTION
   Convert a database query (or stored procedure) result, which may contain multiple data sets, into a sql select script.
.EXAMPLE
   
   Convert-QueryDatatToSQL -ServerInstance MyServer -Database MyDB -Query "select column_1, column_2 from dbo.MyTable where Column_3 > 10"

.EXAMPLE
   Convert-QueryDatatToSQL -ServerInstance MyServer -Database MyDB -Query "exec sp_who2 active"; 
.INPUTS
   -ServerInstance <string>
    The SQL Server instance name, which the query will connect to

   -Database [<string>]
    The target SQL Server database, against which the query will run
   
   -Query 
    simple select statements, or stored procedures that will return table-like result set
.OUTPUTS
   a string which is a select statement with union all to other select statements
.NOTES
   Author: Jeffrey Yao, 2016/04/20   
#>


#requires -version 4.0

# assume you have installed SQL Server 2012 (or above) Feature Pack, mainly the Shared Management Object file
#for sql 2012 version=11.0.0.0, for sql2014, version=12.0.0.0

add-type -AssemblyName "microsoft.sqlserver.smo, version=12.0.0.0, culture=neutral, PublicKeyToken=89845dcd8080cc91" -ea stop

Function Convert-QueryDataToSQL
{
    [CmdletBinding()]
    
    [OutputType([String])]
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

        # Query
        [Parameter(Mandatory=$true,
                   Position=2)]
        [String] $Query
    )
    
    [string[]]$columns='';
    [string] $insert_columns = '';
	[string] $insert_values = '';
	[string] $sqlcmd = '';
    [string] $ret_value= '';

    try {
            $svr = new-object microsoft.sqlserver.management.smo.Server $ServerInstance;
            if ($svr -eq $null)
            {
                Write-Error "Server [$ServerInstance] cannot be accessed, please check";
                return -1;
            }
            $db = $svr.Databases.item($Database);
            if ($db -eq $null)
            {
                Write-Error "Database [$Database] cannot be accessed or does not exist, please check";
                return -1;
            }
    
            $result = $db.ExecuteWithResults($Query);
            if ($result.Tables.count -gt 0) # we now start to generate the strings
            {
                foreach ($t in $result.tables) #loop through each DataTable
                {
                      Foreach ($r in $t.Rows) #loop through each DataRow
                      {
                          $insert_columns = "INSERT INTO dbo.hl7_field_mappings ("
						  $insert_values = " VALUES ("
                          Foreach ($c in $t.Columns) #loop through each DataColumn
                          {
                            if ($r.item($c) -is 'DBNULL')
                            { $itm = 'NULL';}
                            else
                            { 
                                if ($c.datatype.name -eq 'DateTime')
                                { $itm =$r.item($c).tostring("yyyy-MM-dd hh:mm:ss.fff");}
                                else
                                {$itm = $r.item($c).tostring().trim();}
                            
                            }


                            $itm=$itm.replace("'", "''");
                         
                            if ($itm -eq 'Null') {
								$insert_columns += "$c,";
								$insert_values += "NULL,"
							} else {

                                switch ($c.DataType.name) 
                                {
                                    {$_ -in ('Guid', 'String', 'DateTime')} {
										$insert_columns += "$c,"
										$insert_values += "'" + $itm + "',"; 
										break;
									} 
                                    {$_ -in ('int32', 'int64', 'Decimal', 'double')} {
										$insert_columns += "$c,"
										$insert_values += $itm + ","; 
										break;
									} 
                                    {$_ -in ('boolean')} {
										if ($r.item($c)) {
											$insert_columns += "$c,"
											$insert_values += '1,'
										} else {
											$insert_columns += "$c,"
											$insert_values += '0,';
										}; 
										break;
									} 
                                    {$_ -in ('byte[]')} { 
										$insert_columns += "$c,"
										$insert_values += '0x'+[System.BitConverter]::ToString($r.item($c)).replace('-', '')+",";
										break; 
									}
                                   # {$_ -in ('DateTime')} {$insert_columns +="$c="+"'" + $itm + "',"; break;} 
                                    

                                    default {
										$insert_columns += "$c,"# ="+"'" + $r.item($c) + "',"; 
										$insert_values += "'" + $r.item($c) + "',";
										break;
										} 

                                }#switch
                            }#else, i.e. $itm ne  'Null'

                          }#column loop
						#remove trailing comma and replace with close bracket with line breaks
						$insert_columns = $insert_columns.substring(0,$insert_columns.length - 1) + ")"
						$insert_values = $insert_values.substring(0,$insert_values.length - 1) + ")`r`n"
						$sqlcmd = $insert_columns + $insert_values;
                        #$sqlcmd += "`r`n" ; # add line breaks
						
                        $ret_value += $sqlcmd;

                      } #row loop
                    
                    # remove the final line of " union all"
                    #if ($ret_value.Length -gt 13) 
                    #{ $ret_value = $ret_value.Substring(0, $ret_value.Length-13); };
                }#table loop

            }# $result.Tables.count -gt 0
            else
            {
                Write-Output "No data returned";
                return;
            }

            Write-Output $ret_value;
            return;
    }
    catch
    {
        $ex = $_.Exception
        Write-Error "$ex.Message"
    }
}#Convert-QueryDataToSQL

Convert-QueryDataToSQL -ServerInstance benvm -Database NSW_LHD_BASEDB_V1 -Query "select * from dbo.hl7_field_mappings" | out-file -FilePath a.sql -force
