import React, { useState, useEffect } from "react";

import { fetchCompanies } from "../../api";
import { useLanguage } from "../../contexts/LanguageContext";
import { useTranslations } from "../../utils/translations";
import "./JobForm.css";

const initialJobState = {
  job_title: "",
  position_link: "",
  company_name: "",
  field: "",
  job_id: "",
  region: "",
  scope: "",
  job_description: ""
};

export default function JobForm({ onSubmit, onCancel, initialValues = initialJobState, submitLabel = "OK", pageTitle, viewMode = false }) {
  const { t } = useTranslations("addJob");
  const { currentLanguage } = useLanguage();
  const [form, setForm] = useState(initialValues);
  const [companies, setCompanies] = useState([]);
  const [companySelect, setCompanySelect] = useState(initialValues.company_name ? initialValues.company_name : "");
  const [showOther, setShowOther] = useState(false);
  const [otherCompany, setOtherCompany] = useState("");

  useEffect(() => {
    fetchCompanies().then(data => {
      if (data && typeof data === "object") {
        setCompanies(Object.keys(data));
      }
    });
  }, []);

  const handleChange = e => {
    if (viewMode) {
      return;
    }
    const { name, value } = e.target;
    setForm(prev => ({ ...prev, [name]: value }));
  };

  const handleCompanySelect = e => {
    const value = e.target.value;
    setCompanySelect(value);
    if (value === "Other") {
      setShowOther(true);
      setForm(prev => ({ ...prev, company_name: "" }));
    } else {
      setShowOther(false);
      setForm(prev => ({ ...prev, company_name: value }));
    }
  };

  const handleOtherCompanyChange = e => {
    setOtherCompany(e.target.value);
    setForm(prev => ({ ...prev, company_name: e.target.value }));
  };

  const handleSubmit = e => {
    e.preventDefault();
    onSubmit(form);
  };

  const isRTL = currentLanguage === "he";

  return (
    <div dir="auto">
      {pageTitle && (
        <h1 className="job-form__page-title">{pageTitle}</h1>
      )}

      <style>{`
        .job-form input::placeholder,
        .job-form textarea::placeholder {
          color: #8a99a8;
          opacity: 1;
        }
      `}</style>
      <form key={`jobForm-${currentLanguage}`} className={`job-form ${isRTL ? "job-form--rtl" : ""}`} onSubmit={handleSubmit}>
        <div className="job-form__fields">
          <label className="job-form__label job-form__label--required">
            <span className="job-form__label-text">
              {t("form.jobTitle")} <span className="job-form__asterisk">*</span>
            </span>
            <input
              name="job_title"
              value={form.job_title}
              onChange={handleChange}
              required={!viewMode}
              placeholder={t("form.jobTitlePlaceholder")}
              style={{ background: "#fafbfc", color: "#222", border: "1px solid #e1e8ed", borderRadius: "4px", fontSize: "0.9rem", padding: "0.75rem" }}
              disabled={viewMode}
            />
          </label>
          <label className="job-form__label">
            {t("form.positionLink")}
            <input
              name="position_link"
              value={form.position_link}
              onChange={handleChange}
              placeholder={t("form.positionLinkPlaceholder")}
              style={{ background: "#fafbfc", color: "#222", border: "1px solid #e1e8ed", borderRadius: "4px", fontSize: "0.9rem", padding: "0.75rem" }}
              disabled={viewMode}
            />
          </label>
          <label className="job-form__label job-form__label--required">
            <span className="job-form__label-text">
              {t("form.company")} <span className="job-form__asterisk">*</span>
            </span>
            <select
              name="company_name"
              value={companySelect}
              onChange={handleCompanySelect}
              required={!viewMode}
              style={{ background: "#fafbfc", color: "#222", border: "1px solid #e1e8ed", borderRadius: "4px", fontSize: "0.9rem", padding: "0.75rem" }}
              disabled={viewMode}
            >
              <option value="">{t("form.companyPlaceholder")}</option>
              {companies.map(name => (
                <option key={name} value={name}>{name}</option>
              ))}
              <option value="Other">{t("form.companyOther")}</option>
              {viewMode && companySelect && !companies.includes(companySelect) && (
                <option value={companySelect}>{companySelect}</option>
              )}
            </select>
          </label>
          {showOther && <label className="job-form__label">
            {t("form.newCompanyName")}
            <input
              name="other_company"
              value={otherCompany}
              onChange={handleOtherCompanyChange}
              required={showOther && !viewMode}
              placeholder={t("form.newCompanyPlaceholder")}
              style={{ background: "#fafbfc", color: "#222", border: "1px solid #e1e8ed", borderRadius: "4px", fontSize: "0.9rem", padding: "0.75rem" }}
              disabled={viewMode}
            />
          </label>}
          <label className="job-form__label">
            {t("form.field")}
            <input
              name="field"
              value={form.field}
              onChange={handleChange}
              placeholder={t("form.fieldPlaceholder")}
              style={{ background: "#fafbfc", color: "#222", border: "1px solid #e1e8ed", borderRadius: "4px", fontSize: "0.9rem", padding: "0.75rem" }}
              disabled={viewMode}
            />
          </label>
          <label className="job-form__label job-form__label--required">
            <span className="job-form__label-text">
              {t("form.jobId")} <span className="job-form__asterisk">*</span>
            </span>
            <input
              name="job_id"
              value={form.job_id}
              onChange={handleChange}
              required={!viewMode}
              placeholder={t("form.jobIdPlaceholder")}
              style={{ background: "#fafbfc", color: "#222", border: "1px solid #e1e8ed", borderRadius: "4px", fontSize: "0.9rem", padding: "0.75rem" }}
              disabled={viewMode}
            />
          </label>
          <label className="job-form__label">
            {t("form.region")}
            <input
              name="region"
              value={form.region}
              onChange={handleChange}
              placeholder={t("form.regionPlaceholder")}
              style={{ background: "#fafbfc", color: "#222", border: "1px solid #e1e8ed", borderRadius: "4px", fontSize: "0.9rem", padding: "0.75rem" }}
              disabled={viewMode}
            />
          </label>
          <label className="job-form__label">
            {t("form.scope")}
            <select
              name="scope"
              value={form.scope}
              onChange={handleChange}
              style={{ background: "#fafbfc", color: "#222", border: "1px solid #e1e8ed", borderRadius: "4px", fontSize: "0.9rem", padding: "0.75rem" }}
              disabled={viewMode}
            >
              <option value="">{t("form.scopePlaceholder")}</option>
              <option value="Full-time">{t("form.scopeFullTime")}</option>
              <option value="Part-time">{t("form.scopePartTime")}</option>
              {viewMode && form.scope && !["Full-time", "Part-time"].includes(form.scope) && (
                <option value={form.scope}>{form.scope}</option>
              )}
            </select>
          </label>
          <label className="job-form__label job-form__label--required">
            <span className="job-form__label-text">
              {t("form.jobDescription")} <span className="job-form__asterisk" style={{ color: "#e74c3c" }}>*</span>
            </span>
            <textarea
              name="job_description"
              value={form.job_description}
              onChange={handleChange}
              required={!viewMode}
              placeholder={t("form.jobDescriptionPlaceholder")}
              style={{ background: "#fafbfc", color: "#222", border: "1px solid #e1e8ed", borderRadius: "4px", fontSize: "0.9rem", padding: "0.75rem", minHeight: "80px" }}
              disabled={viewMode}
            />
          </label>
        </div>
        {!viewMode && (
          <div className="job-form__actions">
            <button type="button" className="job-form__cancel" onClick={onCancel}>{t("actions.cancel")}</button>
            <button type="submit" className="job-form__ok">{submitLabel}</button>
          </div>
        )}
      </form>
    </div>
  );
}
