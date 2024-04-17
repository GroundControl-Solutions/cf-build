#Requires -Version 3

param(
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string[]]$CoreFoundationDlls=@("CoreFoundation.dll", "BlocksRuntime.dll", "icudt72.dll", "icuin72.dll", "icuuc72.dll"),

    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$ManifestPath="GroundControl.CoreFoundation.manifest",

    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$OutputPath="cf.wxs"
)

function script:add-component {
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [System.Xml.XmlWriter]$xml,
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string]$FileName
    )

    $xml.WriteStartElement("Component")
     $xml.WriteAttributeString("Directory", "CoreFoundation")
     $xml.WriteAttributeString("Win64", "no")
     $xml.WriteStartElement("File")
      $xml.WriteAttributeString("Source", "!(bindpath.cf)\$FileName")
      $xml.WriteAttributeString("KeyPath", "yes")
     $xml.WriteEndElement()
    $xml.WriteEndElement()
}

function script:add-manifestfile {
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [System.Xml.XmlWriter]$xml,
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string]$FileName
    )

    $xml.WriteStartElement("file")
     $xml.WriteAttributeString("name", "$FileName")
    $xml.WriteEndElement()
}

$ErrorActionPreference = "Stop"

$full_manifest_path = [IO.Path]::Combine((Get-Location), $ManifestPath)
$full_output_path = [IO.Path]::Combine((Get-Location), $OutputPath)
$xml_settings = New-Object -TypeName System.Xml.XmlWriterSettings
$xml_settings.Indent = $true
$xml_settings.IndentChars = "`t"
$xml_settings.CloseOutput = $true

$manifest_writer = New-Object -TypeName System.IO.StreamWriter -ArgumentList @($full_manifest_path, $false, [System.Text.Encoding]::UTF8)
[System.Xml.XmlWriter]$xml = [System.Xml.XmlWriter]::Create($manifest_writer, $xml_settings)
$xml.WriteStartElement("assembly", "urn:schemas-microsoft-com:asm.v1")
 $xml.WriteAttributeString("manifestVersion", "1.0")
 $xml.WriteStartElement("assemblyIdentity")
  $xml.WriteAttributeString("type", "win32")
  $xml.WriteAttributeString("name", "GroundControl.CoreFoundation")
  $xml.WriteAttributeString("version", "1.0.0.0")
 $xml.WriteEndElement()
 $CoreFoundationDlls | ForEach-Object -Process { add-manifestfile -xml $xml -FileName $_ }
$xml.WriteEndElement()
$xml.Close()

$text_writer = New-Object -TypeName System.IO.StreamWriter -ArgumentList @($full_output_path, $false, [System.Text.Encoding]::UTF8)
[System.Xml.XmlWriter]$xml = [System.Xml.XmlWriter]::Create($text_writer, $xml_settings)
$xml.WriteStartElement("Wix", "http://schemas.microsoft.com/wix/2006/wi")
 $xml.WriteStartElement("Fragment")
  $xml.WriteAttributeString("Id", "CoreFoundationFragment")
  $xml.WriteStartElement("DirectoryRef")
   $xml.WriteAttributeString("Id", "INSTALLDIR")
   $xml.WriteStartElement("Directory")
    $xml.WriteAttributeString("Id", "CoreFoundation")
    $xml.WriteAttributeString("Name", "GroundControl.CoreFoundation")
   $xml.WriteEndElement()
  $xml.WriteEndElement()

  # Insert newline to visually separate element types
  $xml.Flush()
  $text_writer.WriteLine()

  $xml.WriteStartElement("ComponentGroup")
   $xml.WriteAttributeString("Id", "CoreFoundationFiles")
   $CoreFoundationDlls | ForEach-Object -Process { add-component -xml $xml -FileName $_ }

   # Insert newline to visually separate element types
   $xml.Flush()
   $text_writer.WriteLine()

   # For compatability with the 32-bit installer, add 2 mutually-exclusive components that install the same file to the same location
   $xml.WriteStartElement("Component")
    $xml.WriteAttributeString("Directory", "CoreFoundation")
    $xml.WriteAttributeString("Guid", "95e0440d-0f08-4223-8389-e498cbb9ccfc")
    $xml.WriteAttributeString("Win64", "no")
    $xml.WriteStartElement("File")
     $xml.WriteAttributeString("Source", "!(bindpath.cf)\$ManifestPath")
     $xml.WriteAttributeString("Id", "_95e0440d_0f08_4223_8389_e498cbb9ccfc")
     $xml.WriteAttributeString("KeyPath", "yes")
    $xml.WriteEndElement()
    $xml.WriteElementString("Condition","NOT Privileged")
   $xml.WriteEndElement()
   $xml.WriteStartElement("Component")
    $xml.WriteAttributeString("Directory", "CoreFoundation")
    $xml.WriteAttributeString("Guid", "5ee276e0-1933-47ef-9696-d529b5b0b337")
    $xml.WriteAttributeString("Win64", "no")
    $xml.WriteStartElement("File")
     $xml.WriteAttributeString("Source", "!(bindpath.cf)\$ManifestPath")
     $xml.WriteAttributeString("Id", "_5ee276e0_1933_47ef_9696_d529b5b0b337")
     $xml.WriteAttributeString("KeyPath", "yes")
    $xml.WriteEndElement()
    $xml.WriteElementString("Condition","Privileged")
   $xml.WriteEndElement()
  $xml.WriteEndElement()

  $xml.Flush()
  $text_writer.WriteLine()

  $xml.WriteStartElement("FeatureGroup")
  $xml.WriteAttributeString("Id", "CoreFoundation")
   $xml.WriteStartElement("Feature")
    $xml.WriteAttributeString("Id", "CoreFoundationFiles")
    $xml.WriteAttributeString("Level", "1")
    $xml.WriteStartElement("ComponentGroupRef")
     $xml.WriteAttributeString("Id", "CoreFoundationFiles")
    $xml.WriteEndElement()
   $xml.WriteEndElement()
  $xml.WriteEndElement()

 $xml.WriteEndElement()
$xml.WriteEndElement()
$xml.Close()
