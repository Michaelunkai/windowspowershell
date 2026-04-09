using System;
using System.Linq;
using System.Windows;
using System.Windows.Documents;
using System.Windows.Media;

namespace GitDesk
{
    /// <summary>
    /// Professional diff syntax highlighting with proper color coding.
    /// Provides GitHub-style diff rendering for optimal readability.
    /// </summary>
    public static class DiffHighlighter
    {
        public static FlowDocument CreateDiffDocument(string diffText, ResourceDictionary resources)
        {
            var doc = new FlowDocument
            {
                Background = (SolidColorBrush)resources["BgDarkBrush"],
                FontFamily = new FontFamily("Cascadia Code,Cascadia Mono,Consolas,Courier New"),
                FontSize = 13,
                PagePadding = new Thickness(0),
                LineHeight = 1.4
            };

            if (string.IsNullOrWhiteSpace(diffText))
            {
                doc.Blocks.Add(CreateParagraph("(No changes to display)", 
                    (SolidColorBrush)resources["TextSecondaryBrush"]));
                return doc;
            }

            var lines = diffText.Split('\n');
            
            // Truncate if too large
            if (lines.Length > 15000)
            {
                doc.Blocks.Add(CreateParagraph($"⚠ Large diff: showing first 15000 of {lines.Length} lines", 
                    (SolidColorBrush)resources["AccentOrangeBrush"], fontWeight: FontWeights.SemiBold));
                lines = lines.Take(15000).ToArray();
            }

            foreach (var line in lines)
            {
                var para = CreateDiffLine(line, resources);
                doc.Blocks.Add(para);
            }

            return doc;
        }

        private static Paragraph CreateDiffLine(string line, ResourceDictionary resources)
        {
            var para = new Paragraph 
            { 
                Margin = new Thickness(0), 
                Padding = new Thickness(12, 2, 12, 2) 
            };

            // Additions (green)
            if (line.StartsWith('+') && !line.StartsWith("+++"))
            {
                para.Background = new SolidColorBrush(Color.FromArgb(25, 63, 185, 80));
                para.Foreground = new SolidColorBrush(Color.FromRgb(63, 185, 80));
                para.Inlines.Add(new Run(line));
            }
            // Deletions (red)
            else if (line.StartsWith('-') && !line.StartsWith("---"))
            {
                para.Background = new SolidColorBrush(Color.FromArgb(25, 248, 81, 73));
                para.Foreground = new SolidColorBrush(Color.FromRgb(248, 81, 73));
                para.Inlines.Add(new Run(line));
            }
            // Hunk headers (purple/blue)
            else if (line.StartsWith("@@"))
            {
                para.Background = new SolidColorBrush(Color.FromArgb(15, 139, 148, 250));
                para.Foreground = new SolidColorBrush(Color.FromRgb(139, 148, 250));
                para.FontWeight = FontWeights.SemiBold;
                para.Inlines.Add(new Run(line));
            }
            // File headers (bold blue)
            else if (line.StartsWith("diff --git") || line.StartsWith("index ") || 
                     line.StartsWith("---") || line.StartsWith("+++"))
            {
                para.Foreground = (SolidColorBrush)resources["AccentBlueBrush"];
                para.FontWeight = FontWeights.SemiBold;
                para.Inlines.Add(new Run(line));
            }
            // Context lines
            else
            {
                para.Foreground = (SolidColorBrush)resources["TextSecondaryBrush"];
                para.Inlines.Add(new Run(line));
            }

            return para;
        }

        public static FlowDocument CreateCommitDocument(string commitText, ResourceDictionary resources)
        {
            var doc = new FlowDocument
            {
                Background = (SolidColorBrush)resources["BgDarkBrush"],
                FontFamily = new FontFamily("Cascadia Code,Cascadia Mono,Consolas,Courier New"),
                FontSize = 13,
                PagePadding = new Thickness(0),
                LineHeight = 1.4
            };

            if (string.IsNullOrWhiteSpace(commitText))
            {
                doc.Blocks.Add(CreateParagraph("(No commit data)", 
                    (SolidColorBrush)resources["TextSecondaryBrush"]));
                return doc;
            }

            var lines = commitText.Split('\n');

            foreach (var line in lines)
            {
                Paragraph para;

                if (line.StartsWith("Author:") || line.StartsWith("Date:"))
                {
                    para = CreateParagraph(line, (SolidColorBrush)resources["AccentBlueBrush"], 
                        fontWeight: FontWeights.SemiBold);
                }
                else if (line.Contains("insertion") || line.Contains("deletion") || 
                         line.Contains("changed") || line.Contains("file"))
                {
                    para = CreateParagraph(line, (SolidColorBrush)resources["AccentGreenBrush"]);
                }
                else if (line.TrimStart().StartsWith('+'))
                {
                    para = CreateParagraph(line, (SolidColorBrush)resources["AccentGreenBrush"]);
                }
                else if (line.TrimStart().StartsWith('-'))
                {
                    para = CreateParagraph(line, (SolidColorBrush)resources["AccentRedBrush"]);
                }
                else
                {
                    para = CreateParagraph(line, (SolidColorBrush)resources["TextPrimaryBrush"]);
                }

                doc.Blocks.Add(para);
            }

            return doc;
        }

        public static FlowDocument CreateBlameDocument(string blameText, ResourceDictionary resources)
        {
            var doc = new FlowDocument
            {
                Background = (SolidColorBrush)resources["BgDarkBrush"],
                FontFamily = new FontFamily("Cascadia Code,Cascadia Mono,Consolas,Courier New"),
                FontSize = 12,
                PagePadding = new Thickness(0),
                LineHeight = 1.3
            };

            if (string.IsNullOrWhiteSpace(blameText))
            {
                doc.Blocks.Add(CreateParagraph("(No blame data)", 
                    (SolidColorBrush)resources["TextSecondaryBrush"]));
                return doc;
            }

            var lines = blameText.Split('\n').Take(10000).ToArray();

            foreach (var line in lines)
            {
                var para = CreateParagraph(line, (SolidColorBrush)resources["TextSecondaryBrush"]);
                
                // Highlight SHA at start
                if (line.Length > 8)
                {
                    para.Inlines.Clear();
                    var shaRun = new Run(line[..8]) 
                    { 
                        Foreground = (SolidColorBrush)resources["AccentBlueBrush"],
                        FontWeight = FontWeights.SemiBold
                    };
                    var restRun = new Run(line[8..])
                    {
                        Foreground = (SolidColorBrush)resources["TextPrimaryBrush"]
                    };
                    para.Inlines.Add(shaRun);
                    para.Inlines.Add(restRun);
                }

                doc.Blocks.Add(para);
            }

            return doc;
        }

        public static FlowDocument CreateErrorDocument(string errorMessage, ResourceDictionary resources)
        {
            var doc = new FlowDocument
            {
                Background = (SolidColorBrush)resources["BgDarkBrush"],
                FontFamily = new FontFamily("Segoe UI,Arial"),
                FontSize = 13,
                PagePadding = new Thickness(16)
            };

            doc.Blocks.Add(CreateParagraph($"⚠ {errorMessage}", 
                (SolidColorBrush)resources["AccentRedBrush"], 
                fontWeight: FontWeights.SemiBold));

            return doc;
        }

        private static Paragraph CreateParagraph(string text, Brush foreground, 
            FontWeight? fontWeight = null, Thickness? margin = null)
        {
            var para = new Paragraph(new Run(text))
            {
                Foreground = foreground,
                Margin = margin ?? new Thickness(0),
                Padding = new Thickness(12, 2, 12, 2)
            };

            if (fontWeight.HasValue)
                para.FontWeight = fontWeight.Value;

            return para;
        }
    }
}
