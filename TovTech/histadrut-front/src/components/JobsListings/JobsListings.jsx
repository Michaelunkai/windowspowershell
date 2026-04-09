import { CirclePlus } from "lucide-react";
import React, { useState } from "react";
import { useNavigate } from "react-router-dom";

import { deleteJobAndMatches } from "../../api";
import { useAuth } from "../../hooks/useAuth";
import { useJobsData } from "../../hooks/useJobsData";
import { useTranslations } from "../../utils/translations";
import JobDescriptionModal from "../shared/JobDescriptionModal";
import Modal from "../shared/Modal";
import ScrollToTop from "../shared/ScrollToTop";
import JobListingsFilters from "./JobListingsFilters";
import "./JobsListings.css";
import JobListingsTable from "./JobListingsTable";

const JobsListings = () => {
  const { t, currentLanguage } = useTranslations("jobListings");
  const {
    filteredJobs,
    loading,
    error,
    companies,
    jobTitleTerm,
    jobDescriptionTerm,
    jobIdTerm,
    selectedCompany,
    selectedRegions,
    postedAfter,
    sortField,
    sortDirection,
    handleJobTitleChange,
    handleJobDescriptionChange,
    handleJobIdChange,
    handleCompanyChange,
    handleRegionsChange,
    handlePostedAfterChange,
    handleLimitChange,
    handleSort,
    currentPage,
    totalPages,
    totalJobs,
    goToNextPage,
    goToPreviousPage,
    resetFilters,
    filters
  } = useJobsData();

  const { isAdminOrDemo } = useAuth();
  const isAdmin = isAdminOrDemo();
  const navigate = useNavigate();
  const [viewJob, setViewJob] = useState(null);
  const [deleteJob, setDeleteJob] = useState(null);
  const [deleteLoading, setDeleteLoading] = useState(false);
  const [deleteError, setDeleteError] = useState("");
  const [showDeleteSuccess, setShowDeleteSuccess] = useState(false);

  return (
    <section className="main-page jobs-listings" key={currentLanguage} dir="auto">
      <div className="jobs-listings__header">
        <h1 className="page__title">{t("title")}</h1>
        {isAdmin && (
          <button
            className="jobs-listings__add-btn"
            onClick={() => navigate("/jobs/add")}
          >
            <CirclePlus className="btn-icon" aria-label="Add" />
            {t("addNewJob")}
          </button>
        )}
      </div>

      <JobListingsFilters
        jobTitleTerm={jobTitleTerm}
        onJobTitleChange={handleJobTitleChange}
        jobDescriptionTerm={jobDescriptionTerm}
        onJobDescriptionChange={handleJobDescriptionChange}
        jobIdTerm={jobIdTerm}
        onJobIdChange={handleJobIdChange}
        selectedCompany={selectedCompany}
        onCompanyChange={handleCompanyChange}
        selectedRegions={selectedRegions}
        onRegionsChange={handleRegionsChange}
        postedAfter={postedAfter}
        onPostedAfterChange={handlePostedAfterChange}
        companies={companies}
        onClearAll={resetFilters}
      />

      <JobListingsTable
        key={`table-${filteredJobs.length}-${selectedCompany}`}
        jobs={filteredJobs}
        loading={loading}
        error={error}
        sortField={sortField}
        sortDirection={sortDirection}
        onSort={handleSort}
        showActions={isAdmin}
        onJobTitleClick={job => {
          const params = new URLSearchParams();
          if (job.company) {
            params.set("companyName", job.company);
          }
          if (job.title) {
            params.set("job_title", job.title);
          }
          if (job.job_id || job.id) {
            params.set("job_id", job.job_id || job.id);
          }
          const base = isAdmin ? "/admin/matches" : "/user/matches";
          const url = `${base}?${params.toString()}`;
          navigate(url);
        }}
        onAction={(action, job) => {
          if (action === "view") {
            setViewJob(job);
          }
          if (action === "delete") {
            setDeleteJob(job);
          }
        }}
      />

      {/* Pagination Controls */}
      <div className="pagination-controls">
        <div className="pagination-left">
          <div className="page-size-control">
            <span className="page-size-label">{t("pagination.showLabel")}</span>
            <div className="page-size-buttons">
              {[20, 50, 100].map(size => (
                <button
                  key={size}
                  className={`page-size-btn ${filters?.limit === size ? "active" : ""}`}
                  onClick={() => handleLimitChange(size)}
                >
                  {t(`pagination.pageSize${size}`)}
                </button>
              ))}
            </div>
            <span className="page-size-label">{t("pagination.jobsPerPage")}</span>
          </div>
        </div>
        <div className="pagination-right">
          <button
            onClick={goToPreviousPage}
            disabled={currentPage === 1}
            className="pagination-button"
          >
            {t("pagination.previous")}
          </button>
          <span className="pagination-info">
            {t("pagination.pageInfo", { current: totalPages === 0 ? 1 : currentPage, total: totalPages === 0 ? 1 : totalPages })}
          </span>
          <span className="pagination-total">
            {t("pagination.totalJobs", { total: totalJobs })}
          </span>
          <button
            onClick={goToNextPage}
            disabled={currentPage === totalPages}
            className="pagination-button"
          >
            {t("pagination.next")}
          </button>
        </div>
      </div>
      <JobDescriptionModal isOpen={!!viewJob} job={viewJob} onClose={() => setViewJob(null)} />

      {/* Delete confirmation modal */}
      <Modal
        key={currentLanguage}
        isOpen={!!deleteJob}
        onClose={() => {
          setDeleteJob(null);
          setDeleteError("");
        }}
        title={t("deleteModal.title")}
      >
        <div style={{ padding: "2rem 2.5rem 1.5rem 2.5rem" }}>
          <p style={{ fontWeight: 500, color: "#b71c1c", marginBottom: 18 }} dangerouslySetInnerHTML={{ __html: t("deleteModal.warningText") }} />
          <div style={{ margin: "1.2rem 0 1.2rem 0", color: "#333", fontSize: "1.05rem", lineHeight: 1.7 }}>
            <b>{t("deleteModal.jobId")}:</b> {deleteJob?.job_id} <br />
            <b>{t("deleteModal.job")}:</b> {deleteJob?.title} <br />
            <b>{t("deleteModal.company")}:</b> {deleteJob?.company}
          </div>
          {deleteError && <div style={{ color: "#e74c3c", marginBottom: 8 }}>{deleteError}</div>}
          <div style={{ display: "flex", gap: 16, justifyContent: "flex-end", marginTop: 10 }}>
            <button
              onClick={() => {
                setDeleteJob(null);
                setDeleteError("");
              }}
              style={{ padding: "8px 18px", background: "#eee", border: "none", borderRadius: 4, cursor: "pointer" }}
              disabled={deleteLoading}
            >
              {t("deleteModal.cancel")}
            </button>
            <button
              onClick={async () => {
                setDeleteLoading(true);
                setDeleteError("");
                try {
                  await deleteJobAndMatches(deleteJob.id);
                  setDeleteJob(null);
                  setShowDeleteSuccess(true);
                } catch (err) {
                  setDeleteError(err.message || t("deleteModal.errorDeleting"));
                } finally {
                  setDeleteLoading(false);
                }
              }}
              style={{ padding: "8px 18px", background: "#e74c3c", color: "#fff", border: "none", borderRadius: 4, cursor: "pointer", fontWeight: 600 }}
              disabled={deleteLoading}
            >
              {deleteLoading ? t("deleteModal.deleting") : t("deleteModal.delete")}
            </button>
          </div>
        </div>
      </Modal>

      {/* Success modal after delete */}
      <Modal
        key={`success-${currentLanguage}`}
        isOpen={showDeleteSuccess}
        onClose={() => {
          setShowDeleteSuccess(false);
          location.reload();
        }}
        title={t("successModal.title")}
      >
        <div style={{ padding: "2.5rem 2.5rem 2rem 2.5rem", textAlign: "center" }}>
          <div style={{ fontSize: 48, color: "#27ae60", marginBottom: 16 }}>✔</div>
          <div style={{ fontWeight: 600, fontSize: "1.2rem", color: "#222", marginBottom: 8 }}>
            {t("successModal.message")}
          </div>
          <div style={{ color: "#666", fontSize: "1rem" }}>
            {t("successModal.instruction")}
          </div>
        </div>
      </Modal>
      <ScrollToTop />
    </section>
  );
};

export default JobsListings;
