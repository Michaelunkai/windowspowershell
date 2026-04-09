import { useEffect, useState } from "react";

import { fetchReportMatches } from "../../api";
import { useLanguage } from "../../contexts/LanguageContext";
import { useViewport } from "../../contexts/ViewportContext";
import { useTranslations } from "../../utils/translations";
import ScrollToTop from "../shared/ScrollToTop";
import CompanyJobsPieChart from "./CompanyJobsPieChart";
import "./custom-scrollbar.css";
import JobScoresStripPlot from "./JobScoresStripPlot";
import PerJobBarChart from "./PerJobBarChart";
import styles from "./Reporting.module.css";

const Reporting = () => {
  const { t } = useTranslations("reporting");
  const { currentLanguage } = useLanguage();
  const { isMobile } = useViewport();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [sortIndex, setSortIndex] = useState(1); // Default to "Matches (High → Low)"
  const [minScore, setMinScore] = useState(7.5);
  const [maxScore, setMaxScore] = useState(10);
  const [selectedCompany, setSelectedCompany] = useState(null);

  useEffect(() => {
    fetchReportMatches()
      .then(res => {
        setData(res);
        setError(null);
        // Find the max score in the per_job data
        if (res && res.per_job && res.per_job.length > 0) {
          let max = 7.5;
          res.per_job.forEach(job => {
            if (Array.isArray(job.candidates)) {
              job.candidates.forEach(c => {
                if (typeof c.score === "number" && c.score > max) {
                  max = c.score;
                }
              });
            } else if (typeof job.score === "number" && job.score > max) {
              max = job.score;
            }
          });
          setMaxScore(Math.max(7.5, Math.floor(max * 10) / 10));
        }
      })
      .catch(() => {
        setError("error"); // Store the translation key, not the translated string
        setData(null);
      })
      .finally(() => setLoading(false));
  }, []);

  // Get all companies from data
  const allCompanies =
    data && data.per_job
      ? Array.from(new Set(data.per_job.map(j => j.company)))
      : [];

  // Set default selected company when data loads
  useEffect(() => {
    if (data && data.per_job && data.per_job.length > 0) {
      setSelectedCompany(data.per_job[0].company);
    }
  }, [data]);

  // --- DATA MAPPING FOR CHARTS ---
  // 1. Bar chart: [{ company, job, matches, score }]
  const barChartData =
    data && data.per_job
      ? data.per_job.map(j => ({
        company: j.company,
        job: j.job,
        matches: j.matches,
        score: j.score,
        job_id: j.job_id
      }))
      : [];

  // 2. Pie chart: [{ company, job }]
  const pieChartData =
    data && data.per_job
      ? data.per_job.map(j => ({
        company: j.company,
        job: j.job
      }))
      : [];

  // 3. Strip plot: { [company]: [{ job, scores }] }
  const stripPlotData = {};
  if (data && data.per_job) {
    data.per_job.forEach(j => {
      if (!stripPlotData[j.company]) {
        stripPlotData[j.company] = [];
      }
      stripPlotData[j.company].push({
        job: j.job,
        scores: j.scores
      });
    });
  }

  // Jobs for selected company (for strip plot)
  const companyJobs =
    selectedCompany && stripPlotData[selectedCompany]
      ? stripPlotData[selectedCompany]
      : [];

  // Handler for pie chart click (to be passed to CompanyJobsPieChart)
  const handlePieClick = company => {
    setSelectedCompany(company);
  };

  // Dynamic chart title based on minScore
  const chartTitle = t("charts.jobsWithHighScoreMatches", { minScore });

  const companyColorPalette = [
    "#3498db",
    "#e67e22",
    "#2ecc71",
    "#e74c3c",
    "#9b59b6",
    "#f1c40f",
    "#1abc9c",
    "#34495e",
    "#fd79a8",
    "#00b894",
    "#fdcb6e",
    "#636e72",
    "#00cec9",
    "#6c5ce7",
    "#fab1a0",
    "#d35400"
  ];

  const companyColorMap = {};
  allCompanies.forEach((company, idx) => {
    companyColorMap[company] = companyColorPalette[idx % companyColorPalette.length];
  });

  return (
    <section className={`main-page page ${styles.mobilePage}`} dir="ltr">
      <div dir="auto">
        <h1 className="page__title">{t("title")}</h1>
      </div>
      <div className="page__content">
        <div className={styles.reportingPageColumn}>
          {error && <div className={styles.error}>{t(error)}</div>}

          {/* Filter controls — responsive (row on desktop, card column on mobile) */}
          {!loading && (
            <div className={styles.filterBar}>
              <div className={styles.sorter}>
                <label htmlFor="sort-bar-chart" className={styles.sorter__label}>
                  {t("filters.sortBy")}
                </label>
                <select
                  id="sort-bar-chart"
                  value={sortIndex}
                  onChange={e => setSortIndex(Number(e.target.value))}
                  className={styles.sorter__select}
                >
                  <option value={0}>{t("filters.sortOptions.companyAZ")}</option>
                  <option value={1}>{t("filters.sortOptions.matchesHighLow")}</option>
                </select>
              </div>
              <div className={styles.minScoreFilter}>
                <label htmlFor="min-score-slider" className={styles.sorter__label}>
                  {t("filters.minScore")} <b>{minScore}</b>
                </label>
                <input
                  id="min-score-slider"
                  type="range"
                  min={7.5}
                  max={maxScore}
                  step={0.1}
                  value={minScore}
                  onChange={e => setMinScore(Number(e.target.value))}
                  className={styles.minScoreSlider}
                />
              </div>
            </div>
          )}

          {/* Bar Chart */}
          {!loading && <h2 className={styles.chartTitle}>{chartTitle}</h2>}
          <div className={styles.reportingCard}>
            {loading ? (
              <div className={styles.spinnerWrapper}>
                <div className={styles.spinner} />
                <div style={{ marginTop: "1rem", color: "#666" }}>{t("loading")}</div>
              </div>
            ) : (
              <PerJobBarChart
                data={barChartData}
                sortIndex={sortIndex}
                minScore={minScore}
                companyColorMap={companyColorMap}
                t={t}
              />
            )}
          </div>

          {/* Pie Chart + Strip Plot */}
          <div className={styles.reportingCardLarge}>
            <div className={isMobile ? undefined : "custom-scrollbar"} style={isMobile ? undefined : { height: "100%", overflowY: "auto" }}>
              {loading ? (
                <div className={styles.spinnerWrapper}>
                  <div className={styles.spinner} />
                  <div style={{ marginTop: "1rem", color: "#666" }}>{t("loading")}</div>
                </div>
              ) : (
                <div className={styles.flexRowGraphs}>
                  <div className={styles.pieChartCol}>
                    <CompanyJobsPieChart
                      key={currentLanguage}
                      data={pieChartData}
                      onSliceClick={handlePieClick}
                      selectedCompany={selectedCompany}
                      companyColorMap={companyColorMap}
                      t={t}
                    />
                  </div>
                  <div className={styles.stripPlotCol}>
                    <div className={styles.companySelectorBar}>
                      <label
                        htmlFor="company-select"
                        className={styles.companySelectorLabel}
                      >
                        {t("filters.showCompany")}
                      </label>
                      <select
                        id="company-select"
                        value={selectedCompany || ""}
                        onChange={e => setSelectedCompany(e.target.value)}
                        className={styles.companySelector}
                      >
                        {allCompanies.map(c => (
                          <option key={c} value={c}>
                            {c}
                          </option>
                        ))}
                      </select>
                    </div>
                    <JobScoresStripPlot
                      key={currentLanguage}
                      data={companyJobs}
                      companyColorMap={companyColorMap}
                      selectedCompany={selectedCompany}
                      t={t}
                    />
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
      <ScrollToTop />
    </section>
  );
};

export default Reporting;
