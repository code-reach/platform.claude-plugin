# MARU launcher MCP relay (Windows PowerShell 5.1 - ships with Windows, nothing to install).
#
# The launcher hosts its MCP server on a local named pipe while it runs. This script finds
# whichever MARU launcher is running on this PC and relays bytes between Claude Code (stdio)
# and that pipe. It does not parse MCP; stdout carries MCP only, diagnostics go to stderr.
#
# Pipe names must match the names the launcher serves ("<launcher instance>-mcp").
# Exit codes: 0 normal end, 1 connect failed, 2 no launcher running, 3 more than one running.
# To pick one when several run, set MARU_LAUNCHER_PIPE (for example maru-launcher-test-mcp).

$launcherPipes = @("maru-launcher-mcp", "maru-launcher-test-mcp", "vrsports-v2-launcher-mcp")

$target = "$env:MARU_LAUNCHER_PIPE"
if ($target -eq "") {
    $running = @([System.IO.Directory]::GetFiles("\\.\pipe\") |
        ForEach-Object { [System.IO.Path]::GetFileName($_) } |
        Where-Object { $launcherPipes -contains $_ })
    if ($running.Count -eq 0) {
        [Console]::Error.WriteLine("launcher mcp: no MARU launcher is running on this PC. start the launcher, then reconnect this server (/mcp).")
        exit 2
    }
    if ($running.Count -gt 1) {
        [Console]::Error.WriteLine("launcher mcp: several launchers are running (" + ($running -join ", ") + "). set MARU_LAUNCHER_PIPE to one of them.")
        exit 3
    }
    $target = $running[0]
}

$pipe = New-Object System.IO.Pipes.NamedPipeClientStream(".", $target, [System.IO.Pipes.PipeDirection]::InOut, [System.IO.Pipes.PipeOptions]::Asynchronous)
try {
    $pipe.Connect(3000)
}
catch {
    [Console]::Error.WriteLine("launcher mcp: connect failed, pipe: " + $target + ", error: " + $_.Exception.Message)
    exit 1
}
[Console]::Error.WriteLine("launcher mcp: connected, pipe: " + $target)

# Either side closing ends the relay: Claude Code closing stdin, or the launcher quitting.
$stdin = [Console]::OpenStandardInput()
$stdout = [Console]::OpenStandardOutput()
$upstream = $stdin.CopyToAsync($pipe)
$downstream = $pipe.CopyToAsync($stdout)
[void][System.Threading.Tasks.Task]::WaitAny(@($upstream, $downstream))
$pipe.Dispose()
exit 0
