using System;
using System.CodeDom.Compiler;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Markup;
using System.Windows.Media;
using StartupMaster.Models;
using StartupMaster.Utils;

namespace StartupMaster.Views;

public partial class StatisticsWindow : Window
{
	private readonly List<StartupItem> _items;

	private readonly StartupImpactCalculator _calculator;

	private readonly PerformanceAnalyzer _analyzer;

	
	
	
	
	
	
	
	
	
	
	
	public StatisticsWindow(List<StartupItem> items)
	{
		InitializeComponent();
		_items = items;
		_calculator = new StartupImpactCalculator();
		_analyzer = new PerformanceAnalyzer();
		LoadStatistics();
	}

	private void LoadStatistics()
	{
		TotalItemsText.Text = _items.Count.ToString();
		EnabledText.Text = _items.Count((StartupItem i) => i.IsEnabled).ToString();
		List<StartupItem> highImpactItems = _calculator.GetHighImpactItems(_items);
		HighImpactText.Text = highImpactItems.Count.ToString();
		int value = _calculator.EstimateBootTimeSeconds(_items);
		BootTimeText.Text = $"{value}s";
		(string, string, string) performanceRating = GetPerformanceRating(_items.Count((StartupItem i) => i.IsEnabled));
		RatingText.Text = performanceRating.Item1;
		RatingText.Foreground = new SolidColorBrush((Color)ColorConverter.ConvertFromString(performanceRating.Item2));
		RatingDescription.Text = performanceRating.Item3;
		List<string> itemsSource = (from i in _items
			group i by i.LocationDisplay into g
			select $"{g.Key}: {g.Count()} items ({g.Count((StartupItem i) => i.IsEnabled)} enabled)").ToList();
		LocationList.ItemsSource = itemsSource;
		AnalysisReport analysisReport = _analyzer.AnalyzeStartupItems(_items);
		RecommendationsList.ItemsSource = analysisReport.Recommendations;
		var itemsSource2 = highImpactItems.Select((StartupItem item) => new
		{
			Impact = $"{_calculator.GetImpactEmoji(_calculator.CalculateImpact(item))} {_calculator.CalculateImpact(item)}/10",
			Name = item.Name,
			Command = item.Command,
			Suggestion = _calculator.GetOptimizationSuggestion(item)
		}).ToList();
		HighImpactGrid.ItemsSource = itemsSource2;
		IssuesList.ItemsSource = analysisReport.PotentialIssues;
	}

	private (string rating, string color, string description) GetPerformanceRating(int enabledCount)
	{
		if (enabledCount <= 10)
		{
			return (rating: "Excellent", color: "#00CC00", description: "Your startup configuration is optimal. Boot times should be very fast.");
		}
		if (enabledCount <= 15)
		{
			return (rating: "Good", color: "#00AA00", description: "Decent configuration with room for minor improvements.");
		}
		if (enabledCount <= 20)
		{
			return (rating: "Fair", color: "#FFA500", description: "Above average item count. Consider optimizing further.");
		}
		return (rating: "Poor", color: "#FF0000", description: "Too many startup items. Significant optimization recommended.");
	}

	private void CloseButton_Click(object sender, RoutedEventArgs e)
	{
		Close();
	}

}


