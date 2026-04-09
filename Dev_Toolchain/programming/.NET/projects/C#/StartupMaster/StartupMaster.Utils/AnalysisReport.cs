using System.Collections.Generic;
using StartupMaster.Models;

namespace StartupMaster.Utils;

public class AnalysisReport
{
	public int TotalItems { get; set; }

	public int EnabledItems { get; set; }

	public int DisabledItems { get; set; }

	public int ImmediateStartItems { get; set; }

	public int DelayedItems { get; set; }

	public Dictionary<string, int> ByLocation { get; set; }

	public List<string> Recommendations { get; set; }

	public List<string> PotentialIssues { get; set; }

	public List<StartupItem> HighImpactItems { get; set; }
}

