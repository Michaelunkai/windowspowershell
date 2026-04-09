using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace GitDesk
{
    /// <summary>
    /// High-level Git operations that wrap CLI commands for scenarios where LibGit2Sharp is insufficient.
    /// Provides enterprise-grade reliability with proper error handling and progress reporting.
    /// </summary>
    public class GitOperations
    {
        private readonly string _workingDirectory;

        public event Action<string>? ProgressChanged;
        public event Action<string>? StatusChanged;

        public GitOperations(string workingDirectory)
        {
            _workingDirectory = workingDirectory;
        }

        public async Task<GitResult> ExecuteAsync(string arguments, int timeoutMs = 60000)
        {
            return await Task.Run(() => Execute(arguments, timeoutMs));
        }

        public GitResult Execute(string arguments, int timeoutMs = 30000)
        {
            try
            {
                var psi = new ProcessStartInfo("git", arguments)
                {
                    WorkingDirectory = _workingDirectory,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                using var process = Process.Start(psi);
                if (process == null)
                    return GitResult.Failure("Failed to start git process");

                string output = process.StandardOutput.ReadToEnd();
                string error = process.StandardError.ReadToEnd();

                if (!process.WaitForExit(timeoutMs))
                {
                    process.Kill();
                    return GitResult.Failure("Operation timed out");
                }

                return process.ExitCode == 0
                    ? GitResult.Success(output)
                    : GitResult.Failure(string.IsNullOrWhiteSpace(error) ? output : error);
            }
            catch (Exception ex)
            {
                return GitResult.Failure($"Exception: {ex.Message}");
            }
        }

        public async Task<GitResult> CloneAsync(string url, string targetPath, Action<int>? progressCallback = null)
        {
            try
            {
                var psi = new ProcessStartInfo("git", $"clone --progress \"{url}\" \"{targetPath}\"")
                {
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                using var process = Process.Start(psi);
                if (process == null)
                    return GitResult.Failure("Failed to start git process");

                var errorOutput = "";
                process.ErrorDataReceived += (sender, e) =>
                {
                    if (e.Data != null)
                    {
                        errorOutput += e.Data + "\n";
                        ProgressChanged?.Invoke(e.Data);
                        
                        // Parse progress percentage
                        if (e.Data.Contains('%'))
                        {
                            var parts = e.Data.Split('%');
                            if (parts.Length > 0)
                            {
                                var percentStr = parts[0].Trim().Split(' ').Last();
                                if (int.TryParse(percentStr, out int percent))
                                    progressCallback?.Invoke(percent);
                            }
                        }
                    }
                };

                process.BeginErrorReadLine();
                await process.WaitForExitAsync();

                return process.ExitCode == 0
                    ? GitResult.Success("Clone completed successfully")
                    : GitResult.Failure(errorOutput);
            }
            catch (Exception ex)
            {
                return GitResult.Failure($"Clone exception: {ex.Message}");
            }
        }

        public async Task<GitResult> StashSaveAsync(string message)
        {
            return await ExecuteAsync($"stash push -m \"{message}\"");
        }

        public async Task<GitResult> StashPopAsync()
        {
            return await ExecuteAsync("stash pop");
        }

        public async Task<GitResult> StashApplyAsync(int index)
        {
            return await ExecuteAsync($"stash apply stash@{{{index}}}");
        }

        public async Task<GitResult> StashDropAsync(int index)
        {
            return await ExecuteAsync($"stash drop stash@{{{index}}}");
        }

        public async Task<GitResult> StashListAsync()
        {
            return await ExecuteAsync("stash list");
        }

        public async Task<GitResult> GetDiffAsync(string? path = null)
        {
            string args = string.IsNullOrEmpty(path) ? "diff" : $"diff -- \"{path}\"";
            return await ExecuteAsync(args);
        }

        public async Task<GitResult> GetDiffCachedAsync(string? path = null)
        {
            string args = string.IsNullOrEmpty(path) ? "diff --cached" : $"diff --cached -- \"{path}\"";
            return await ExecuteAsync(args);
        }

        public async Task<GitResult> GetBlameAsync(string path)
        {
            return await ExecuteAsync($"blame -- \"{path}\"");
        }

        public async Task<GitResult> GetLogAsync(int count = 100, string? path = null)
        {
            string args = string.IsNullOrEmpty(path)
                ? $"log -n {count} --format=\"%H|%an|%ae|%ai|%s\""
                : $"log -n {count} --format=\"%H|%an|%ae|%ai|%s\" -- \"{path}\"";
            return await ExecuteAsync(args);
        }

        public async Task<GitResult> GetRemotesAsync()
        {
            return await ExecuteAsync("remote -v");
        }

        public async Task<GitResult> GetBranchesAsync(bool includeRemote = false)
        {
            string args = includeRemote ? "branch -a" : "branch";
            return await ExecuteAsync(args);
        }

        public async Task<GitResult> GetTagsAsync()
        {
            return await ExecuteAsync("tag -l");
        }

        public async Task<GitResult> GetStatusAsync()
        {
            return await ExecuteAsync("status --porcelain");
        }

        public async Task<GitResult> DiscardChangesAsync(string path)
        {
            return await ExecuteAsync($"checkout -- \"{path}\"");
        }

        public async Task<GitResult> DiscardAllChangesAsync()
        {
            return await ExecuteAsync("reset --hard HEAD");
        }

        public async Task<GitResult> InitAsync(string path, bool bare = false)
        {
            string args = bare ? $"init --bare \"{path}\"" : $"init \"{path}\"";
            return await ExecuteAsync(args);
        }
    }

    public class GitResult
    {
        public bool IsSuccess { get; set; }
        public string Output { get; set; } = "";
        public string ErrorMessage { get; set; } = "";

        public static GitResult Success(string output = "")
        {
            return new GitResult { IsSuccess = true, Output = output };
        }

        public static GitResult Failure(string error)
        {
            return new GitResult { IsSuccess = false, ErrorMessage = error };
        }
    }
}
