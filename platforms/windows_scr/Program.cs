using System;
using System.Diagnostics;
using System.IO;
using System.Text.RegularExpressions;

/// <summary>
/// Thin Windows screen saver host (.scr) that launches open_fliqlo.exe
/// with --screensaver / --configure / --preview.
/// </summary>
internal static class Program
{
    private static int Main(string[] args)
    {
        var mode = ParseMode(args, out var previewHwnd);
        var exe = FindFlutterExe();
        if (exe == null)
        {
            Console.Error.WriteLine(
                "open_fliqlo.exe not found next to OpenFliqlo.scr");
            return 1;
        }

        return mode switch
        {
            ScrMode.Screensaver => Run(exe, "--screensaver", wait: true),
            ScrMode.Configure => Run(exe, "--configure", wait: true),
            ScrMode.Preview => RunPreview(exe, previewHwnd),
            _ => 0,
        };
    }

    private enum ScrMode
    {
        None,
        Screensaver,
        Configure,
        Preview,
    }

    private static ScrMode ParseMode(string[] args, out string? previewHwnd)
    {
        previewHwnd = null;
        // Windows may pass: /s  /c  /c:1234  /p 1234  /P 1234
        for (var i = 0; i < args.Length; i++)
        {
            var a = args[i];
            if (a.Equals("/s", StringComparison.OrdinalIgnoreCase) ||
                a.Equals("-s", StringComparison.OrdinalIgnoreCase))
            {
                return ScrMode.Screensaver;
            }

            if (a.StartsWith("/c", StringComparison.OrdinalIgnoreCase) ||
                a.StartsWith("-c", StringComparison.OrdinalIgnoreCase))
            {
                return ScrMode.Configure;
            }

            if (a.Equals("/p", StringComparison.OrdinalIgnoreCase) ||
                a.Equals("-p", StringComparison.OrdinalIgnoreCase) ||
                a.Equals("/P", StringComparison.OrdinalIgnoreCase))
            {
                if (i + 1 < args.Length)
                {
                    previewHwnd = args[i + 1];
                }
                return ScrMode.Preview;
            }

            // Combined form /p:HWND
            var m = Regex.Match(a, @"^/[pP]:(.+)$");
            if (m.Success)
            {
                previewHwnd = m.Groups[1].Value;
                return ScrMode.Preview;
            }
        }

        // Double-click .scr → configure on some Windows versions; prefer screensaver.
        return ScrMode.Screensaver;
    }

    private static string? FindFlutterExe()
    {
        var baseDir = AppContext.BaseDirectory;
        var candidates = new[]
        {
            Path.Combine(baseDir, "open_fliqlo.exe"),
            Path.Combine(baseDir, "OpenFliqlo.exe"),
            Path.GetFullPath(Path.Combine(baseDir, "..", "open_fliqlo.exe")),
        };
        foreach (var c in candidates)
        {
            if (File.Exists(c))
            {
                return c;
            }
        }
        return null;
    }

    private static int Run(string exe, string arg, bool wait)
    {
        var psi = new ProcessStartInfo
        {
            FileName = exe,
            Arguments = arg,
            UseShellExecute = false,
            WorkingDirectory = Path.GetDirectoryName(exe) ?? AppContext.BaseDirectory,
        };
        using var proc = Process.Start(psi);
        if (proc == null)
        {
            return 1;
        }
        if (wait)
        {
            proc.WaitForExit();
            return proc.ExitCode;
        }
        return 0;
    }

    private static int RunPreview(string exe, string? hwnd)
    {
        var psi = new ProcessStartInfo
        {
            FileName = exe,
            Arguments = "--preview",
            UseShellExecute = false,
            WorkingDirectory = Path.GetDirectoryName(exe) ?? AppContext.BaseDirectory,
        };
        if (!string.IsNullOrEmpty(hwnd))
        {
            psi.Environment["OPEN_FLIQLO_PREVIEW_HWND"] = hwnd;
        }
        using var proc = Process.Start(psi);
        if (proc == null)
        {
            return 1;
        }
        // Preview: wait until Control Panel closes the preview child (process kill)
        // or the Flutter window exits.
        proc.WaitForExit();
        return proc.ExitCode;
    }
}
