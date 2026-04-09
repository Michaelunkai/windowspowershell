namespace StartupManager;

public class StartupItem
{
    public string Name { get; set; } = "";
    public string Command { get; set; } = "";
    public bool IsEnabled { get; set; }
    public string Location { get; set; } = "Registry (Current User)";
}
