param(
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$CRTVersion="142",

    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string[]]$CoreFoundationDlls=@("CoreFoundation.dll", "BlocksRuntime.dll", "icudt68.dll", "icuin68.dll", "icuuc68.dll"),

    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$MergedManifestPath="merged.manifest",

    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$LocalManifestPath="local.manifest",

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

$redist_dir = Join-Path -Path $env:VCToolsRedistDir -ChildPath "x86\Microsoft.VC$($CRTVersion).CRT"
$redist_dlls = Get-ChildItem -Path $redist_dir -Filter "*.dll"
$full_merged_manifest_path = [IO.Path]::Combine((Get-Location), $MergedManifestPath)
$full_local_manifest_path = [IO.Path]::Combine((Get-Location), $LocalManifestPath)
$full_output_path = [IO.Path]::Combine((Get-Location), $OutputPath)
$xml_settings = New-Object -TypeName System.Xml.XmlWriterSettings
$xml_settings.Indent = $true
$xml_settings.IndentChars = "`t"
$xml_settings.CloseOutput = $true

$local_manifest_writer = New-Object -TypeName System.IO.StreamWriter -ArgumentList @($full_local_manifest_path, $false, [System.Text.Encoding]::UTF8)
[System.Xml.XmlWriter]$xml = [System.Xml.XmlWriter]::Create($local_manifest_writer, $xml_settings)
$xml.WriteStartElement("assembly", "urn:schemas-microsoft-com:asm.v1")
 $xml.WriteAttributeString("manifestVersion", "1.0")
 $xml.WriteStartElement("assemblyIdentity")
  $xml.WriteAttributeString("type", "win32")
  $xml.WriteAttributeString("name", "GroundControl.CoreFoundation")
  $xml.WriteAttributeString("version", "1.0.0.0")
 $xml.WriteEndElement()
 $CoreFoundationDlls | ForEach-Object -Process { add-manifestfile -xml $xml -FileName $_ }
 $redist_dlls | ForEach-Object -Process { add-manifestfile -xml $xml -FileName $_.Name }
$xml.WriteEndElement()
$xml.Close()

$merged_manifest_writer = New-Object -TypeName System.IO.StreamWriter -ArgumentList @($full_merged_manifest_path, $false, [System.Text.Encoding]::UTF8)
[System.Xml.XmlWriter]$xml = [System.Xml.XmlWriter]::Create($merged_manifest_writer, $xml_settings)
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
   $xml.WriteStartElement("Merge")
    $xml.WriteAttributeString("Id", "VCRedist")
    $xml.WriteAttributeString("SourceFile", "!(bindpath.cf)\Microsoft_VC$($CRTVersion)_CRT_x86.msm")
    $xml.WriteAttributeString("Language", "1033")
    $xml.WriteAttributeString("DiskId", "1")
   $xml.WriteEndElement()
   $xml.WriteStartElement("Directory")
    $xml.WriteAttributeString("Id", "CoreFoundation")
    $xml.WriteAttributeString("Name", "GroundControl.CoreFoundation")
   $xml.WriteEndElement()
  $xml.WriteEndElement()

  # Insert newline to visually separate element types
  $xml.Flush()
  $text_writer.WriteLine()

  $xml.WriteStartElement("ComponentGroup")
   $xml.WriteAttributeString("Id", "MainCoreFoundationFiles")
   $CoreFoundationDlls | ForEach-Object -Process { add-component -xml $xml -FileName $_ }
  $xml.WriteEndElement()

  $xml.Flush()
  $text_writer.WriteLine()

# The manifests need explicit Ids and Guids, since otherwise they'll conflict due to having the same target path
  $xml.WriteStartElement("ComponentGroup")
   $xml.WriteAttributeString("Id", "LocalCoreFoundationFiles")
   $xml.WriteStartElement("Component")
    $xml.WriteAttributeString("Directory", "CoreFoundation")
    $xml.WriteAttributeString("Guid", "95e0440d-0f08-4223-8389-e498cbb9ccfc")
    $xml.WriteStartElement("File")
     $xml.WriteAttributeString("Source", "!(bindpath.cf)\$(Split-Path -Path $full_local_manifest_path -Leaf)")
     $xml.WriteAttributeString("Name", "GroundControl.CoreFoundation.manifest")
     $xml.WriteAttributeString("Id", "_95e0440d_0f08_4223_8389_e498cbb9ccfc")
     $xml.WriteAttributeString("KeyPath", "yes")
    $xml.WriteEndElement()
    $xml.WriteElementString("Condition","NOT Privileged")
   $xml.WriteEndElement()
   $redist_dlls | ForEach-Object -Process { add-component -xml $xml -FileName $_.Name }
  $xml.WriteEndElement()

  $xml.Flush()
  $text_writer.WriteLine()

  $xml.WriteStartElement("ComponentGroup")
   $xml.WriteAttributeString("Id", "MergedCoreFoundationFiles")
   $xml.WriteStartElement("Component")
    $xml.WriteAttributeString("Directory", "CoreFoundation")
    $xml.WriteAttributeString("Guid", "5ee276e0-1933-47ef-9696-d529b5b0b337")
    $xml.WriteStartElement("File")
     $xml.WriteAttributeString("Source", "!(bindpath.cf)\$(Split-Path -Path $full_merged_manifest_path -Leaf)")
     $xml.WriteAttributeString("Name", "GroundControl.CoreFoundation.manifest")
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
    $xml.WriteAttributeString("Id", "MainCoreFoundationFiles")
    $xml.WriteAttributeString("Level", "1")
    $xml.WriteStartElement("ComponentGroupRef")
     $xml.WriteAttributeString("Id", "MainCoreFoundationFiles")
    $xml.WriteEndElement()
   $xml.WriteEndElement()
   $xml.WriteStartElement("Feature")
    $xml.WriteAttributeString("Id", "LocalCoreFoundationFiles")
    $xml.WriteAttributeString("Level", "0")
    $xml.WriteStartElement("ComponentGroupRef")
     $xml.WriteAttributeString("Id", "LocalCoreFoundationFiles")
    $xml.WriteEndElement()
    $xml.WriteStartElement("Condition")
     $xml.WriteAttributeString("Level", "1")
     $xml.WriteString("NOT Privileged")
    $xml.WriteEndElement()
   $xml.WriteEndElement()
   $xml.WriteStartElement("Feature")
    $xml.WriteAttributeString("Id", "MergedCoreFoundationFiles")
    $xml.WriteAttributeString("Level", "0")
    $xml.WriteStartElement("ComponentGroupRef")
     $xml.WriteAttributeString("Id", "MergedCoreFoundationFiles")
    $xml.WriteEndElement()
    $xml.WriteStartElement("MergeRef")
     $xml.WriteAttributeString("Id", "VCRedist")
    $xml.WriteEndElement()
    $xml.WriteStartElement("Condition")
     $xml.WriteAttributeString("Level", "1")
     $xml.WriteString("Privileged")
    $xml.WriteEndElement()
   $xml.WriteEndElement()
  $xml.WriteEndElement()

 $xml.WriteEndElement()
$xml.WriteEndElement()
$xml.Close()
