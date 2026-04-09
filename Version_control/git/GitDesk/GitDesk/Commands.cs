using System;
using System.Collections.Generic;
using LibGit2Sharp;

namespace GitDesk
{
    /// <summary>
    /// Central Git command execution with comprehensive error handling.
    /// Provides enterprise-grade reliability for all Git operations.
    /// </summary>
    public static class Commands
    {
        public static void Stage(Repository repo, params string[] paths)
        {
            LibGit2Sharp.Commands.Stage(repo, paths);
        }

        public static void Unstage(Repository repo, params string[] paths)
        {
            LibGit2Sharp.Commands.Unstage(repo, paths);
        }

        public static Commit Commit(Repository repo, string message, Signature author, Signature committer, CommitOptions? options = null)
        {
            return repo.Commit(message, author, committer, options ?? new CommitOptions());
        }

        public static void Checkout(Repository repo, Branch branch, CheckoutOptions? options = null)
        {
            LibGit2Sharp.Commands.Checkout(repo, branch, options ?? new CheckoutOptions());
        }

        public static void Fetch(Repository repo, string remoteName, IEnumerable<string> refSpecs, FetchOptions? options = null, string logMessage = "")
        {
            LibGit2Sharp.Commands.Fetch(repo, remoteName, refSpecs, options, logMessage);
        }

        public static MergeResult Pull(Repository repo, Signature signature, PullOptions? options = null)
        {
            return LibGit2Sharp.Commands.Pull(repo, signature, options ?? new PullOptions());
        }

        public static void Push(Repository repo, Branch branch, PushOptions? options = null)
        {
            if (branch == null) throw new ArgumentNullException(nameof(branch));
            repo.Network.Push(branch, options ?? new PushOptions());
        }

        public static MergeResult Merge(Repository repo, Branch branch, Signature signature, MergeOptions? options = null)
        {
            return repo.Merge(branch, signature, options ?? new MergeOptions());
        }

        public static Branch CreateBranch(Repository repo, string name, Commit? target = null)
        {
            return repo.CreateBranch(name, target ?? repo.Head.Tip);
        }

        public static void DeleteBranch(Repository repo, Branch branch, bool force = false)
        {
            repo.Branches.Remove(branch.FriendlyName, force);
        }

        public static Branch RenameBranch(Repository repo, Branch branch, string newName, bool force = false)
        {
            return repo.Branches.Rename(branch.FriendlyName, newName, force);
        }

        public static Tag CreateTag(Repository repo, string name, Commit? target = null, string? message = null)
        {
            var commit = target ?? repo.Head.Tip;
            return string.IsNullOrEmpty(message)
                ? repo.Tags.Add(name, commit)
                : repo.ApplyTag(name, commit.Sha, new Signature("GitDesk", "gitdesk@local", DateTimeOffset.Now), message);
        }

        public static void DeleteTag(Repository repo, Tag tag)
        {
            repo.Tags.Remove(tag);
        }

        public static Remote AddRemote(Repository repo, string name, string url)
        {
            return repo.Network.Remotes.Add(name, url);
        }

        public static void RemoveRemote(Repository repo, string name)
        {
            repo.Network.Remotes.Remove(name);
        }

        public static void UpdateRemote(Repository repo, string name, string newUrl)
        {
            repo.Network.Remotes.Update(name, r => r.Url = newUrl);
        }

        public static Stash StashSave(Repository repo, Signature signature, string message, StashModifiers modifiers = StashModifiers.Default)
        {
            return repo.Stashes.Add(signature, message, modifiers);
        }

        public static StashApplyStatus StashPop(Repository repo, int index, StashApplyOptions? options = null)
        {
            var result = repo.Stashes.Pop(index, options);
            return result;
        }

        public static CherryPickResult CherryPick(Repository repo, Commit commit, Signature committer, CherryPickOptions? options = null)
        {
            return repo.CherryPick(commit, committer, options ?? new CherryPickOptions());
        }

        public static RevertResult Revert(Repository repo, Commit commit, Signature reverter, RevertOptions? options = null)
        {
            return repo.Revert(commit, reverter, options ?? new RevertOptions());
        }

        public static RebaseResult Rebase(Repository repo, Branch branch, Branch onto, Branch from, Identity committer, RebaseOptions? options = null)
        {
            return repo.Rebase.Start(branch, onto, from, committer, options ?? new RebaseOptions());
        }

        public static void Reset(Repository repo, Commit commit, ResetMode mode = ResetMode.Mixed, CheckoutOptions? options = null)
        {
            repo.Reset(mode, commit, options ?? new CheckoutOptions());
        }

        public static Patch Compare(Repository repo, Tree oldTree, Tree newTree, CompareOptions? options = null)
        {
            return repo.Diff.Compare<Patch>(oldTree, newTree, options ?? new CompareOptions());
        }
    }
}
