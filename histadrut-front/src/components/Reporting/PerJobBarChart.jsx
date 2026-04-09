import Highcharts from "highcharts";
import HighchartsReact from "highcharts-react-official";
import React from "react";
import { useNavigate } from "react-router-dom";

import { useViewport } from "../../contexts/ViewportContext";
import "./PerJobBarChart.css";

const sorters = [
  { label: "Company (A-Z)", fn: (a, b) => a.company.localeCompare(b.company) },
  { label: "Matches (High → Low)", fn: (a, b) => b.matches - a.matches }
];

const PerJobBarChart = ({
  data = [],
  sortIndex,
  minScore = 7.5,
  companyColorMap,
  t
}) => {
  const navigate = useNavigate();
  const { isMobile } = useViewport();

  const filteredData = data
    .map(job => {
      if (Array.isArray(job.candidates)) {
        const filteredCandidates = job.candidates.filter(c => c.score >= minScore);
        return { ...job, matches: filteredCandidates.length, candidates: filteredCandidates };
      }
      return job.score >= minScore ? job : { ...job, matches: 0 };
    })
    .filter(job => job.matches > 0);

  const sortedData = [...filteredData].sort(sorters[sortIndex].fn);
  const maxMatches = Math.max(...sortedData.map(d => d.matches), 1);

  const options = {
    title: { text: "" },
    chart: {
      type: "bar",
      height: sortedData.length * 35 + 120,
      marginLeft: 250,
      style: { fontFamily: "inherit" }
    },
    credits: { enabled: false },
    accessibility: { enabled: false },
    legend: { enabled: false },
    xAxis: {
      categories: sortedData.map(item => item.job),
      title: { text: null },
      labels: {
        style: { fontSize: "13px", whiteSpace: "nowrap", textOverflow: "ellipsis", color: "#222", fontWeight: 500 },
        formatter: function () {
          return this.value;
        }
      }
    },
    yAxis: {
      min: 0,
      title: { text: t ? t("charts.numberOfMatches") : "Number of Matches", align: "high" },
      gridLineDashStyle: "Dash"
    },
    tooltip: {
      useHTML: true,
      formatter: function () {
        const pointData = sortedData[this.point.index];
        const companyLabel = t ? t("charts.company") : "Company";
        const matchesLabel = t ? t("charts.matches") : "Matches";
        const avgScoreLabel = t ? t("charts.avgScore") : "Avg. Score";
        const clickToViewLabel = t ? t("charts.clickToViewJobMatches") : "Click to view job matches";
        return `
          <div style="white-space: nowrap; min-width: 150px;">
            <b>${this.point.category}</b><br/>
            <span style="color:${this.point.color}">●</span> ${companyLabel}: <b>${pointData.company}</b><br/>
            ${matchesLabel}: <b>${this.point.y}</b><br/>
            ${avgScoreLabel}: <b>${pointData.score ? pointData.score.toFixed(1) : ""}</b><br/>
            <span style="display:inline-block;margin-top:6px;padding:2px 8px;background:#eaf4fb;color:#2176bd;border-radius:4px;font-size:13px;font-weight:500;">${clickToViewLabel}</span>
          </div>
        `;
      }
    },
    plotOptions: {
      bar: {
        dataLabels: { enabled: true },
        borderRadius: 3,
        borderWidth: 0
      },
      series: {
        cursor: "pointer",
        point: {
          events: {
            click: function () {
              const jobTitle = this.category;
              const item = sortedData[this.index];
              const params = new URLSearchParams();
              params.set("companyName", item.company);
              params.set("job_title", jobTitle);
              if (item.job_id) {
                params.set("job_id", item.job_id);
              }
              navigate(`/admin/matches?${params.toString()}`);
            }
          }
        }
      }
    },
    series: [{
      name: t ? t("charts.matches") : "Matches",
      data: sortedData.map(item => ({ y: item.matches, color: companyColorMap[item.company] }))
    }],
    responsive: {
      rules: [{
        condition: { maxWidth: 768 },
        chartOptions: {
          chart: {
            height: sortedData.length * 25 + 80,
            marginLeft: 120
          },
          xAxis: {
            labels: {
              style: { fontSize: "11px" }
            }
          }
        }
      }]
    }
  };

  if (isMobile) {
    return (
      <div className="mobile-bar-chart">
        {sortedData.map((item, index) => (
          <div key={index} className="mobile-bar-chart__item">
            <div className="mobile-bar-chart__title">{item.job}</div>
            <div className="mobile-bar-chart__bar-wrapper">
              <div
                className="mobile-bar-chart__bar"
                style={{
                  width: `${(item.matches / maxMatches) * 100}%`,
                  backgroundColor: companyColorMap[item.company]
                }}
              />
              <span className="mobile-bar-chart__value">{item.matches}</span>
            </div>
          </div>
        ))}
      </div>
    );
  }

  return (
    <div className="custom-scrollbar" style={{ overflowY: "auto", maxHeight: "400px" }}>
      <HighchartsReact highcharts={Highcharts} options={options} />
    </div>
  );
};

export default PerJobBarChart;
