
<# 
.SYNOPSIS
	Skript um ein CSV Datei mit Firewall Objekten für den Import in die Barracuda Firewall vorzubereiten.
.NOTES 
   DATE         : 2023-04-22
   AUTHOR       : Johannes Rehle
   DESCRIPTION  : Prompts to help the Enduser
   VERSION      : 0.4
#> 

Write-Host "Welcome to the Barracuda Object Importer"
Write-Host "----------------------------------------"
Write-Host "Please specify a csv or text file with the following content:"
Write-host '"Name,Ziel,Typ"'
Write-Host '"H_Test",1.2.3.4/32'
Write-Host '"name.dns.local","name.dns.local",FQDN'
Write-Host '"N_Test",192.168.0.0/24'
Write-Host '"N_Test1",192.168.0.0/255.255.255.0'
Write-Host
Write-Host "Select File"

Add-Type -AssemblyName System.Windows.Forms

Write-Verbose "Check for Tempfile"
$barracuda = "$env:TEMP\BarracudaTempOutput.txt"
if (Test-Path $barracuda)
{
	Remove-Item $barracuda
}

Write-Verbose "Get File with Barracuda Data"
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
    InitialDirectory = [Environment]::GetFolderPath('Desktop') 
    Filter = 'CSV (*.csv)|*.csv'
}
$null = $FileBrowser.ShowDialog()


Write-Verbose "Converting Data"
try {
	$objects = Import-CSV -Path $FileBrowser.FileName -Delimiter ';'
}
catch {
	"Datei konnte nicht eingelesen werden."| clip
	exit
}

Write-Verbose "Check for Validity"
if (!(Get-Member -InputObject $objects[0] -Membertype Properties -Name "Name"))
{
	Write-Verbose "Name Property not found. Aborting"
	"CSV enthält kein Name"| clip
	Write-Host "CSV enhält kein Name. Abbruch!"
	Read-Host
	exit
}

if (!(Get-Member -InputObject $objects[0] -Membertype Properties -Name "Ziel"))
{
	Write-Verbose "Ziel Property not found. Aborting"
	"CSV enthält kein Ziel"| clip
	Write-Host "CSV enthält kein Ziel. Abbruch!"
	Read-Host
	exit
}

Write-Verbose "Everything seems OK"

Write-Verbose "Generate Global Start Configuration"
'RuleSet{
	name={}
	readOnly={0}
	origin={}
	global={0}
	comment={}
	objrenamed={0}
	baseid={0}
	incid={1}
	featureLevel={20}
	useAppRules={0}
	id={}
	transobj={7.1.1.1}
	creator={}
	localCascade={0}
	allowRID={0}
	allowAppRules={0}
	prefixmatch={
	}
	rulesettype={}
	loadsets={}
	name={}
	readOnly={0}
	origin={}
	global={0}
	comment={
	}
	netprefixobj={
	}
	netprefixobj6={
	}
	netobj={' | Add-Content $barracuda


Write-Verbose "Generate Network Object Configuration"
foreach ($object in $objects)
{
	Write-Verbose "Proccessing $(($object.name))"

	switch($object.typ)
	{
		"fqdn"
		{
			Write-Verbose "Object Typ is FQDN"

"		NetSet{
			name={$($object.name)}
			readOnly={0}
			origin={}
			global={0}
			comment={}
			list={
			}
			neglist={
			}
			netType={5}
		}" | Add-Content $barracuda
		}

		default 
		{
			Write-Verbose "Object Typ is IP/Network"

			if ($object.ziel -match ' - ')
			{
				Write-Verbose "Found additional Spaces. Removing"
				$object.ziel = $object.ziel.replace(" - ","-")
			}


			Write-Verbose "Check for Host /255.255.255.255"
			if ($object.ziel -match "/255.255.255.255")
			{	
				Write-Verbose "Found"
				$object.ziel = $object.ziel.replace("/255.255.255.255","")
			}

			Write-Verbose "Check for Subnetmask"
			if ($object.ziel -match "/")
			{
				
				$subnetmask = $object.ziel.split("/")[1]
				if($subnetmask -match "(254|252|248|240|224|192|128).0.0.0$|255.(254|252|248|240|224|192|128|0).0.0$|255.255.(254|252|248|240|224|192|128|0).0$|255.255.255.(255|254|252|248|240|224|192|128|0)$")
				{
					Write-Verbose "Found! Convert to CIDR"
					$result = 0; 
					[IPAddress] $ip = $subnetmask;
					$octets = $ip.IPAddressToString.Split('.');
					foreach($octet in $octets)
					{
						while(0 -ne $octet) 
						{
							$octet = ($octet -shl 1) -band [byte]::MaxValue
							$result++; 
						}
					}
					$object.ziel = $object.ziel.Replace($subnetmask,$result)
				}
				
				Write-Verbose "Convert CIDR reverse"
				$subnetmask = $object.ziel.split("/")[1]
				$object.ziel = $object.ziel.Replace($subnetmask,32-$subnetmask)
			}
		
		"		NetSet{
					name={$($object.name)}
					readOnly={0}
					origin={}
					global={0}
					comment={}
					list={
						NetEntry{
							name={}
							readOnly={0}
							origin={}
							global={0}
							comment={}
							addr={$($object.ziel)}
						} 
					}
					neglist={
					}
				}" | Add-Content $barracuda
		}
	}
}



Write-Verbose "Generate Global End Configuration"
'	
	srvobj={
	}
	appobj={
	}
	contentobj={
	}
	connobj={
	}
	protoobj={
	}
	filterobj={
	}
	filtergroupobj={
	}
	parpobj={
	}
	devgroupobj={
	}
	icmpparamobj={
	}
	rules={
	}
	testobj={
	}
	subsets={
	}
	sublists={
	}
}
' | Add-Content $barracuda

Write-Verbose "Copy configuration to clipboard"
if (Test-Path -Path $barracuda)
{
	Get-Content $barracuda | clip
}

Write-Host "Convert done, please check for errors"
Read-Host
	