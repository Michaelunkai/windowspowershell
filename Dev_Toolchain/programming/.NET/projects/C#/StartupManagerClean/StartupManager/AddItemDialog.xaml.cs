using System.IO;
using System.Windows;
using OpenFileDialog = Microsoft.Win32.OpenFileDialog;
using MessageBox = System.Windows.MessageBox;

namespace StartupManager;

public partial class AddItemDialog : Window
{
    public string ItemName => NameBox.Text.Trim();
    public string ItemCommand => CommandBox.Text.Trim();

    public AddItemDialog()
    {
        InitializeComponent();
        
        // Auto-populate name when command path is pasted/changed
        CommandBox.TextChanged += (s, e) =>
        {
            if (!string.IsNullOrWhiteSpace(CommandBox.Text))
            {
                try
                {
                    var path = CommandBox.Text.Trim().Trim('"');
                    if (File.Exists(path) || path.EndsWith(".exe", StringComparison.OrdinalIgnoreCase))
                    {
                        NameBox.Text = Path.GetFileNameWithoutExtension(path);
                    }
                }
                catch { }
            }
        };
        
        // Focus command box on load so user can immediately paste
        Loaded += (s, e) => CommandBox.Focus();
    }

    private void Browse_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog
        {
            Filter = "Executable files (*.exe)|*.exe|All files (*.*)|*.*",
            Title = "Select Program"
        };

        if (dialog.ShowDialog() == true)
        {
            CommandBox.Text = dialog.FileName;
            if (string.IsNullOrWhiteSpace(NameBox.Text))
            {
                NameBox.Text = Path.GetFileNameWithoutExtension(dialog.FileName);
            }
        }
    }

    private void Add_Click(object sender, RoutedEventArgs e)
    {
        // Auto-fill name if empty but command is provided
        if (string.IsNullOrWhiteSpace(NameBox.Text) && !string.IsNullOrWhiteSpace(CommandBox.Text))
        {
            try
            {
                var path = CommandBox.Text.Trim().Trim('"');
                NameBox.Text = Path.GetFileNameWithoutExtension(path);
            }
            catch { }
        }

        if (string.IsNullOrWhiteSpace(ItemName))
        {
            MessageBox.Show("Please enter a command/path.", "Validation Error", MessageBoxButton.OK, MessageBoxImage.Warning);
            CommandBox.Focus();
            return;
        }

        if (string.IsNullOrWhiteSpace(ItemCommand))
        {
            MessageBox.Show("Please enter a command/path.", "Validation Error", MessageBoxButton.OK, MessageBoxImage.Warning);
            CommandBox.Focus();
            return;
        }

        DialogResult = true;
        Close();
    }

    private void Cancel_Click(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
        Close();
    }
}
