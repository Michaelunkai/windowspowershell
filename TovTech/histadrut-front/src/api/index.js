// Re-export everything from the modular API files for backward compatibility
export {
  loginUser,
  registerUser,
  resetPassword,
  setNewPassword,
  fetchUserFromSession,
  backendLogout
} from "./auth.js";

export {
  fetchStats,
  fetchCompaniesToday,
  fetchReportMatches,
  fetchCompanies,
  fetchRegions,
  fetchJobs,
  fetchJobListings,
  deleteJobAndMatches,
  fetchUsers,
  deleteUser,
  setMatchSent,
  setMatchRelevant,
  unsubscribeFromEmails,
  resubscribeToEmails,
  deleteCompanyData,
  uploadJobDetails,
  uploadCV,
  updateMaxAlerts,
  updateStudentJobAlerts,
  updateIsStudentStatus,
  getCvId,
  user_profile,
  downloadCVWithAuth
} from "./services.js";

export {
  transformJobsData,
  transformJobListingsData,
  transformStatsData,
  transformCompaniesData
} from "./transformers.js";
