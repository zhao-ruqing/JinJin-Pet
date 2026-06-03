Add-Type -AssemblyName PresentationCore, PresentationFramework, WindowsBase

$ErrorActionPreference = "Stop"
$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $AppDir "pet-config.json"
$SpritePath = Join-Path $AppDir "spritesheet.png"

$DefaultConfig = @{
    scale = 1.15
    fps = 8
    state = "idle"
    autoState = $true
    left = $null
    top = $null
}

if (Test-Path -LiteralPath $ConfigPath) {
    $Config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
} else {
    $Config = [pscustomobject]$DefaultConfig
}

$Rows = @{
    idle = @{ row = 0; frames = 6 }
    "running-right" = @{ row = 1; frames = 8 }
    "running-left" = @{ row = 2; frames = 8 }
    waving = @{ row = 3; frames = 4 }
    "happy-wave" = @{ row = 3; frames = 4 }
    jumping = @{ row = 4; frames = 5 }
    failed = @{ row = 5; frames = 8 }
    sleepy = @{ row = 5; frames = 8 }
    waiting = @{ row = 6; frames = 6 }
    surprised = @{ row = 6; frames = 6 }
    running = @{ row = 7; frames = 6 }
    coding = @{ row = 7; frames = 6 }
    review = @{ row = 8; frames = 6 }
    thinking = @{ row = 8; frames = 6 }
}

if (-not (Test-Path -LiteralPath $SpritePath)) {
    [System.Windows.MessageBox]::Show("Missing spritesheet.png in $AppDir", "Jinjin Pet") | Out-Null
    exit 1
}

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class ForegroundWindowInfo {
    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    public static string CurrentProcessName() {
        IntPtr hwnd = GetForegroundWindow();
        if (hwnd == IntPtr.Zero) return "";
        uint pid;
        GetWindowThreadProcessId(hwnd, out pid);
        try {
            return System.Diagnostics.Process.GetProcessById((int)pid).ProcessName;
        } catch {
            return "";
        }
    }

    public static string CurrentTitle() {
        IntPtr hwnd = GetForegroundWindow();
        if (hwnd == IntPtr.Zero) return "";
        StringBuilder text = new StringBuilder(512);
        GetWindowText(hwnd, text, text.Capacity);
        return text.ToString();
    }
}

public static class InputInfo {
    [StructLayout(LayoutKind.Sequential)]
    public struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT {
        public int X;
        public int Y;
    }

    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int vKey);

    [DllImport("user32.dll")]
    private static extern bool GetCursorPos(out POINT point);

    [DllImport("user32.dll")]
    private static extern bool GetLastInputInfo(ref LASTINPUTINFO info);

    public static bool IsBackspaceDown() {
        return (GetAsyncKeyState(0x08) & 0x8000) != 0;
    }

    public static uint GetIdleMilliseconds() {
        LASTINPUTINFO info = new LASTINPUTINFO();
        info.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
        if (!GetLastInputInfo(ref info)) return 0;
        return unchecked((uint)Environment.TickCount - info.dwTime);
    }

    public static string CursorPosition() {
        POINT point;
        if (!GetCursorPos(out point)) return "";
        return point.X.ToString() + "," + point.Y.ToString();
    }
}
"@

$CellW = 192
$CellH = 208
$MinScale = 0.55
$MaxScale = 2.4
$Scale = [double]$Config.scale
if ($Scale -lt $MinScale) { $Scale = $MinScale }
if ($Scale -gt $MaxScale) { $Scale = $MaxScale }
$State = if ($Rows.ContainsKey([string]$Config.state)) { [string]$Config.state } else { "idle" }
$AutoState = if ($null -eq $Config.autoState) { $true } else { [bool]$Config.autoState }
$Hovering = $false
$BackspaceStateUntil = [DateTime]::MinValue
$FailedIdleDelayMs = 10000

$Window = New-Object System.Windows.Window
$Window.Title = "Jinjin Pet"
$Window.Width = $CellW * $Scale
$Window.Height = $CellH * $Scale
$Window.MinWidth = $CellW * $MinScale
$Window.MinHeight = $CellH * $MinScale
$Window.MaxWidth = $CellW * $MaxScale
$Window.MaxHeight = $CellH * $MaxScale
$Window.WindowStyle = "None"
$Window.ResizeMode = "CanResizeWithGrip"
$Window.AllowsTransparency = $true
$Window.Background = [System.Windows.Media.Brushes]::Transparent
$Window.Topmost = $true
$Window.ShowInTaskbar = $false
$Window.SnapsToDevicePixels = $true
$Window.SizeToContent = "Manual"

$WorkArea = [System.Windows.SystemParameters]::WorkArea
if ($null -eq $Config.left) {
    $Window.Left = $WorkArea.Right - $Window.Width - 28
} else {
    $Window.Left = [double]$Config.left
}
if ($null -eq $Config.top) {
    $Window.Top = $WorkArea.Bottom - $Window.Height - 28
} else {
    $Window.Top = [double]$Config.top
}

$Bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
$Bitmap.BeginInit()
$Bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$Bitmap.UriSource = New-Object System.Uri($SpritePath)
$Bitmap.EndInit()
$Bitmap.Freeze()

$Image = New-Object System.Windows.Controls.Image
$Image.Stretch = "Fill"
$Image.SnapsToDevicePixels = $true
$Image.HorizontalAlignment = "Stretch"
$Image.VerticalAlignment = "Stretch"
$Window.Content = $Image

$Frame = 0

function Set-PetState([string]$NextState) {
    if (-not $Rows.ContainsKey($NextState)) {
        return
    }
    if ($script:State -ne $NextState) {
        $script:State = $NextState
        $script:Frame = 0
        Set-PetFrame
    }
}

function Set-PetFrame {
    $Info = $Rows[$script:State]
    $Rect = New-Object System.Windows.Int32Rect(($script:Frame * $CellW), ($Info.row * $CellH), $CellW, $CellH)
    $Crop = New-Object System.Windows.Media.Imaging.CroppedBitmap($Bitmap, $Rect)
    $Image.Source = $Crop
}

function Save-PetConfig {
    $script:Scale = [math]::Round(($Window.Width / $CellW), 3)
    $Out = [ordered]@{
        scale = $script:Scale
        fps = [int]$Config.fps
        state = $script:State
        autoState = $script:AutoState
        left = [math]::Round($Window.Left, 0)
        top = [math]::Round($Window.Top, 0)
    }
    $Out | ConvertTo-Json | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
}

function Resize-Pet([double]$NextScale) {
    if ($NextScale -lt $MinScale) { $NextScale = $MinScale }
    if ($NextScale -gt $MaxScale) { $NextScale = $MaxScale }
    $CenterX = $Window.Left + ($Window.Width / 2)
    $CenterY = $Window.Top + ($Window.Height / 2)
    $Window.Width = $CellW * $NextScale
    $Window.Height = $CellH * $NextScale
    $Window.Left = $CenterX - ($Window.Width / 2)
    $Window.Top = $CenterY - ($Window.Height / 2)
    $script:Scale = $NextScale
    Save-PetConfig
}

function Get-AutoPetState {
    $Process = ([ForegroundWindowInfo]::CurrentProcessName()).ToLowerInvariant()
    $Title = ([ForegroundWindowInfo]::CurrentTitle()).ToLowerInvariant()
    $Text = "$Process $Title"

    if ($Text -match "cursor|code|devenv|trae|webstorm|pycharm|idea|terminal|powershell|cmd|git|node|python|npm|pnpm|yarn") {
        if ($Text -match "diff|merge|review|pull request|pr |error|exception|debug|test|terminal|console|log") {
            return "thinking"
        }
        return "coding"
    }

    if ($Text -match "claude|chatgpt|copilot|browser|chrome|edge|firefox") {
        return "thinking"
    }

    return "idle"
}

$Menu = New-Object System.Windows.Controls.ContextMenu
$AutoItem = New-Object System.Windows.Controls.MenuItem
$AutoItem.Header = "Auto actions"
$AutoItem.IsCheckable = $true
$AutoItem.IsChecked = $AutoState
$AutoItem.Add_Click({
    $script:AutoState = [bool]$this.IsChecked
    Save-PetConfig
})
$Menu.Items.Add($AutoItem) | Out-Null
$Menu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

foreach ($Name in @("idle", "happy-wave", "coding", "thinking", "jumping", "waiting", "failed")) {
    $Item = New-Object System.Windows.Controls.MenuItem
    $Item.Header = $Name
    $Item.Add_Click({
        $script:AutoState = $false
        $AutoItem.IsChecked = $false
        Set-PetState ([string]$this.Header)
        Save-PetConfig
    })
    $Menu.Items.Add($Item) | Out-Null
}

$Menu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null
foreach ($Name in @("sleepy", "surprised")) {
    $Item = New-Object System.Windows.Controls.MenuItem
    $Item.Header = $Name
    $Item.Add_Click({
        $script:AutoState = $false
        $AutoItem.IsChecked = $false
        Set-PetState ([string]$this.Header)
        Save-PetConfig
    })
    $Menu.Items.Add($Item) | Out-Null
}

$Menu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null
foreach ($Pair in @(@("Small", 0.8), @("Normal", 1.15), @("Large", 1.55), @("Huge", 2.0))) {
    $SizeItem = New-Object System.Windows.Controls.MenuItem
    $SizeItem.Header = $Pair[0]
    $SizeValue = [double]$Pair[1]
    $SizeItem.Add_Click({ Resize-Pet $SizeValue }.GetNewClosure())
    $Menu.Items.Add($SizeItem) | Out-Null
}

$Menu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null
$ExitItem = New-Object System.Windows.Controls.MenuItem
$ExitItem.Header = "Exit"
$ExitItem.Add_Click({ Save-PetConfig; $Window.Close() })
$Menu.Items.Add($ExitItem) | Out-Null
$Image.ContextMenu = $Menu

$Image.Add_MouseEnter({
    $script:Hovering = $true
    Set-PetState "happy-wave"
})
$Image.Add_MouseLeave({
    $script:Hovering = $false
    if ($script:AutoState) {
        Set-PetState (Get-AutoPetState)
    }
})
$Image.Add_MouseWheel({
    if ($_.Delta -gt 0) {
        Resize-Pet ($script:Scale + 0.08)
    } else {
        Resize-Pet ($script:Scale - 0.08)
    }
})
$Image.Add_MouseLeftButtonDown({
    try {
        $Window.DragMove()
        Save-PetConfig
    } catch {
    }
})

$Window.Add_SizeChanged({
    $RatioScale = [math]::Min($Window.Width / $CellW, $Window.Height / $CellH)
    if ([math]::Abs(($Window.Width / $Window.Height) - ($CellW / $CellH)) -gt 0.01) {
        $Window.Width = $CellW * $RatioScale
        $Window.Height = $CellH * $RatioScale
    }
    $script:Scale = [math]::Round(($Window.Width / $CellW), 3)
})

$Timer = New-Object System.Windows.Threading.DispatcherTimer
$Timer.Interval = [TimeSpan]::FromMilliseconds([math]::Max(80, 1000 / [int]$Config.fps))
$Timer.Add_Tick({
    $Info = $Rows[$script:State]
    $script:Frame = ($script:Frame + 1) % $Info.frames
    Set-PetFrame
})

$AutoTimer = New-Object System.Windows.Threading.DispatcherTimer
$AutoTimer.Interval = [TimeSpan]::FromMilliseconds(250)
$AutoTimer.Add_Tick({
    $Now = [DateTime]::UtcNow
    if ([InputInfo]::IsBackspaceDown()) {
        $script:BackspaceStateUntil = $Now.AddMilliseconds(850)
    }
    if ($script:AutoState -and -not $script:Hovering) {
        if ($Now -lt $script:BackspaceStateUntil) {
            Set-PetState "surprised"
        } elseif ([InputInfo]::GetIdleMilliseconds() -ge $FailedIdleDelayMs) {
            Set-PetState "failed"
        } else {
            Set-PetState (Get-AutoPetState)
        }
    }
})

$Window.Add_SourceInitialized({
    Set-PetFrame
    $Timer.Start()
    $AutoTimer.Start()
})
$Window.Add_Closing({ Save-PetConfig })

$App = New-Object System.Windows.Application
$App.ShutdownMode = "OnMainWindowClose"
$App.Run($Window) | Out-Null
