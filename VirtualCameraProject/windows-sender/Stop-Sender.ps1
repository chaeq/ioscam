$runtimePath = Join-Path $PSScriptRoot 'local-runtime\sender.pid'
if (Test-Path -LiteralPath $runtimePath) {
    $senderProcessId = [int](Get-Content -LiteralPath $runtimePath)
    $senderProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $senderProcessId"
    if ($senderProcess -and $senderProcess.CommandLine -like '*sender.py*--headless*local-media/selected-image.png*') {
        Stop-Process -Id $senderProcessId
        Write-Output 'Image sender stopped.'
    } else {
        Write-Output 'Recorded sender is no longer running.'
    }
}
