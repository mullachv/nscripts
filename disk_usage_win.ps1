#requires powershell -version 3.0

$path = "D:\Program Files (x86)\"
$fso = New-Object -ComObject scripting.filesystemobject
$folders = Foreach($folder in (Get-ChildItem $path -Directory -Recurse))
{
 New-Object -TypeName psobject -Property @{
  name=$fso.getFolder($folder.fullname.tostring()).path;
  size=[int]($fso.GetFolder($folder.FullName.ToString()).size /1MB)} 
  }

$folders | sort size -Descending | ? size -gt 1000 | out-gridview

