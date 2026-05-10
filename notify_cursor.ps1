# PowerShell script to show a system notification
Add-Type -AssemblyName System.Windows.Forms
$notification = New-Object System.Windows.Forms.NotifyIcon
$notification.Icon = [System.Drawing.SystemIcons]::Information
$notification.BalloonTipIcon = 'Info'
$notification.BalloonTipTitle = '任务完成提醒'
$notification.BalloonTipText = '任务已完成！请打开 Cursor 继续工作。'
$notification.Visible = $true
$notification.ShowBalloonTip(5000)
Start-Sleep -Seconds 5
$notification.Dispose()
