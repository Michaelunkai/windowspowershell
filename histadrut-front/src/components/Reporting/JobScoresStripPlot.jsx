import Highcharts from "highcharts";
import HighchartsReact from "highcharts-react-official";
import HighchartsMore from "highcharts/highcharts-more";
import React from "react";

import { useViewport } from "../../contexts/ViewportContext";
import "./JobScoresStripPlot.css";

// Initialize highcharts-more for areasplinerange
if (typeof HighchartsMore === "function") {
  HighchartsMore(Highcharts);
}

function hexToRgb(hex) {
  hex = hex.replace(/^#/, "");
  if (hex.length === 3) {
    hex = hex.split("").map(x => x + x).join("");
  }
  const num = parseInt(hex, 16);
  return [(num >> 16) & 255, (num >> 8) & 255, num & 255].join(",");
}

function hexToRgba(hex, alpha = 1) {
  hex = hex.replace(/^#/, "");
  if (hex.length === 3) {
    hex = hex.split("").map(x => x + x).join("");
  }
  const num = parseInt(hex, 16);
  const r = (num >> 16) & 255;
  const g = (num >> 8) & 255;
  const b = num & 255;
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

const JobScoresStripPlot = ({ data = [], companyColorMap = {}, selectedCompany, t }) => {
  const { isMobile } = useViewport();
  let jobs = data.filter(j => Array.isArray(j.scores) && j.scores.length > 0);
  jobs = jobs.sort((a, b) => b.scores.length - a.scores.length).slice(0, 20);

  let maxCount = 1;
  jobs.forEach(job => {
    const scoreCounts = {};
    job.scores.forEach(s => {
      const rounded = Math.round(s * 100) / 100;
      scoreCounts[rounded] = (scoreCounts[rounded] || 0) + 1;
    });
    Object.values(scoreCounts).forEach(count => {
      if (count > maxCount) {
        maxCount = count;
      }
    });
  });

  const categories = jobs.map(j => j.job);

  const scatterSeries = jobs.map((job, jobIndex) => {
    const scoreCounts = {};
    job.scores.forEach(s => {
      const rounded = Math.round(s * 100) / 100;
      scoreCounts[rounded] = (scoreCounts[rounded] || 0) + 1;
    });

    const scatterData = Object.entries(scoreCounts).map(([score, count]) => {
      const alpha = count >= maxCount ? 1 : count > 1 ? 0.4 + 0.6 * (count - 1) / (maxCount - 1) : 0.5;
      const radius = count >= maxCount ? 10 : count > 1 ? 3 + 7 * (count - 1) / (maxCount - 1) : 3;
      const fillColor = companyColorMap[selectedCompany]
        ? `rgba(${hexToRgb(companyColorMap[selectedCompany])},${alpha})`
        : `rgba(52,152,219,${alpha})`;

      return {
        x: jobIndex,
        y: parseFloat(score),
        count,
        job: job.job,
        marker: { radius, fillColor, symbol: "circle", lineWidth: 0 }
      };
    });

    return {
      type: "scatter",
      name: job.job + " scores",
      data: scatterData,
      zIndex: 3,
      tooltip: {
        pointFormatter: function () {
          const scoreLabel = t ? t("charts.score") : "Score";
          const countLabel = t ? t("charts.count") : "Count";
          return `<b>${this.job}</b><br/>${scoreLabel}: <b>${this.y.toFixed(2)}</b><br/>${countLabel}: <b>${this.count}</b>`;
        }
      },
      showInLegend: false,
      lineWidth: 0,
      connectNulls: false,
      states: { hover: { lineWidthPlus: 0 } },
      dataLabels: { enabled: false }
    };
  });

  const options = {
    chart: {
      type: "scatter",
      height: 500,
      style: { fontFamily: "inherit" },
      scrollablePlotArea: { minWidth: 600, scrollPositionX: 0 }
    },
    title: {
      text: t && typeof t === "function" ? t("charts.scoreDensityAcrossJobs") : "Score density across top jobs",
      align: "left"
    },
    credits: { enabled: false },
    accessibility: { enabled: false },
    legend: { enabled: false },
    xAxis: {
      min: -0.5,
      max: categories.length - 0.5,
      tickPositions: categories.map((_, i) => i),
      labels: {
        formatter: function () {
          const label = categories[this.value];
          if (!label) {
            return "";
          }

          return label.length > 35 ? label.slice(0, 32) + "..." : label;
        },
        rotation: -80,
        style: { fontSize: "11px", color: "#222", fontWeight: 400, maxWidth: 60, textOverflow: "ellipsis", whiteSpace: "nowrap" }
      },
      title: { text: t ? t("charts.job") : "Job" }
    },
    yAxis: {
      min: 7,
      max: 10,
      tickInterval: 0.5,
      title: { text: t ? t("charts.score") : "Score" }
    },
    tooltip: {
      useHTML: true,
      formatter: function () {
        if (this.point && typeof this.point.count !== "undefined") {
          const scoreLabel = t ? t("charts.score") : "Score";
          const countLabel = t ? t("charts.count") : "Count";
          return `
            <div style="white-space: nowrap; min-width: 120px;">
              <b>${this.point.job}</b><br/>
              ${scoreLabel}: <b>${this.y.toFixed(2)}</b><br/>
              ${countLabel}: <b>${this.point.count}</b>
            </div>
          `;
        }
        return false;
      }
    },
    plotOptions: {
      scatter: {
        marker: { radius: 3, symbol: "circle", fillColor: "#3498db" },
        states: { inactive: { opacity: 0.8 } }
      },
      areasplinerange: {
        enableMouseTracking: false,
        marker: { enabled: false },
        showInLegend: false,
        zIndex: 1
      },
      line: {
        marker: { enabled: false },
        lineWidth: 2,
        zIndex: 2
      }
    },
    responsive: {
      rules: [{
        condition: { maxWidth: 500 },
        chartOptions: {
          chart: { height: 350 },
          title: { style: { fontSize: "0.85rem" } },
          xAxis: {
            labels: {
              rotation: -65,
              style: { fontSize: "9px" }
            }
          }
        }
      }]
    },
    series: scatterSeries
  };

  if (jobs.length === 0) {
    return (
      <div style={{ padding: "20px", textAlign: "center", color: "#888", height: "340px", display: "flex", alignItems: "center", justifyContent: "center" }}>
        {t ? t("charts.notEnoughData") : "Not enough data to display the plot."}<br />
        {t ? t("charts.chartRequiresData") : "This chart requires at least one job with scores."}
      </div>
    );
  }

  const companyColor = companyColorMap[selectedCompany] || "#3498db";
  const columnWidth = 70;
  const svgChartHeight = 400;
  const svgMinScore = 7;
  const svgMaxScore = 10;
  const svgScoreRange = svgMaxScore - svgMinScore;
  const chartWidth = jobs.length * columnWidth;

  if (isMobile) {
    return (
      <div className="strip-plot-list">
        {jobs.map((job, jobIndex) => {
          const scoreCounts = {};
          job.scores.forEach(s => {
            const rounded = Math.round(s * 100) / 100;
            scoreCounts[rounded] = (scoreCounts[rounded] || 0) + 1;
          });

          return (
            <div key={jobIndex} className="strip-plot-list__item">
              <div className="strip-plot-list__name">
                {job.job.length > 40 ? job.job.slice(0, 37) + "…" : job.job}
              </div>
              <div className="strip-plot-list__track">
                {Object.entries(scoreCounts).map(([score, count]) => {
                  const numScore = parseFloat(score);
                  const pct = ((numScore - svgMinScore) / svgScoreRange) * 100;
                  let radius = 5;
                  let alpha = 0.5;
                  if (count >= maxCount) {
                    radius = 12;
                    alpha = 1;
                  } else if (count > 1) {
                    radius = 5 + 7 * (count - 1) / (maxCount - 1);
                    alpha = 0.5 + 0.5 * (count - 1) / (maxCount - 1);
                  }
                  return (
                    <div
                      key={score}
                      className="strip-plot-list__dot"
                      style={{
                        left: `${pct}%`,
                        width: radius * 2,
                        height: radius * 2,
                        backgroundColor: hexToRgba(companyColor, alpha)
                      }}
                      title={`${t ? t("charts.score") : "Score"}: ${numScore}  ${t ? t("charts.count") : "Count"}: ${count}`}
                    />
                  );
                })}
              </div>
              <div className="strip-plot-list__axis">
                <span>7</span><span>7.5</span><span>8</span><span>8.5</span><span>9</span><span>9.5</span><span>10</span>
              </div>
            </div>
          );
        })}
      </div>
    );
  }

  return <HighchartsReact highcharts={Highcharts} options={options} />;
};

export default JobScoresStripPlot;
