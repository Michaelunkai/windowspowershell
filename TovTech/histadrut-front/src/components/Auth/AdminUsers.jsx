import { CheckCircle2, Download, Eye, FileWarning, Trash2 } from "lucide-react";

import "./AdminUsers.css";
import React, { useState } from "react";

import { deleteUser } from "../../api";
import { formatDateDDMMYYYY } from "../../api/transformers";
import { useLanguage } from "../../contexts/LanguageContext";
import { useUsersData } from "../../hooks/useUsersData";
import { API_BASE_URL } from "../../utils/config";
import { useTranslations } from "../../utils/translations";
import Modal from "../shared/Modal";
import ScrollToTop from "../shared/ScrollToTop";
import CVPreviewModal from "./CVPreviewModal";

const AdminUsers = () => {
  const { t: tUsers } = useTranslations("users");      // Page keys: title, table.headers.name, etc.
  const { t: tPagination } = useTranslations("common"); // Pagination: previous, next, etc.
  const { currentLanguage } = useLanguage();

  // Updated destructuring to match new useUsersData (like JobsListings)
  const {
    filteredUsers: users, // Renamed from sortedUsers for consistency
    loading,
    error: tableError,
    sortField,
    sortDirection,
    handleSort,
    searchTerm,
    handleSearch,
    currentPage,
    totalPages,
    totalUsers,
    goToNextPage,
    goToPreviousPage,
    handleLimitChange,
    resetFilters,
    filters,
    refreshUsers // Still available for delete refresh
  } = useUsersData();

  const [deleteModalOpen, setDeleteModalOpen] = useState(false);
  const [userToDelete, setUserToDelete] = useState(null);
  const [deleting, setDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState("");
  const [successModalOpen, setSuccessModalOpen] = useState(false);
  const [cvModalOpen, setCvModalOpen] = useState(false);
  const [selectedUserForCV, setSelectedUserForCV] = useState(null);

  // Sort icons (keep as-is, works with new handleSort)
  const getSortIcon = field => {
    if (sortField !== field) {
      return (
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
          <path d="M4 2L6 0L8 2" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
          <path d="M8 10L6 12L4 10" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      );
    }

    if (sortDirection === "asc") {
      return (
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
          <path d="M4 2L6 0L8 2" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      );
    }

    return (
      <svg width="12" height="12" viewBox="0 0 12 12" fill="none">
        <path d="M8 10L6 12L4 10" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    );
  };

  // SortableHeader (keep as-is)
  const SortableHeader = ({ field, children, sortable = true }) => {
    const handleClick = () => {
      if (sortable && handleSort) {
        handleSort(field);
      }
    };

    return (
      <th
        className={`admin-users-table__header ${sortable ? "admin-users-table__header--sortable" : ""
        } ${sortField === field ? "admin-users-table__header--sorted" : ""}`}
        onClick={handleClick}
      >
        <div className="admin-users-table__header-content">
          <span>{children}</span>
          {sortable && (
            <span className="admin-users-table__sort-icon">{getSortIcon(field)}</span>
          )}
        </div>
      </th>
    );
  };

  const handleDeleteClick = user => {
    setUserToDelete(user);
    setDeleteModalOpen(true);
    setDeleteError("");
  };

  const handleDeleteConfirm = async () => {
    setDeleting(true);
    setDeleteError("");
    try {
      await deleteUser(userToDelete._id);
      await refreshUsers(); // Refreshes data (now triggers server refetch)
      setDeleteModalOpen(false);
      setSuccessModalOpen(true);
      setUserToDelete(null);
    } catch (e) {
      setDeleteError(e.message || tUsers("error"));
    } finally {
      setDeleting(false);
    }
  };

  const handleDeleteCancel = () => {
    setDeleteModalOpen(false);
    setUserToDelete(null);
    setDeleteError("");
  };

  const handleSuccessModalClose = () => {
    setSuccessModalOpen(false);
  };

  const handleViewCV = user => {
    setSelectedUserForCV(user);
    setCvModalOpen(true);
  };

  const handleDownloadCV = user => {
    if (!user || !user.cv_id) {
      return;
    }

    const link = document.createElement("a");
    link.href = `${API_BASE_URL}/s3_get_cv?id=${user.cv_id}&mode=download`;
    link.download = `${user.name.replace(/\s+/g, "_")}_CV.pdf`;
    link.target = "_blank";
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  // Pagination info helpers (like JobsListings)
  const getPageInfo = () => {
    if (totalPages === 0) {
      return tPagination("pagination.pageInfo", { current: 1, total: 1 });
    }
    return tPagination("pagination.pageInfo", { current: currentPage, total: totalPages });
  };

  const renderCVStatus = (user, isMobileContext = false) => {
    const actionsClass = isMobileContext ? "cv-actions-mobile" : "cv-actions";
    if ((user.cv_status === "uploaded" || user.cv_status === "Uploaded") && user.cv_id && user.cv_id !== "null" && user.cv_id !== "None") {
      return (
        <>
          <span className="cv-status-badge cv-status-badge--uploaded">
            <CheckCircle2 size={12} />
            {user.cv_status}
          </span>
          <div className={actionsClass}>
            <button
              className="cv-action-btn cv-action-btn--view"
              onClick={() => handleViewCV(user)}
              title={tUsers("actions.viewCV")}
              aria-label={tUsers("actions.viewCV")}
            >
              <Eye size={18} aria-hidden="true" />
            </button>
            <button
              className="cv-action-btn cv-action-btn--download"
              onClick={() => handleDownloadCV(user)}
              title={tUsers("actions.downloadCV")}
              aria-label={tUsers("actions.downloadCV")}
            >
              <Download size={18} aria-hidden="true" />
            </button>
          </div>
        </>
      );
    } else if (user.cv_status === "uploaded" || user.cv_status === "Uploaded") {
      return (
        <span className="cv-status-badge cv-status-badge--uploaded">
          <CheckCircle2 size={12} />
          {user.cv_status} (ID missing)
        </span>
      );
    }
    return (
      <span className="cv-status-badge cv-status-badge--missing">
        <FileWarning size={12} />
        {user.cv_status}
      </span>
    );
  };

  return (
    <div className="main-page admin-users-page" key={currentLanguage} dir="auto">
      <div className="admin-users-header">
        <h1 className="page__title">{tUsers("title")}</h1>
      </div>

      {/* Filters/Search + Page Size */}
      <div className="admin-users-filters">
        <div className="filter-group">
          <div className="admin-users-filters__input-container">
            <input
              type="text"
              placeholder={tUsers("filters.searchPlaceholder")}
              value={searchTerm}
              onChange={e => handleSearch(e.target.value)}
              className="filter-input"
            />
            {searchTerm && (
              <button
                type="button"
                className="admin-users-filters__clear"
                onClick={() => handleSearch("")}
                title={tUsers("filters.clear")}
              >
                ×
              </button>
            )}
          </div>
          {/* Page Size Selector */}
          <div className="page-size-control">
            <span className="page-size-label">{tPagination("pagination.showLabel") || "Show"}</span>
            <div className="page-size-buttons">
              {[10, 20, 50].map(size => (
                <button
                  key={size}
                  className={`page-size-btn ${filters?.limit === size ? "active" : ""}`}
                  onClick={() => handleLimitChange(size)}
                >
                  {size}
                </button>
              ))}
            </div>
            <span className="page-size-label">{tPagination("pagination.usersPerPage") || "per page"}</span>
          </div>
          {/* Reset Button */}
          <button
            className="reset-filters-btn"
            onClick={resetFilters}
          >
            {tUsers("filters.clear") || "Clear All"}
          </button>
        </div>
      </div>

      {/* Mobile card list */}
      <div className="adminusers-layout--mobile">
        <div className="admin-users-mobile">
          {loading ? (
            <div className="admin-users-mobile__loading">{tUsers("loading")}</div>
          ) : tableError ? (
            <div className="admin-users-mobile__error">{tableError}</div>
          ) : users.length === 0 ? (
            <div className="admin-users-mobile__empty">{tUsers("noUsersFound")}</div>
          ) : (
            users.map(user => (
              <div key={user._id} className="user-card">
                <div className="user-card__header">
                  <h3 className="user-card__name">{user.name}</h3>
                  <button
                    className="user-card__delete-btn"
                    onClick={() => handleDeleteClick(user)}
                    title={tUsers("actions.deleteUser")}
                    aria-label={tUsers("actions.deleteUser")}
                    disabled={deleting}
                  >
                    <Trash2 aria-hidden="true" />
                  </button>
                </div>

                <div className="user-card__info">
                  <div className="user-card__detail">
                    <span className="user-card__label">{tUsers("table.headers.email")}:</span>
                    <span className="user-card__value">{user.email}</span>
                  </div>
                  <div className="user-card__detail">
                    <span className="user-card__label">{tUsers("table.headers.cvStatus")}:</span>
                    <div className="user-card__cv-status">
                      {renderCVStatus(user, true)}
                    </div>
                  </div>
                  <div className="user-card__detail">
                    <span className="user-card__label">{tUsers("table.headers.signedUp")}:</span>
                    <span className="user-card__value">{formatDateDDMMYYYY(user.signed_up)}</span>
                  </div>
                  <div className="user-card__detail">
                    <span className="user-card__label">{tUsers("table.headers.totalMatches")}:</span>
                    <span className="user-card__value user-card__value--matches">{user.total_matches.toLocaleString()}</span>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {/* Desktop table */}
      <div className="adminusers-layout--desktop">
        <div className="admin-users-table-container">
          {loading ? (
            <div className="admin-users-loading">{tUsers("loading")}</div>
          ) : tableError ? (
            <div className="admin-users-error">{tableError}</div>
          ) : (
            <table className="admin-users-table">
              <thead>
                <tr>
                  <SortableHeader field="name">
                    {tUsers("table.headers.name")}
                  </SortableHeader>
                  <SortableHeader field="email">
                    {tUsers("table.headers.email")}
                  </SortableHeader>
                  <SortableHeader field="cv_status">
                    {tUsers("table.headers.cvStatus")}
                  </SortableHeader>
                  <SortableHeader field="signed_up">
                    {tUsers("table.headers.signedUp")}
                  </SortableHeader>
                  <SortableHeader field="total_matches">
                    {tUsers("table.headers.totalMatches")}
                  </SortableHeader>
                  <SortableHeader field="actions" sortable={false}>
                    {tUsers("table.headers.actions")}
                  </SortableHeader>
                </tr>
              </thead>
              <tbody>
                {users.map(user => (
                  <tr key={user._id} className="admin-users-table__row">
                    <td data-label={tUsers("table.headers.name")}>{user.name}</td>
                    <td data-label={tUsers("table.headers.email")}>{user.email}</td>
                    <td data-label={tUsers("table.headers.cvStatus")}>
                      <div className="cv-status-cell">
                        {renderCVStatus(user, false)}
                      </div>
                    </td>
                    <td data-label={tUsers("table.headers.signedUp")}>{formatDateDDMMYYYY(user.signed_up)}</td>
                    <td data-label={tUsers("table.headers.totalMatches")} style={{ textAlign: "center" }}>{user.total_matches.toLocaleString()}</td>
                    <td data-label={tUsers("table.headers.actions")}>
                      <button
                        className="users-table__action-btn users-table__action-btn--delete"
                        title={tUsers("actions.deleteUser")}
                        aria-label={tUsers("actions.deleteUser")}
                        onClick={() => handleDeleteClick(user)}
                        disabled={deleting}
                      >
                        <Trash2 className="users-table__action-icon" aria-hidden="true" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>

      {/* Pagination — shared between mobile and desktop */}
      {!loading && !tableError && (
        <div className="pagination-controls">
          <div className="pagination-left" />
          <div className="pagination-right">
            <button
              onClick={goToPreviousPage}
              disabled={currentPage === 1}
              className="pagination-button"
            >
              {tPagination("pagination.previous") || "Previous"}
            </button>
            <span className="pagination-info">
              {getPageInfo()}
            </span>
            <span className="pagination-total">
              {tPagination("pagination.totalUsers", { total: totalUsers.toLocaleString() }) || `${totalUsers.toLocaleString()} total users`}
            </span>
            <button
              onClick={goToNextPage}
              disabled={currentPage === totalPages || totalPages === 0}
              className="pagination-button"
            >
              {tPagination("pagination.next") || "Next"}
            </button>
          </div>
        </div>
      )}

      {/* Modals */}
      <Modal
        key={`delete-${currentLanguage}`}
        isOpen={deleteModalOpen}
        onClose={handleDeleteCancel}
        title={tUsers("modal.deleteTitle")}
      >
        {userToDelete && (
          <div className="delete-modal__text">
            {tUsers("modal.deleteMessage", { userName: userToDelete.name })}
            {userToDelete.cv_status === "uploaded" ? tUsers("modal.deleteMessageWithCV") : ""}
            {userToDelete.total_matches > 0
              ? tUsers("modal.deleteMessageWithMatches", { matchCount: userToDelete.total_matches })
              : ""}
            ?<br />
            <span style={{ color: "red" }}>{tUsers("modal.deleteWarning")}</span>
            {deleteError && (
              <div style={{ color: "#e74c3c", marginTop: "1rem", fontWeight: 500 }}>
                {deleteError}
              </div>
            )}
            <div className="delete-modal__actions">
              <button
                className="delete-modal__cancel"
                onClick={handleDeleteCancel}
                disabled={deleting}
              >
                {tUsers("modal.cancel")}
              </button>
              <button
                className="delete-modal__delete"
                onClick={handleDeleteConfirm}
                disabled={deleting}
              >
                {deleting ? tUsers("modal.deleting") : tUsers("modal.delete")}
              </button>
            </div>
          </div>
        )}
      </Modal>
      <Modal
        key={`success-${currentLanguage}`}
        isOpen={successModalOpen}
        onClose={handleSuccessModalClose}
        title={tUsers("modal.successTitle")}
      >
        <div className="delete-modal__text">
          {tUsers("modal.successMessage")}
          <div className="delete-modal__actions" style={{ marginTop: "1rem" }}>
            <button
              className="delete-modal__close"
              onClick={handleSuccessModalClose}
            >
              {tUsers("modal.ok")}
            </button>
          </div>
        </div>
      </Modal>
      <CVPreviewModal
        key={`cv-${currentLanguage}`}
        user={selectedUserForCV}
        isOpen={cvModalOpen}
        onClose={() => setCvModalOpen(false)}
      />
      <ScrollToTop />
    </div>
  );
};

export default AdminUsers;
