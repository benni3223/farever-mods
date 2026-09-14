param([Parameter(Mandatory=$true)][string]$Plugin)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DesktopTest {
    [DllImport("kernel32", CharSet=CharSet.Unicode, SetLastError=true)] public static extern IntPtr LoadLibrary(string path);
    [DllImport("kernel32", CharSet=CharSet.Ansi)] public static extern IntPtr GetProcAddress(IntPtr module, string name);
    [DllImport("user32", SetLastError=true)] public static extern bool OpenClipboard(IntPtr owner);
    [DllImport("user32")] public static extern bool CloseClipboard();
    [DllImport("user32")] public static extern IntPtr GetClipboardData(uint format);
    [DllImport("kernel32")] public static extern IntPtr GlobalLock(IntPtr memory);
    [DllImport("kernel32")] public static extern bool GlobalUnlock(IntPtr memory);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate IntPtr Primitive(out IntPtr signature);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate int PathAction(byte[] path, int length);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate int CopyImage(byte[] bytes, int length, int width, int height);
    public static Delegate Bind(IntPtr module, string name, string expected, Type type) {
        IntPtr address = GetProcAddress(module, name);
        if (address == IntPtr.Zero) throw new Exception("Missing export: " + name);
        var registration = (Primitive)Marshal.GetDelegateForFunctionPointer(address, typeof(Primitive));
        IntPtr signature;
        IntPtr function = registration(out signature);
        if (Marshal.PtrToStringAnsi(signature) != expected) throw new Exception("Wrong HL signature: " + name);
        return Marshal.GetDelegateForFunctionPointer(function, type);
    }
    public static void CheckClipboard() {
        if (!OpenClipboard(IntPtr.Zero)) throw new Exception("Cannot read clipboard");
        try {
            IntPtr handle = GetClipboardData(8); // CF_DIB
            IntPtr data = GlobalLock(handle);
            if (data == IntPtr.Zero) throw new Exception("Missing clipboard DIB");
            try {
                if (Marshal.ReadInt32(data, 0) != 40 || Marshal.ReadInt32(data, 4) != 2 || Marshal.ReadInt32(data, 8) != 2)
                    throw new Exception("Wrong DIB dimensions");
                if (Marshal.ReadByte(data, 40) != 255 || Marshal.ReadByte(data, 42) != 0 || Marshal.ReadByte(data, 43) != 0)
                    throw new Exception("Bottom blue pixel was not preserved");
                if (Marshal.ReadByte(data, 48) != 0 || Marshal.ReadByte(data, 50) != 255)
                    throw new Exception("Top red pixel was not preserved");
            } finally { GlobalUnlock(handle); }
        } finally { CloseClipboard(); }
    }
}
'@
$module = [DesktopTest]::LoadLibrary((Resolve-Path -LiteralPath $Plugin).Path)
if ($module -eq [IntPtr]::Zero) { throw "Could not load desktop plugin: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())" }
$copy = [DesktopTest]::Bind($module, 'hlp_copy_image', 'PBiii_i', [DesktopTest+CopyImage])
$recycle = [DesktopTest]::Bind($module, 'hlp_recycle_file', 'PBi_i', [DesktopTest+PathAction])
$open = [DesktopTest]::Bind($module, 'hlp_open_folder', 'PBi_i', [DesktopTest+PathAction])
[byte[]]$pixels = 0,0,255,255, 0,255,0,255, 255,0,0,255, 255,255,255,255
if ($copy.Invoke($pixels, 16, 2, 2) -ne 0) { throw 'Could not write native clipboard image' }
[DesktopTest]::CheckClipboard()
if ($copy.Invoke($pixels, 15, 2, 2) -eq 0) { throw 'Truncated pixel buffer was accepted' }
[DesktopTest]::CheckClipboard() # Failed copies must leave the previous image intact.

$folder = Join-Path ([IO.Path]::GetTempPath()) ('dps-desktop-test-測試 & ' + [Guid]::NewGuid())
[IO.Directory]::CreateDirectory($folder) | Out-Null
$path = Join-Path $folder 'fight.json'
$content = '{"fixture":"recoverable combat log"}'
[IO.File]::WriteAllText($path, $content)
try {
    $bytes = [Text.Encoding]::UTF8.GetBytes($folder)
    if ($recycle.Invoke($bytes, $bytes.Length) -eq 0) { throw 'Directory deletion was accepted' }
    if (-not [IO.File]::Exists($path)) { throw 'Directory rejection changed its contents' }
    $invalid = [Text.Encoding]::UTF8.GetBytes('https://example.invalid')
    if ($open.Invoke($invalid, $invalid.Length) -eq 0) { throw 'Non-filesystem folder target was accepted' }
    $bytes = [Text.Encoding]::UTF8.GetBytes($path)
    $result = $recycle.Invoke($bytes, $bytes.Length)
    if ($result -ne 0) { throw "Native recycling failed: $result" }
    if ([IO.File]::Exists($path)) { throw 'Recycled fixture is still at its original path' }
    $shell = New-Object -ComObject Shell.Application
    $recovered = @($shell.Namespace(10).Items() | Where-Object { $_.ExtendedProperty('System.Recycle.DeletedFrom') -eq $folder })
    if ($recovered.Count -ne 1) { throw 'The fixture was not found in the actual Windows Recycle Bin' }
    if ([IO.File]::ReadAllText($recovered[0].Path) -ne $content) { throw 'Recycled contents differ' }
    $recovered[0].InvokeVerb('undelete')
    for ($attempt = 0; $attempt -lt 40 -and -not [IO.File]::Exists($path); $attempt++) { Start-Sleep -Milliseconds 250 }
    if (-not [IO.File]::Exists($path) -or [IO.File]::ReadAllText($path) -ne $content) { throw 'Recycle Bin restore did not recover the original file' }
    Write-Output 'Windows desktop: plugin ABI, clipboard image, validation, Unicode recycling, and Recycle Bin restore passed'
} finally {
    # Only this test's uniquely named temporary directory is removed.
    if ([IO.Directory]::Exists($folder)) { [IO.Directory]::Delete($folder, $true) }
}
