using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Media;
using System.Windows.Threading;
using LibGit2Sharp;

namespace GitDesk
{
    public partial class MainWindow : Window
    {
        private Repository? _repo;
        private string? _repoPath;
        private ObservableCollection<FileChange> _changedFiles = new();
        private ObservableCollection<CommitInfo> _history = new();
        private ObservableCollection<BranchInfo> _branches = new();
        private ObservableCollection<string> _stashes = new();
        private ObservableCollection<string> _tags = new();
        private ObservableCollection<RemoteInfo> _remotes = new();
        private DispatcherTimer? _refreshTimer;
        private FileSystemWatcher? _watcher;
        private bool _isRefreshing = false;

        public MainWindow()
        {
            InitializeComponent();
            
            // Restore window state
            var (width, height, maximized) = RepoManager.GetWindowState();
            Width = width;
            Height = height;
            if (maximized)
                WindowState = WindowState.Maximized;
            
            ChangedFilesList.ItemsSource = _changedFiles;
            HistoryList.ItemsSource = _history;
            BranchList.ItemsSource = _branches;
            StashList.ItemsSource = _stashes;
            TagList.ItemsSource = _tags;
            RemoteList.ItemsSource = _remotes;

            WelcomeView.RepoSelected += async path =>
            {
                string repoRoot = Repository.Discover(path) ?? "";
                if (!string.IsNullOrEmpty(repoRoot))
                    await OpenRepoAsync(repoRoot);
                else
                    await OpenRepoAsync(path);
            };
            
            // Auto-restore last repo
            Loaded += async (s, e) =>
            {
                var lastRepo = RepoManager.GetLastRepo();
                if (!string.IsNullOrEmpty(lastRepo) && Directory.Exists(lastRepo))
                {
                    await OpenRepoAsync(lastRepo);
                }
            };

            // Keyboard shortcuts
            InputBindings.Add(new System.Windows.Input.KeyBinding(
                new RelayCommand(_ => OpenRepo_Click(this, new RoutedEventArgs())),
                System.Windows.Input.Key.O, System.Windows.Input.ModifierKeys.Control));
            InputBindings.Add(new System.Windows.Input.KeyBinding(
                new RelayCommand(async _ => { if (_repo != null) { Commands.Stage(_repo, "*"); await RefreshChangesAsync(); SetStatus("All staged."); } }),
                System.Windows.Input.Key.A, System.Windows.Input.ModifierKeys.Control | System.Windows.Input.ModifierKeys.Shift));
            InputBindings.Add(new System.Windows.Input.KeyBinding(
                new RelayCommand(_ => Fetch_Click(this, new RoutedEventArgs())),
                System.Windows.Input.Key.F, System.Windows.Input.ModifierKeys.Control | System.Windows.Input.ModifierKeys.Shift));
            InputBindings.Add(new System.Windows.Input.KeyBinding(
                new RelayCommand(_ => Pull_Click(this, new RoutedEventArgs())),
                System.Windows.Input.Key.P, System.Windows.Input.ModifierKeys.Control | System.Windows.Input.ModifierKeys.Shift));
            InputBindings.Add(new System.Windows.Input.KeyBinding(
                new RelayCommand(_ => Push_Click(this, new RoutedEventArgs())),
                System.Windows.Input.Key.U, System.Windows.Input.ModifierKeys.Control | System.Windows.Input.ModifierKeys.Shift));
            InputBindings.Add(new System.Windows.Input.KeyBinding(
                new RelayCommand(_ => RefreshAll()),
                System.Windows.Input.Key.F5, System.Windows.Input.ModifierKeys.None));
            InputBindings.Add(new System.Windows.Input.KeyBinding(
                new RelayCommand(_ => { if (_repo != null) Commit_Click(this, new RoutedEventArgs()); }),
                System.Windows.Input.Key.Return, System.Windows.Input.ModifierKeys.Control));
            InputBindings.Add(new System.Windows.Input.KeyBinding(
                new RelayCommand(_ => ShowHelp()),
                System.Windows.Input.Key.OemQuestion, System.Windows.Input.ModifierKeys.Control));
        }

        private void SetStatus(string msg)
        {
            Dispatcher.Invoke(() => StatusText.Text = msg);
        }

        private void SetProgress(bool isActive, string message = "")
        {
            Dispatcher.Invoke(() =>
            {
                ProgressIndicator.Visibility = isActive ? Visibility.Visible : Visibility.Collapsed;
                if (!string.IsNullOrEmpty(message))
                    ProgressText.Text = message;
            });
        }

        private async Task<string> RunGitAsync(string args)
        {
            if (_repoPath == null) return "";
            return await Task.Run(() =>
            {
                var psi = new ProcessStartInfo("git", args)
                {
                    WorkingDirectory = _repoPath,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };
                var proc = Process.Start(psi);
                if (proc == null) return "";
                string output = proc.StandardOutput.ReadToEnd();
                proc.WaitForExit(30000);
                return output;
            });
        }

        private string RunGit(string args)
        {
            if (_repoPath == null) return "";
            var psi = new ProcessStartInfo("git", args)
            {
                WorkingDirectory = _repoPath,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };
            var proc = Process.Start(psi);
            if (proc == null) return "";
            string output = proc.StandardOutput.ReadToEnd();
            proc.WaitForExit(10000);
            return output;
        }

        private async Task OpenRepoAsync(string path)
        {
            try
            {
                SetProgress(true, "Opening repository...");
                await Task.Run(() =>
                {
                    _repo?.Dispose();
                    _repo = new Repository(path);
                    _repoPath = path;
                });

                RepoNameText.Text = Path.GetFileName(path.TrimEnd('\\', '/'));
                SetStatus($"Opened: {path}");
                WelcomeView.Visibility = Visibility.Collapsed;
                RepoManager.AddRecent(path);
                SetupFileWatcher(path);
                await RefreshAllAsync();
            }
            catch (Exception ex)
            {
                ErrorHandler.Handle(ex, $"Opening repository: {path}");
            }
            finally
            {
                SetProgress(false);
            }
        }

        private void RefreshAll()
        {
            _ = RefreshAllAsync();
        }

        private async Task RefreshAllAsync()
        {
            if (_repo == null || _isRefreshing) return;
            _isRefreshing = true;
            try
            {
                await Task.WhenAll(
                    RefreshChangesAsync(),
                    RefreshHistoryAsync(),
                    RefreshBranchesAsync(),
                    RefreshStashesAsync(),
                    RefreshTagsAsync(),
                    RefreshRemotesAsync()
                );
                await Dispatcher.InvokeAsync(UpdateBranchBar);
            }
            finally
            {
                _isRefreshing = false;
            }
        }

        private async Task RefreshChangesAsync()
        {
            if (_repo == null) return;
            var changes = await Task.Run(() =>
            {
                var status = _repo.RetrieveStatus(new StatusOptions());
                return status.Where(e => e.State != FileStatus.Ignored && e.State != FileStatus.Unaltered)
                    .Select(entry => new FileChange
                    {
                        FilePath = entry.FilePath,
                        FileName = Path.GetFileName(entry.FilePath),
                        State = entry.State,
                        StatusIcon = GetStatusIcon(entry.State)
                    }).ToList();
            });

            await Dispatcher.InvokeAsync(() =>
            {
                _changedFiles.Clear();
                foreach (var change in changes)
                    _changedFiles.Add(change);
                FileCountText.Text = $"{_changedFiles.Count} changed file{(_changedFiles.Count != 1 ? "s" : "")}";
            });
        }

        private string GetStatusIcon(FileStatus state)
        {
            if (state.HasFlag(FileStatus.NewInWorkdir) || state.HasFlag(FileStatus.NewInIndex)) return "🟢";
            if (state.HasFlag(FileStatus.ModifiedInWorkdir) || state.HasFlag(FileStatus.ModifiedInIndex)) return "🟡";
            if (state.HasFlag(FileStatus.DeletedFromWorkdir) || state.HasFlag(FileStatus.DeletedFromIndex)) return "🔴";
            if (state.HasFlag(FileStatus.RenamedInWorkdir) || state.HasFlag(FileStatus.RenamedInIndex)) return "🔵";
            if (state.HasFlag(FileStatus.Conflicted)) return "⚠️";
            return "⚪";
        }

        private async Task RefreshHistoryAsync()
        {
            if (_repo == null) return;
            var commits = await Task.Run(() =>
            {
                try
                {
                    return _repo.Commits.Take(200).Select(c => new CommitInfo
                    {
                        Sha = c.Sha,
                        MessageShort = c.MessageShort,
                        AuthorName = c.Author.Name,
                        AuthorEmail = c.Author.Email,
                        When = c.Author.When,
                        TimeAgo = GetTimeAgo(c.Author.When)
                    }).ToList();
                }
                catch { return new List<CommitInfo>(); }
            });

            await Dispatcher.InvokeAsync(() =>
            {
                _history.Clear();
                foreach (var commit in commits)
                    _history.Add(commit);
            });
        }

        private async Task RefreshBranchesAsync()
        {
            if (_repo == null) return;
            var branches = await Task.Run(() =>
                _repo.Branches.Where(b => !b.IsRemote)
                    .Select(b => new BranchInfo
                    {
                        Name = b.FriendlyName,
                        IsHead = b.IsCurrentRepositoryHead
                    }).ToList()
            );

            await Dispatcher.InvokeAsync(() =>
            {
                _branches.Clear();
                BranchCombo.Items.Clear();
                foreach (var b in branches)
                {
                    _branches.Add(b);
                    BranchCombo.Items.Add(b.Name);
                    if (b.IsHead)
                        BranchCombo.SelectedItem = b.Name;
                }
            });
        }

        private async Task RefreshStashesAsync()
        {
            if (_repo == null) return;
            try
            {
                string output = await RunGitAsync("stash list");
                var stashes = output.Split('\n', StringSplitOptions.RemoveEmptyEntries)
                    .Select(line => line.Trim()).ToList();

                await Dispatcher.InvokeAsync(() =>
                {
                    _stashes.Clear();
                    foreach (var stash in stashes)
                        _stashes.Add(stash);
                });
            }
            catch { }
        }

        private async Task RefreshTagsAsync()
        {
            if (_repo == null) return;
            var tags = await Task.Run(() =>
                _repo.Tags.Select(t => t.FriendlyName).ToList()
            );

            await Dispatcher.InvokeAsync(() =>
            {
                _tags.Clear();
                foreach (var tag in tags)
                    _tags.Add(tag);
            });
        }

        private async Task RefreshRemotesAsync()
        {
            if (_repo == null) return;
            var remotes = await Task.Run(() =>
                _repo.Network.Remotes.Select(r => new RemoteInfo
                {
                    Name = r.Name,
                    Url = r.Url
                }).ToList()
            );

            await Dispatcher.InvokeAsync(() =>
            {
                _remotes.Clear();
                foreach (var remote in remotes)
                    _remotes.Add(remote);
            });
        }

        private void UpdateBranchBar()
        {
            if (_repo == null) return;
            var head = _repo.Head;
            BranchStatusText.Text = $"⑂ {head.FriendlyName}";
            try
            {
                if (head.TrackedBranch != null)
                {
                    var divergence = _repo.ObjectDatabase.CalculateHistoryDivergence(head.Tip, head.TrackedBranch.Tip);
                    int ahead = divergence.AheadBy ?? 0;
                    int behind = divergence.BehindBy ?? 0;
                    AheadBehindText.Text = $"↑{ahead} ↓{behind}";
                }
                else
                {
                    AheadBehindText.Text = "local only";
                }
            }
            catch { AheadBehindText.Text = ""; }
        }

        private string GetTimeAgo(DateTimeOffset when)
        {
            var diff = DateTimeOffset.Now - when;
            if (diff.TotalMinutes < 1) return "just now";
            if (diff.TotalMinutes < 60) return $"{(int)diff.TotalMinutes}m ago";
            if (diff.TotalHours < 24) return $"{(int)diff.TotalHours}h ago";
            if (diff.TotalDays < 30) return $"{(int)diff.TotalDays}d ago";
            if (diff.TotalDays < 365) return $"{(int)(diff.TotalDays / 30)}mo ago";
            return $"{(int)(diff.TotalDays / 365)}y ago";
        }

        // ── Event Handlers ──────────────────────────────────────────

        private void OpenRepo_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new System.Windows.Forms.FolderBrowserDialog
            {
                Description = "Select a Git repository folder",
                ShowNewFolderButton = false
            };
            if (dlg.ShowDialog() == System.Windows.Forms.DialogResult.OK)
            {
                string path = dlg.SelectedPath;
                string repoRoot = Repository.Discover(path) ?? "";
                if (!string.IsNullOrEmpty(repoRoot))
                    _ = OpenRepoAsync(repoRoot);
                else
                    MessageBox.Show("No Git repository found at that location.", "Not a repo");
            }
        }

        internal async void CloneRepo_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new CloneDialog();
            if (dlg.ShowDialog() == true && !string.IsNullOrWhiteSpace(dlg.RepoUrl) && !string.IsNullOrWhiteSpace(dlg.TargetPath))
            {
                try
                {
                    SetProgress(true, $"Cloning {dlg.RepoUrl}...");
                    SetStatus($"Cloning {dlg.RepoUrl}...");
                    
                    string url = dlg.RepoUrl;
                    string target = dlg.TargetPath;
                    
                    await Task.Run(() =>
                    {
                        var cloneOptions = new CloneOptions();
                        cloneOptions.FetchOptions.OnTransferProgress = progress =>
                        {
                            Dispatcher.Invoke(() =>
                            {
                                double percent = progress.TotalObjects > 0
                                    ? (progress.ReceivedObjects * 100.0 / progress.TotalObjects)
                                    : 0;
                                SetStatus($"Cloning: {percent:F0}% ({progress.ReceivedObjects}/{progress.TotalObjects} objects)");
                            });
                            return true;
                        };
                        Repository.Clone(url, target, cloneOptions);
                    });
                    
                    await OpenRepoAsync(target);
                    SetStatus("Clone complete.");
                }
                catch (Exception ex)
                {
                    ErrorHandler.Handle(ex, $"Cloning repository: {dlg.RepoUrl}");
                    SetStatus("Clone failed.");
                }
                finally
                {
                    SetProgress(false);
                }
            }
        }

        internal async void InitRepo_Click(object sender, RoutedEventArgs e)
        {
            var dlg = new System.Windows.Forms.FolderBrowserDialog
            {
                Description = "Select folder to initialize as Git repo",
                ShowNewFolderButton = true
            };
            if (dlg.ShowDialog() == System.Windows.Forms.DialogResult.OK)
            {
                try
                {
                    await Task.Run(() => Repository.Init(dlg.SelectedPath));
                    await OpenRepoAsync(dlg.SelectedPath);
                    SetStatus("Repository initialized.");
                }
                catch (Exception ex)
                {
                    ErrorHandler.Handle(ex, $"Initializing repository: {dlg.SelectedPath}");
                }
            }
        }

        private async void Fetch_Click(object sender, RoutedEventArgs e)
        {
            if (_repoPath == null || _repo == null) return;
            try
            {
                SetProgress(true, "Fetching from remote...");
                SetStatus("Fetching...");
                
                await Task.Run(() =>
                {
                    foreach (var remote in _repo.Network.Remotes)
                    {
                        var refSpecs = remote.FetchRefSpecs.Select(x => x.Specification);
                        Commands.Fetch(_repo, remote.Name, refSpecs, new FetchOptions
                        {
                            OnTransferProgress = progress =>
                            {
                                Dispatcher.Invoke(() =>
                                {
                                    SetStatus($"Fetching: {progress.ReceivedObjects}/{progress.TotalObjects} objects");
                                });
                                return true;
                            }
                        }, "");
                    }
                });
                
                await RefreshAllAsync();
                SetStatus("Fetch complete.");
            }
            catch (Exception ex)
            {
                ErrorHandler.Handle(ex, "Fetching from remote");
                SetStatus("Fetch failed.");
            }
            finally
            {
                SetProgress(false);
            }
        }

        private async void Pull_Click(object sender, RoutedEventArgs e)
        {
            if (_repoPath == null || _repo == null) return;
            try
            {
                SetProgress(true, "Pulling from remote...");
                SetStatus("Pulling...");
                
                await Task.Run(() =>
                {
                    var signature = _repo.Config.BuildSignature(DateTimeOffset.Now);
                    Commands.Pull(_repo, signature, new PullOptions
                    {
                        FetchOptions = new FetchOptions
                        {
                            OnTransferProgress = progress =>
                            {
                                Dispatcher.Invoke(() =>
                                {
                                    SetStatus($"Pulling: {progress.ReceivedObjects}/{progress.TotalObjects} objects");
                                });
                                return true;
                            }
                        }
                    });
                });
                
                await RefreshAllAsync();
                SetStatus("Pull complete.");
            }
            catch (Exception ex)
            {
                ErrorHandler.Handle(ex, "Pulling from remote");
                SetStatus("Pull failed.");
            }
            finally
            {
                SetProgress(false);
            }
        }

        private async void Push_Click(object sender, RoutedEventArgs e)
        {
            if (_repoPath == null || _repo == null) return;
            try
            {
                SetProgress(true, "Pushing to remote...");
                SetStatus("Pushing...");
                
                await Task.Run(() =>
                {
                    var branch = _repo.Head;
                    if (branch.TrackedBranch != null)
                    {
                        _repo.Network.Push(branch, new PushOptions
                        {
                            OnPushTransferProgress = (current, total, bytes) =>
                            {
                                Dispatcher.Invoke(() =>
                                {
                                    SetStatus($"Pushing: {current}/{total} objects");
                                });
                                return true;
                            }
                        });
                    }
                    else
                    {
                        throw new Exception("No tracking branch configured. Use 'git push --set-upstream' manually.");
                    }
                });
                
                await RefreshAllAsync();
                SetStatus("Push complete.");
            }
            catch (Exception ex)
            {
                ErrorHandler.Handle(ex, "Pushing to remote");
                SetStatus("Push failed.");
            }
            finally
            {
                SetProgress(false);
            }
        }

        private async void Commit_Click(object sender, RoutedEventArgs e)
        {
            if (_repo == null) return;
            string summary = CommitSummary.Text.Trim();
            if (string.IsNullOrEmpty(summary))
            {
                MessageBox.Show("Commit summary is required.", "Missing summary");
                return;
            }

            try
            {
                SetProgress(true, "Committing changes...");
                
                await Task.Run(() =>
                {
                    // Stage all changes
                    Commands.Stage(_repo, "*");
                    string message = summary;
                    if (!string.IsNullOrWhiteSpace(CommitDescription.Text))
                        message += "\n\n" + CommitDescription.Text.Trim();

                    var sig = _repo.Config.BuildSignature(DateTimeOffset.Now);
                    var options = new CommitOptions();
                    if (Dispatcher.Invoke(() => AmendCheck.IsChecked == true))
                        options.AmendPreviousCommit = true;
                    _repo.Commit(message, sig, sig, options);
                });

                await Dispatcher.InvokeAsync(() =>
                {
                    CommitSummary.Text = "";
                    CommitDescription.Text = "";
                });
                
                await RefreshAllAsync();
                SetStatus($"Committed: {summary}");
            }
            catch (Exception ex)
            {
                ErrorHandler.Handle(ex, "Committing changes");
            }
            finally
            {
                SetProgress(false);
            }
        }

        private async void BranchCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (_repo == null || BranchCombo.SelectedItem == null || _isRefreshing) return;
            string name = BranchCombo.SelectedItem.ToString()!;
            var branch = _repo.Branches[name];
            if (branch != null && !branch.IsCurrentRepositoryHead)
            {
                try
                {
                    SetProgress(true, $"Checking out {name}...");
                    await Task.Run(() => Commands.Checkout(_repo, branch));
                    await RefreshAllAsync();
                    SetStatus($"Switched to {name}");
                }
                catch (Exception ex)
                {
                    SetStatus($"Checkout failed: {ex.Message}");
                }
                finally
                {
                    SetProgress(false);
                }
            }
        }

        private async void NewBranch_Click(object sender, RoutedEventArgs e)
        {
            if (_repo == null) return;
            var dlg = new InputDialog("New Branch", "Branch name:");
            if (dlg.ShowDialog() == true && !string.IsNullOrWhiteSpace(dlg.InputText))
            {
                try
                {
                    SetProgress(true, "Creating branch...");
                    await Task.Run(() =>
                    {
                        var branch = _repo.CreateBranch(dlg.InputText);
                        Commands.Checkout(_repo, branch);
                    });
                    await RefreshAllAsync();
                    SetStatus($"Created and switched to {dlg.InputText}");
                }
                catch (Exception ex)
                {
                    ErrorHandler.Handle(ex, $"Creating branch: {dlg.InputText}");
                }
                finally
                {
                    SetProgress(false);
                }
            }
        }

        private async void BranchList_DoubleClick(object sender, System.Windows.Input.MouseButtonEventArgs e)
        {
            if (_repo == null || BranchList.SelectedItem is not BranchInfo bi) return;
            try
            {
                SetProgress(true, $"Checking out {bi.Name}...");
                await Task.Run(() =>
                {
                    var branch = _repo.Branches[bi.Name];
                    if (branch != null)
                        Commands.Checkout(_repo, branch);
                });
                await RefreshAllAsync();
                SetStatus($"Switched to {bi.Name}");
            }
            catch (Exception ex) { SetStatus($"Checkout failed: {ex.Message}"); }
            finally { SetProgress(false); }
        }

        private void ChangedFilesList_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (_repo == null || ChangedFilesList.SelectedItem is not FileChange fc) return;
            _ = ShowDiffAsync(fc);
        }

        private async Task ShowDiffAsync(FileChange fc)
        {
            DiffFileHeader.Text = fc.FilePath;
            SetProgress(true, "Loading diff...");
            
            try
            {
                string diffText = await Task.Run(() =>
                {
                    string result = RunGit($"diff -- \"{fc.FilePath}\"");
                    if (string.IsNullOrWhiteSpace(result))
                        result = RunGit($"diff --cached -- \"{fc.FilePath}\"");
                    if (string.IsNullOrWhiteSpace(result))
                    {
                        // New untracked file — show content
                        string fullPath = Path.Combine(_repoPath!, fc.FilePath);
                        if (File.Exists(fullPath))
                        {
                            var lines = File.ReadAllLines(fullPath);
                            if (lines.Length > 5000)
                                result = $"(file too large: {lines.Length} lines)\n" + string.Join("\n", lines.Take(1000));
                            else
                                result = "+ " + string.Join("\n+ ", lines);
                        }
                        else
                            result = "(file not found)";
                    }
                    return result;
                });

                await Dispatcher.InvokeAsync(() =>
                {
                    DiffView.Document = DiffHighlighter.CreateDiffDocument(diffText, Resources);
                });
            }
            catch (Exception ex)
            {
                await Dispatcher.InvokeAsync(() =>
                {
                    DiffView.Document = DiffHighlighter.CreateErrorDocument($"Failed to load diff: {ex.Message}", Resources);
                });
                ErrorHandler.Handle(ex, $"Loading diff for {fc.FilePath}", showDialog: false);
            }
            finally
            {
                SetProgress(false);
            }
        }

        private void HistoryList_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (_repo == null || HistoryList.SelectedItem is not CommitInfo ci) return;
            _ = ShowCommitDiffAsync(ci);
        }

        private async Task ShowCommitDiffAsync(CommitInfo ci)
        {
            DiffFileHeader.Text = $"{ci.Sha[..8]} — {ci.MessageShort}";
            SetProgress(true, "Loading commit diff...");
            
            try
            {
                string diffText = await RunGitAsync($"show --stat --format=\"Author: %an <%ae>%nDate: %ai%n%n%B\" {ci.Sha}");

                await Dispatcher.InvokeAsync(() =>
                {
                    DiffView.Document = DiffHighlighter.CreateCommitDocument(diffText, Resources);
                });
            }
            catch (Exception ex)
            {
                await Dispatcher.InvokeAsync(() =>
                {
                    DiffView.Document = DiffHighlighter.CreateErrorDocument($"Failed to load commit: {ex.Message}", Resources);
                });
                ErrorHandler.Handle(ex, $"Loading commit {ci.Sha}", showDialog: false);
            }
            finally
            {
                SetProgress(false);
            }
        }

        private async void StageFile_Click(object sender, RoutedEventArgs e)
        {
            if (_repo == null || ChangedFilesList.SelectedItem is not FileChange fc) return;
            await Task.Run(() => Commands.Stage(_repo, fc.FilePath));
            await RefreshChangesAsync();
            SetStatus($"Staged: {fc.FileName}");
        }

        private async void DiscardChanges_Click(object sender, RoutedEventArgs e)
        {
            if (_repo == null || ChangedFilesList.SelectedItem is not FileChange fc) return;
            var result = MessageBox.Show($"Discard all changes to {fc.FileName}?", "Confirm Discard",
                MessageBoxButton.YesNo, MessageBoxImage.Warning);
            if (result == MessageBoxResult.Yes)
            {
                await RunGitAsync($"checkout -- \"{fc.FilePath}\"");
                await RefreshChangesAsync();
                SetStatus($"Discarded: {fc.FileName}");
            }
        }

        private async void StashSave_Click(object sender, RoutedEventArgs e)
        {
            if (_repoPath == null) return;
            SetProgress(true, "Stashing changes...");
            await RunGitAsync("stash push -m \"GitDesk stash\"");
            await RefreshAllAsync();
            SetStatus("Changes stashed.");
            SetProgress(false);
        }

        private async void StashPop_Click(object sender, RoutedEventArgs e)
        {
            if (_repoPath == null) return;
            SetProgress(true, "Applying stash...");
            await RunGitAsync("stash pop");
            await RefreshAllAsync();
            SetStatus("Stash popped.");
            SetProgress(false);
        }

        private async void Merge_Click(object sender, RoutedEventArgs e)
        {
            if (_repo == null) return;
            var branchNames = _repo.Branches.Where(b => !b.IsRemote).Select(b => b.FriendlyName);
            var dlg = new MergeDialog(_repo.Head.FriendlyName, branchNames);
            if (dlg.ShowDialog() == true && dlg.SelectedBranch != null)
            {
                try
                {
                    SetProgress(true, $"Merging {dlg.SelectedBranch}...");
                    SetStatus($"Merging {dlg.SelectedBranch}...");
                    
                    await Task.Run(() =>
                    {
                        if (dlg.Squash)
                        {
                            RunGit($"merge --squash {dlg.SelectedBranch}");
                        }
                        else
                        {
                            var branch = _repo.Branches[dlg.SelectedBranch];
                            if (branch != null)
                            {
                                var sig = _repo.Config.BuildSignature(DateTimeOffset.Now);
                                _repo.Merge(branch, sig);
                            }
                        }
                    });
                    
                    await RefreshAllAsync();
                    SetStatus($"Merged {dlg.SelectedBranch} into {_repo.Head.FriendlyName}");
                }
                catch (Exception ex)
                {
                    ErrorHandler.Handle(ex, $"Merging branch: {dlg.SelectedBranch}");
                    SetStatus("Merge failed.");
                }
                finally
                {
                    SetProgress(false);
                }
            }
        }

        private async void NewTag_Click(object sender, RoutedEventArgs e)
        {
            if (_repo == null) return;
            var dlg = new InputDialog("New Tag", "Tag name:");
            if (dlg.ShowDialog() == true && !string.IsNullOrWhiteSpace(dlg.InputText))
            {
                try
                {
                    await Task.Run(() => _repo.ApplyTag(dlg.InputText));
                    await RefreshTagsAsync();
                    SetStatus($"Tag created: {dlg.InputText}");
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Failed:\n{ex.Message}", "Error");
                }
            }
        }

        private async void AddRemote_Click(object sender, RoutedEventArgs e)
        {
            if (_repo == null) return;
            var nameDlg = new InputDialog("Add Remote", "Remote name (e.g. origin):");
            if (nameDlg.ShowDialog() == true && !string.IsNullOrWhiteSpace(nameDlg.InputText))
            {
                var urlDlg = new InputDialog("Add Remote", "Remote URL:");
                if (urlDlg.ShowDialog() == true && !string.IsNullOrWhiteSpace(urlDlg.InputText))
                {
                    string name = nameDlg.InputText;
                    string url = urlDlg.InputText;
                    try
                    {
                        await Task.Run(() => _repo.Network.Remotes.Add(name, url));
                        await RefreshRemotesAsync();
                        SetStatus($"Remote added: {name}");
                    }
                    catch (Exception ex)
                    {
                        ErrorHandler.Handle(ex, $"Adding remote: {name}");
                    }
                }
            }
        }

        private async void BranchCheckout_Click(object sender, RoutedEventArgs e)
        {
            if (_repo == null || BranchList.SelectedItem is not BranchInfo bi) return;
            try
            {
                SetProgress(true, $"Checking out {bi.Name}...");
                await Task.Run(() =>
                {
                    var branch = _repo.Branches[bi.Name];
                    if (branch != null)
                        Commands.Checkout(_repo, branch);
                });
                await RefreshAllAsync();
                SetStatus($"Switched to {bi.Name}");
            }
            catch (Exception ex) { SetStatus($"Failed: {ex.Message}"); }
            finally { SetProgress(false); }
        }

        private async void BranchRename_Click(object sender, RoutedEventArgs e)
        {
            if (_repo == null || BranchList.SelectedItem is not BranchInfo bi) return;
            var dlg = new InputDialog("Rename Branch", $"New name for '{bi.Name}':");
            if (dlg.ShowDialog() == true && !string.IsNullOrWhiteSpace(dlg.InputText))
            {
                await RunGitAsync($"branch -m {bi.Name} {dlg.InputText}");
                await RefreshAllAsync();
                SetStatus($"Renamed {bi.Name} to {dlg.InputText}");
            }
        }

        private async void BranchDelete_Click(object sender, RoutedEventArgs e)
        {
            if (_repo == null || BranchList.SelectedItem is not BranchInfo bi) return;
            if (bi.IsHead) { MessageBox.Show("Cannot delete the current branch.", "Error"); return; }
            var result = MessageBox.Show($"Delete branch '{bi.Name}'?", "Delete Branch",
                MessageBoxButton.YesNo, MessageBoxImage.Warning);
            if (result == MessageBoxResult.Yes)
            {
                try
                {
                    await Task.Run(() => _repo.Branches.Remove(bi.Name));
                    await RefreshAllAsync();
                    SetStatus($"Deleted branch: {bi.Name}");
                }
                catch (Exception ex) { ErrorHandler.Handle(ex, $"Deleting branch: {bi.Name}"); }
            }
        }

        private void OpenInExplorer_Click(object sender, RoutedEventArgs e)
        {
            if (_repoPath == null) return;
            Process.Start("explorer.exe", _repoPath);
        }

        private void OpenTerminal_Click(object sender, RoutedEventArgs e)
        {
            if (_repoPath == null) return;
            try
            {
                Process.Start(new ProcessStartInfo("wt", $"-d \"{_repoPath}\"") { UseShellExecute = true });
            }
            catch
            {
                // Fallback to cmd if Windows Terminal not installed
                Process.Start(new ProcessStartInfo("cmd", $"/k cd /d \"{_repoPath}\"") { UseShellExecute = true });
            }
        }

        private void BlameFile_Click(object sender, RoutedEventArgs e)
        {
            if (_repo == null || ChangedFilesList.SelectedItem is not FileChange fc) return;
            _ = Task.Run(async () =>
            {
                string blameText = await RunGitAsync($"blame -- \"{fc.FilePath}\"");
                await Dispatcher.InvokeAsync(() => ShowTextInDiff($"Blame: {fc.FilePath}", blameText, Brushes.CornflowerBlue));
            });
        }

        private void OpenFileInExplorer_Click(object sender, RoutedEventArgs e)
        {
            if (_repoPath == null || ChangedFilesList.SelectedItem is not FileChange fc) return;
            string fullPath = Path.Combine(_repoPath, fc.FilePath);
            if (File.Exists(fullPath))
                Process.Start("explorer.exe", $"/select,\"{fullPath}\"");
        }

        private async void CherryPick_Click(object sender, RoutedEventArgs e)
        {
            if (_repo == null || HistoryList.SelectedItem is not CommitInfo ci) return;
            var result = MessageBox.Show($"Cherry-pick commit {ci.Sha[..8]}?\n{ci.MessageShort}", "Cherry-pick",
                MessageBoxButton.YesNo, MessageBoxImage.Question);
            if (result == MessageBoxResult.Yes)
            {
                try
                {
                    SetProgress(true, "Cherry-picking...");
                    await Task.Run(() =>
                    {
                        var commit = _repo.Lookup<Commit>(ci.Sha);
                        if (commit != null)
                            _repo.CherryPick(commit, commit.Author);
                    });
                    await RefreshAllAsync();
                    SetStatus($"Cherry-picked: {ci.MessageShort}");
                }
                catch (Exception ex) { ErrorHandler.Handle(ex, $"Cherry-picking commit: {ci.Sha[..8]}"); }
                finally { SetProgress(false); }
            }
        }

        private async void Revert_Click(object sender, RoutedEventArgs e)
        {
            if (_repo == null || HistoryList.SelectedItem is not CommitInfo ci) return;
            var result = MessageBox.Show($"Revert commit {ci.Sha[..8]}?\n{ci.MessageShort}", "Revert",
                MessageBoxButton.YesNo, MessageBoxImage.Question);
            if (result == MessageBoxResult.Yes)
            {
                try
                {
                    SetProgress(true, "Reverting...");
                    await Task.Run(() =>
                    {
                        var commit = _repo.Lookup<Commit>(ci.Sha);
                        if (commit != null)
                            _repo.Revert(commit, commit.Author);
                    });
                    await RefreshAllAsync();
                    SetStatus($"Reverted: {ci.MessageShort}");
                }
                catch (Exception ex) { ErrorHandler.Handle(ex, $"Reverting commit: {ci.Sha[..8]}"); }
                finally { SetProgress(false); }
            }
        }

        private void CopySha_Click(object sender, RoutedEventArgs e)
        {
            if (HistoryList.SelectedItem is not CommitInfo ci) return;
            Clipboard.SetText(ci.Sha);
            SetStatus($"Copied: {ci.Sha}");
        }

        private void ShowHelp()
        {
            var help = new HelpWindow();
            help.ShowDialog();
        }

        private void ShowTextInDiff(string header, string text, Brush defaultColor)
        {
            DiffFileHeader.Text = header;
            
            // Use BlameDocument for blame operations
            if (header.StartsWith("Blame:"))
            {
                DiffView.Document = DiffHighlighter.CreateBlameDocument(text, Resources);
            }
            else
            {
                // Generic text display
                var doc = new FlowDocument
                {
                    Background = (SolidColorBrush)FindResource("BgDarkBrush"),
                    FontFamily = new FontFamily("Cascadia Code,Cascadia Mono,Consolas,Courier New"),
                    FontSize = 13,
                    PagePadding = new Thickness(0)
                };
                foreach (var line in text.Split('\n'))
                {
                    var para = new Paragraph(new Run(line))
                    {
                        Margin = new Thickness(0),
                        Padding = new Thickness(12, 2, 12, 2),
                        Foreground = defaultColor
                    };
                    doc.Blocks.Add(para);
                }
                DiffView.Document = doc;
            }
        }

        private void SearchBox_TextChanged(object sender, TextChangedEventArgs e)
        {
            // Filter changed files by search text
            if (_repo == null) return;
            string query = SearchBox.Text.Trim().ToLower();
            if (string.IsNullOrEmpty(query))
            {
                ChangedFilesList.ItemsSource = _changedFiles;
                return;
            }
            // Simple filter on existing items
            var filtered = _changedFiles.Where(f => f.FilePath.ToLower().Contains(query)).ToList();
            ChangedFilesList.ItemsSource = filtered;
        }

        private void SetupFileWatcher(string repoPath)
        {
            _watcher?.Dispose();
            _refreshTimer?.Stop();

            _refreshTimer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(1000) };
            _refreshTimer.Tick += (s, e) =>
            {
                _refreshTimer.Stop();
                try { _ = RefreshChangesAsync(); } catch { }
            };

            try
            {
                _watcher = new FileSystemWatcher(repoPath)
                {
                    IncludeSubdirectories = true,
                    NotifyFilter = NotifyFilters.FileName | NotifyFilters.LastWrite | NotifyFilters.DirectoryName,
                    EnableRaisingEvents = true
                };
                
                FileSystemEventHandler handler = (s, ev) =>
                {
                    if (!ev.FullPath.Contains(".git") && !ev.FullPath.Contains("node_modules"))
                        Dispatcher.Invoke(() => _refreshTimer.Start());
                };
                
                _watcher.Changed += handler;
                _watcher.Created += handler;
                _watcher.Deleted += handler;
                _watcher.Renamed += (s, ev) =>
                {
                    if (!ev.FullPath.Contains(".git") && !ev.FullPath.Contains("node_modules"))
                        Dispatcher.Invoke(() => _refreshTimer.Start());
                };
            }
            catch { }
        }

        protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
        {
            // Save window state
            RepoManager.SaveWindowState(
                WindowState == WindowState.Maximized ? RestoreBounds.Width : Width,
                WindowState == WindowState.Maximized ? RestoreBounds.Height : Height,
                WindowState == WindowState.Maximized);
            base.OnClosing(e);
        }

        protected override void OnClosed(EventArgs e)
        {
            _watcher?.Dispose();
            _refreshTimer?.Stop();
            _repo?.Dispose();
            base.OnClosed(e);
        }
    }

    // ── Models ──────────────────────────────────────────────────

    public class FileChange
    {
        public string FilePath { get; set; } = "";
        public string FileName { get; set; } = "";
        public FileStatus State { get; set; }
        public string StatusIcon { get; set; } = "⚪";
    }

    public class CommitInfo
    {
        public string Sha { get; set; } = "";
        public string MessageShort { get; set; } = "";
        public string AuthorName { get; set; } = "";
        public string AuthorEmail { get; set; } = "";
        public DateTimeOffset When { get; set; }
        public string TimeAgo { get; set; } = "";
    }

    public class BranchInfo
    {
        public string Name { get; set; } = "";
        public bool IsHead { get; set; }
    }

    public class RemoteInfo
    {
        public string Name { get; set; } = "";
        public string Url { get; set; } = "";
    }

    public class RelayCommand : System.Windows.Input.ICommand
    {
        private readonly Action<object?> _execute;
        public RelayCommand(Action<object?> execute) { _execute = execute; }
        public event EventHandler? CanExecuteChanged;
        public bool CanExecute(object? parameter) => true;
        public void Execute(object? parameter) => _execute(parameter);
    }
}
