import React from "react";

import { useLanguage } from "../../contexts/LanguageContext";
import { useTranslations } from "../../utils/translations";

const Stats = ({ data, companiesToday, loading, error }) => {
  const { t } = useTranslations("overview");
  const { currentLanguage } = useLanguage();
  if (loading) {
    return (
      <div className="stats">
        <div className="stats__loading">{t("loadingStats")}</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="stats">
        <div className="stats__error">{t("errorLoadingStats")}: {error}</div>
      </div>
    );
  }

  const statsCards = [
    {
      title: t("totalActiveJobs"),
      value: data?.jobs || 0,
      color: "blue"
    },
    {
      title: t("totalCandidates"),
      value: data?.candidates || 0,
      color: "green"
    },
    {
      title: t("totalMatches"),
      value: data?.matches || 0,
      color: "purple"
    },
    {
      title: t("jobsAddedLastDay"),
      value: data?.jobsLastDay || 0,
      color: "orange"
    },
    {
      title: t("jobsAddedLastWeek"),
      value: data?.jobsLastWeek || 0,
      color: "teal"
    }
  ];

  // Show companies today card directly below "Jobs Added Last Day" if conditions are met
  const shouldShowCompaniesCard = data?.jobsLastDay > 0 && companiesToday && companiesToday.length > 0;

  return (
    <section className="stats" aria-labelledby="stats-heading" dir="auto">
      <h2 id="stats-heading" className="sr-only">
        Dashboard Statistics
      </h2>
      <div className="stats__container">
        <div className="stats__grid">
          {statsCards.map((stat, index) => (
            <article
              key={index}
              className={`stats__card stats__card--${stat.color}`}
            >
              <h3 className="stats__card-title">{stat.title}</h3>
              <div className="stats__card-value">{stat.value}</div>
            </article>
          ))}
        </div>

        {/* Companies today card positioned below "Jobs Added Last Day" */}
        {shouldShowCompaniesCard && (
          <div className="stats__companies-today">
            <article className="stats__card stats__card--companies">
              <h3 className="stats__card-title">{t("newJobsByCompanyToday")}</h3>
              <div className="stats__companies-list">
                {companiesToday.map((company, index) => (
                  <div key={index} className="stats__company-item">
                    <span className="stats__company-name">{company.company_name}</span>
                    <span className="stats__company-count">{company.count}</span>
                  </div>
                ))}
              </div>
            </article>
          </div>
        )}
      </div>
    </section>
  );
};

export default Stats;
