import Highcharts from "highcharts";
import HighchartsReact from "highcharts-react-official";
import React from "react";

import { useViewport } from "../../contexts/ViewportContext";
import "./CompanyJobsPieChart.css";

const OTHER_ID = "__other__";

const CompanyJobsPieChart = ({ data = [], onSliceClick, selectedCompany, companyColorMap = {}, t }) => {
  const { isMobile } = useViewport();
  // Aggregate by company
  const companyCounts = {};
  data.forEach(item => {
    companyCounts[item.company] = (companyCounts[item.company] || 0) + 1;
  });
  const aggData = Object.entries(companyCounts).map(([name, y]) => ({ id: name, name, y }));
  aggData.sort((a, b) => b.y - a.y);

  const otherLabel = t && typeof t === "function" ? t("charts.other") : "Other";
  let pieData = aggData;
  if (aggData.length > 5) {
    const top5 = aggData.slice(0, 5);
    const otherSum = aggData.slice(5).reduce((sum, d) => sum + d.y, 0);
    pieData = [...top5, { id: OTHER_ID, name: otherLabel, y: otherSum }];
  }
  pieData = pieData.map(d => ({
    ...d,
    color: companyColorMap[d.id] || "#bdc3c7",
    sliced: selectedCompany && d.id === selectedCompany
  }));

  const pointClickEvent = {
    click() {
      if (onSliceClick && this.options.id !== OTHER_ID) {
        onSliceClick(this.options.id);
      }
    }
  };

  const options = {
    chart: {
      type: "pie",
      height: 300,
      ...(isMobile ? { backgroundColor: "transparent", spacing: [10, 0, 0, 0], width: 390 } : { height: 400 })
    },
    title: {
      text: isMobile ? null : (t ? t("charts.topCompaniesByJobs") : "Top Companies by Number of Jobs"),
      style: { fontSize: "1rem", fontWeight: 500 },
      margin: 6
    },
    series: [{
      name: t ? t("charts.jobs") : "Jobs",
      colorByPoint: true,
      data: pieData,
      point: { events: pointClickEvent },
      ...(isMobile && { size: "90%", center: ["50%", "50%"], innerSize: "0%" })
    }],
    legend: { enabled: false },
    credits: { enabled: false },
    accessibility: { enabled: false },
    tooltip: {
      pointFormat: "<b>{point.y}</b> {series.name}",
      style: { fontSize: "13px" }
    },
    plotOptions: {
      pie: {
        allowPointSelect: true,
        cursor: "pointer",
        dataLabels: { enabled: !isMobile },
        showInLegend: !isMobile,
        borderWidth: 2,
        borderColor: "#fff",
        states: { hover: { brightness: 0.05 } }
      }
    }
  };

  return (
    <>
      {isMobile && (
        <div className="pie-chart-mobile-title">
          {t ? t("charts.topCompaniesByJobs") : "Top Companies by Number of Jobs"}
        </div>
      )}
      <div className={isMobile ? "pie-chart-mobile-wrapper" : undefined}>
        <HighchartsReact highcharts={Highcharts} options={options} />
      </div>
      <div className="pie-chart-legend">
        {pieData.map(item => (
          <button
            key={item.id}
            className="pie-chart-legend__item"
            onClick={() => onSliceClick && onSliceClick(item.id)}
            disabled={item.id === OTHER_ID || !onSliceClick}
          >
            <span className="pie-chart-legend__symbol" style={{ backgroundColor: item.color }} />
            <span className="pie-chart-legend__text">{item.name}</span>
          </button>
        ))}
      </div>
    </>
  );
};

export default CompanyJobsPieChart;
