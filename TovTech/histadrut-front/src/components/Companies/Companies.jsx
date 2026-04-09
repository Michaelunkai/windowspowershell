import { ListFilter, Trash2 } from "lucide-react";
import React from "react";
import { useNavigate } from "react-router-dom";

import { deleteCompanyData } from "../../api";
import { useLanguage } from "../../contexts/LanguageContext";
import { useAuth } from "../../hooks/useAuth";
import { useCompaniesData } from "../../hooks/useCompaniesData";
import { useTranslations } from "../../utils/translations";
import Modal from "../shared/Modal";
import ScrollToTop from "../shared/ScrollToTop";
import "./Companies.css";

const Companies = () => {
  const {
    sortedCompanies: companiesData,
    loading,
    error,
    sortField,
    sortDirection,
    handleSort,
    searchTerm,
    handleSearch
  } = useCompaniesData();
  const navigate = useNavigate();
  const { t } = useTranslations("companies");
  const { currentLanguage } = useLanguage();

  const { isAdminOrDemo } = useAuth();
  const isAdmin = isAdminOrDemo();

  const handleViewCompany = companyName => {
    // Navigate to job listings page with company filter
    navigate(`/jobs-listings?company=${encodeURIComponent(companyName)}`);
  };

  const [deleteModalOpen, setDeleteModalOpen] = React.useState(false);
  const [companyToDelete, setCompanyToDelete] = React.useState(null);
  const [resultModalOpen, setResultModalOpen] = React.useState(false);
  const [resultMessage, setResultMessage] = React.useState("");

  const handleDeleteCompany = (companyName, jobsCount) => {
    setCompanyToDelete({ name: companyName, jobsCount });
    setDeleteModalOpen(true);
  };

  const confirmDeleteCompany = async () => {
    try {
      const response = await deleteCompanyData(companyToDelete.name);
      setResultMessage(response.message || "Company deleted successfully.");
    } catch (error) {
      setResultMessage(error.message || "Failed to delete company.");
    }
    setDeleteModalOpen(false);
    setResultModalOpen(true);
  };

  const closeResultModal = () => {
    setResultModalOpen(false);
    setCompanyToDelete(null);
    // Optionally refresh companies list here
    window.location.reload();
  };

  // Sort icons component
  const getSortIcon = field => {
    if (sortField !== field) {
      return (
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
          <path d="M4 2L6 0L8 2" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
          <path d="M8 10L6 12L4 10" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
      );
    }

    if (sortDirection === "asc") {
      return (
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
          <path d="M4 2L6 0L8 2" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
      );
    }

    return (
      <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
        <path d="M8 10L6 12L4 10" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
      </svg>
    );
  };

  const renderSortableHeader = ({ field, label, sortable = true }) => {
    const handleClick = () => {
      if (sortable && handleSort) {
        handleSort(field);
      }
    };

    return (
      <th
        className={`companies-table__cell companies-table__cell--header ${
          sortable ? "companies-table__header--sortable" : ""
        } ${sortField === field ? "companies-table__header--sorted" : ""}`}
        onClick={handleClick}
      >
        <div className="companies-table__header-content">
          <span>{label}</span>
          {sortable && (
            <span className="companies-table__sort-icon">{getSortIcon(field)}</span>
          )}
        </div>
      </th>
    );
  };

  if (loading) {
    return (
      <section
        className="main-page companies-page"
        dir="auto"
      >
        <div className="companies-header">
          <h1 className="page__title">{t("title")}</h1>
        </div>
        <div className="companies-table">
          <div className="companies-table__loading">{t("loading")}</div>
        </div>
      </section>
    );
  }

  if (error) {
    return (
      <section
        className="main-page companies-page"
        dir="auto"
      >
        <div className="companies-header">
          <h1 className="page__title">{t("title")}</h1>
        </div>
        <div className="companies-table">
          <div className="companies-table__error">{t("error")}: {error}</div>
        </div>
      </section>
    );
  }
  return (
    <section className="main-page companies-page" dir="auto">
      <div className="companies-header">
        <h1 className="page__title">{t("title")}</h1>
      </div>

      <div className="companies-filters">
        <div className="filter-group">
          <div className="companies-filters__input-container">
            <input
              type="text"
              placeholder={t("filters.searchPlaceholder")}
              value={searchTerm}
              onChange={e => handleSearch(e.target.value)}
              className="filter-input"
            />
            {searchTerm && (
              <button
                type="button"
                className="companies-filters__clear"
                onClick={() => handleSearch("")}
                title={t("filters.clear")}
              >
                ×
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Mobile card list */}
      <div className="companies-layout--mobile">
        <div className="companies-mobile">
          {companiesData.length === 0 ? (
            <div className="companies-mobile__empty">{t("noCompanies")}</div>
          ) : (
            companiesData.map(company => (
              <div key={company.id} className="company-card">
                <div className="company-card__header">
                  <div className="company-card__index">{company.id}</div>
                  <button
                    type="button"
                    className="company-card__name"
                    onClick={() => handleViewCompany(company.name)}
                    aria-label={t("actions.viewJobs", { company: company.name })}
                  >
                    {company.name}
                  </button>
                </div>

                <div className="company-card__info">
                  <div className="company-card__detail">
                    <span className="company-card__label">{t("table.headers.jobsCount")}:</span>
                    <span className="company-card__value company-card__value--jobs">{company.jobsCount}</span>
                  </div>
                </div>

                <div className="company-card__actions">
                  <button
                    className="company-card__action-btn company-card__action-btn--view"
                    onClick={() => handleViewCompany(company.name)}
                    title={t("actions.viewJobs", { company: company.name })}
                  >
                    <ListFilter aria-hidden="true" />
                    <span>{t("actions.viewJobsShort")}</span>
                  </button>
                  {isAdmin && (
                    <button
                      className="company-card__action-btn company-card__action-btn--delete"
                      onClick={() => handleDeleteCompany(company.name, company.jobsCount)}
                      title={t("actions.deleteCompany", { company: company.name })}
                      aria-label={t("actions.deleteCompany", { company: company.name })}
                    >
                      <Trash2 aria-hidden="true" />
                    </button>
                  )}
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {/* Desktop table */}
      <div className="companies-layout--desktop">
        <div className="companies-table" dir="ltr">
          <table className="companies-table__table">
            <thead className="companies-table__header">
              <tr>
                {renderSortableHeader({ field: "id", label: t("table.headers.id") })}
                {renderSortableHeader({ field: "name", label: t("table.headers.companyName") })}
                {renderSortableHeader({ field: "jobsCount", label: t("table.headers.jobsCount") })}
                {renderSortableHeader({ field: "actions", label: t("table.headers.actions"), sortable: false })}
              </tr>
            </thead>
            <tbody>
              {companiesData.length === 0 ? (
                <tr>
                  <td colSpan="4" className="companies-table__empty">{t("noCompanies")}</td>
                </tr>
              ) : (
                companiesData.map(company => (
                  <tr key={company.id} className="companies-table__row">
                    <td className="companies-table__cell companies-table__cell--id">{company.id}</td>
                    <td className="companies-table__cell companies-table__cell--name">
                      <button
                        type="button"
                        className="companies-table__cell--name-clickable"
                        onClick={() => handleViewCompany(company.name)}
                        aria-label={t("actions.viewJobs", { company: company.name })}
                      >
                        {company.name}
                      </button>
                    </td>
                    <td className="companies-table__cell companies-table__cell--jobs-count">{company.jobsCount}</td>
                    <td className="companies-table__cell companies-table__cell--actions">
                      <div className="companies-table__actions">
                        <button
                          className="companies-table__action-btn companies-table__action-btn--view"
                          onClick={() => handleViewCompany(company.name)}
                          title={t("actions.viewJobs", { company: company.name })}
                          aria-label={t("actions.viewJobs", { company: company.name })}
                        >
                          <ListFilter className="companies-table__action-icon" aria-hidden="true" />
                        </button>
                        {isAdmin && (
                          <button
                            className="companies-table__action-btn companies-table__action-btn--delete"
                            onClick={() => handleDeleteCompany(company.name, company.jobsCount)}
                            title={t("actions.deleteCompany", { company: company.name })}
                            aria-label={t("actions.deleteCompany", { company: company.name })}
                          >
                            <Trash2 className="companies-table__action-icon" aria-hidden="true" />
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      <Modal
        isOpen={deleteModalOpen}
        onClose={() => setDeleteModalOpen(false)}
        title={t("modal.deleteTitle")}
      >
        {companyToDelete && (
          <div className="delete-modal__text" dir="auto">
            {t("modal.deleteMessage", {
              company: companyToDelete.name.toUpperCase(),
              jobsCount: companyToDelete.jobsCount
            })}<br /><br />
            {t("modal.deleteConfirm")}
            <div className="delete-modal__actions">
              <button className="delete-modal__cancel" onClick={() => setDeleteModalOpen(false)}>
                {t("modal.cancel")}
              </button>
              <button className="delete-modal__delete" onClick={confirmDeleteCompany}>
                {t("modal.delete")}
              </button>
            </div>
          </div>
        )}
      </Modal>
      <Modal
        isOpen={resultModalOpen}
        onClose={closeResultModal}
        title={resultMessage.toLowerCase().includes("fail") ? t("modal.errorTitle") : t("modal.successTitle")}
      >
        <div className="delete-modal__result-text" dir="auto">
          {resultMessage}
        </div>
        <div className="delete-modal__actions" style={{ justifyContent: "center", marginTop: "1.5rem" }}>
          <button className="delete-modal__cancel" onClick={closeResultModal}>OK</button>
        </div>
      </Modal>
      <ScrollToTop />
    </section>
  );
};

export default Companies;
