import { API_BASE_URL } from "../utils/config.js";
import { apiRequest, authenticatedFetch } from "./client.js";

// ============================================================================
// DATA FETCHING ENDPOINTS
// ============================================================================

export const fetchStats = async () => apiRequest("/stats");

export const fetchCompaniesToday = async () => apiRequest("/get_companies_today");

export const fetchReportMatches = async () => apiRequest("/report_matches");

export const fetchCompanies = async () => apiRequest("/companies");

export const fetchRegions = async () => apiRequest("/regions");

export const fetchJobs = async (page = 1, limit = 20, minScore, createdAt, companyName, candidateName, job_title, job_id, match_status, region, open_text, mmr) => {
  const paramsObj = { page, limit };

  if (typeof minScore === "number") {
    paramsObj.min_score = minScore;
  }
  if (createdAt) {
    paramsObj.created_at = createdAt;
  }
  if (companyName && companyName.trim()) {
    paramsObj.company_name = companyName.trim();
  }
  if (candidateName && candidateName.trim()) {
    paramsObj.candidate_name = candidateName.trim();
  }
  if (job_title && job_title.trim()) {
    paramsObj.job_title = job_title.trim();
  }
  if (job_id && job_id.trim()) {
    paramsObj.job_id = job_id.trim();
  }
  if (match_status && match_status.trim()) {
    paramsObj.match_status = match_status.trim();
  }
  if (region && region.trim()) {
    paramsObj.regions = region.trim().replace(/,\s+/g, ",");
  }
  if (open_text && open_text.trim()) {
    paramsObj.open_text = open_text.trim();
  }
  if (mmr !== undefined && mmr !== null && mmr !== "") {
    paramsObj.mmr = mmr;
  }

  const params = new URLSearchParams(paramsObj);
  return apiRequest(`/matches2?${params}`);
};

export const fetchJobListings = async (page = 1, limit = 20, companyName, jobTitle, searchString, minDaysOld, maxDaysOld, jobId, regions, postedAfter, minRelevanceScore, mmr) => {
  const params = new URLSearchParams({ page, limit });

  if (companyName && companyName.trim()) {
    params.set("company_name", companyName.trim());
  }
  if (jobTitle && jobTitle.trim()) {
    params.set("job_title", jobTitle.trim());
  }
  if (searchString && searchString.trim()) {
    params.set("search", searchString.trim());
  }
  if (jobId && jobId.trim()) {
    params.set("job_id", jobId.trim());
  }
  if (regions && regions.trim()) {
    params.set("regions", regions.trim().replace(/,\s+/g, ","));
  }
  if (typeof minDaysOld === "number") {
    params.set("min_days_old", minDaysOld);
  }
  if (typeof maxDaysOld === "number") {
    params.set("max_days_old", maxDaysOld);
  }
  if (postedAfter && postedAfter.trim()) {
    params.set("posted_after", postedAfter.trim());
  }
  if (typeof minRelevanceScore === "number" && minRelevanceScore > 0) {
    params.set("min_relevance_score", minRelevanceScore);
  }
  if (mmr && mmr !== "") {
    params.set("mmr", mmr);
  }

  return apiRequest(`/jobs2?${params}`);
};

// ============================================================================
// DATA MUTATION ENDPOINTS
// ============================================================================

export const deleteJobAndMatches = async job_id => {
  const formData = new FormData();
  formData.append("job_id", job_id);
  const response = await authenticatedFetch(`${API_BASE_URL}/delete_job`, {
    method: "DELETE",
    body: formData
  });
  return await response.json();
};

export const fetchUsers = async (page = 1, limit = 20, search = "") => {
  const params = new URLSearchParams({
    page,
    page_size: limit,
    ...search && search.trim() && { search: search.trim() }
  });

  return apiRequest(`/users?${params}`);
};

export const deleteUser = async user_id => {
  const formData = new FormData();
  formData.append("user_id", user_id);
  const response = await authenticatedFetch(`${API_BASE_URL}/delete_user`, {
    method: "DELETE",
    body: formData
  });
  return await response.json();
};

export const setMatchSent = async (match_id, action = "sent") => {
  const formData = new FormData();
  formData.append("match_id", match_id);
  formData.append("action", action);
  const response = await authenticatedFetch(`${API_BASE_URL}/set_match_sent`, {
    method: "POST",
    body: formData
  });
  return await response.json();
};

export const setMatchRelevant = async (match_id, action = "neutral") => {
  const formData = new FormData();
  formData.append("match_id", match_id);
  formData.append("action", action);
  const response = await authenticatedFetch(`${API_BASE_URL}/set_match_relevant`, {
    method: "POST",
    body: formData
  });
  return await response.json();
};

export const unsubscribeFromEmails = async email => {
  const formData = new FormData();
  formData.append("email", email);
  const response = await authenticatedFetch(`${API_BASE_URL}/unsubscribe/`, {
    method: "POST",
    body: formData
  });
  return await response.json();
};

export const resubscribeToEmails = async email => {
  const formData = new FormData();
  formData.append("email", email);
  const response = await authenticatedFetch(`${API_BASE_URL}/resubscribe/`, {
    method: "POST",
    body: formData
  });
  return await response.json();
};

export const deleteCompanyData = async companyName => {
  const formData = new FormData();
  formData.append("company_name", companyName);
  const response = await authenticatedFetch(`${API_BASE_URL}/delete_company_data`, {
    method: "DELETE",
    body: formData
  });
  return await response.json();
};

export const getCvId = async user_id => {
  try {
    // Try the new endpoint first (will work after backend deployment)
    const response = await authenticatedFetch(`${API_BASE_URL}/get_cv_id?user_id=${user_id}`);
    return response.json();
  } catch {
    // Fallback: Try using /me endpoint with user_id parameter (works on current staging)
    try {
      const response = await authenticatedFetch(`${API_BASE_URL}/me?user_id=${user_id}`);
      const data = await response.json();
      if (data.user && data.user.cv_id) {
        return { cv_id: data.user.cv_id };
      }
      return { cv_id: null };
    } catch (fallbackError) {
      console.warn(`Could not fetch cv_id for user ${user_id}:`, fallbackError.message);
      return { cv_id: null, error: fallbackError.message };
    }
  }
};

export const uploadJobDetails = async jobData => {
  const formData = new FormData();
  for (const [key, value] of Object.entries(jobData)) {
    formData.append(key, value ?? "");
  }
  const response = await authenticatedFetch(`${API_BASE_URL}/upload_job_details`, {
    method: "POST",
    body: formData
  });
  return await response.json();
};

export const uploadCV = async file => {
  const formData = new FormData();
  formData.append("cv", file);
  const response = await authenticatedFetch(`${API_BASE_URL}/upload`, {
    method: "POST",
    body: formData
  });
  return await response.json();
};

export const updateMaxAlerts = async (maxAlerts, userId) => {
  const formData = new FormData();
  formData.append("max_num_alerts", maxAlerts);
  formData.append("user_id", userId);
  const response = await authenticatedFetch(`${API_BASE_URL}/set_max_num_alerts`, {
    method: "POST",
    body: formData
  });
  return await response.json();
};

export const updateStudentJobAlerts = async (receiveStudentJobs, userId) => {
  const formData = new FormData();
  formData.append("receive_student_jobs", String(receiveStudentJobs));
  formData.append("user_id", userId);
  const response = await authenticatedFetch(`${API_BASE_URL}/set_student_job_alerts`, {
    method: "POST",
    body: formData
  });
  return await response.json();
};

export const updateIsStudentStatus = async ({ userId, value }) => {
  const response = await authenticatedFetch(`${API_BASE_URL}/set_is_student_status`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      user_id: userId,
      value: String(value)
    })
  });
  return await response.json();
};

export const user_profile = async user_id => {
  const url = `/user_profile?user_id=${encodeURIComponent(user_id)}`;
  return apiRequest(url);
};

// Download CV with authentication support
export const downloadCVWithAuth = async cvLink => {
  if (!cvLink) {
    return;
  }

  try {
    const token = localStorage.getItem("authToken");
    const urlObj = new URL(cvLink.startsWith("http") ? cvLink : `${API_BASE_URL}${cvLink}`);
    urlObj.searchParams.set("mode", "download");

    const response = await fetch(urlObj.toString(), {
      method: "GET",
      credentials: "include",
      headers: {
        ...(token ? { Authorization: `Bearer ${token}` } : {})
      }
    });

    const isUnauthorized = response.status === 401;
    if (isUnauthorized) {
      // noinspection ExceptionCaughtLocallyJS
      throw new Error("Unauthorized");
    }
    if (!response.ok) {
      // noinspection ExceptionCaughtLocallyJS
      throw new Error(`Download failed: ${response.status}`);
    }

    const contentType = response.headers.get("Content-Type") || "application/octet-stream";

    const disposition = response.headers.get("Content-Disposition");
    let fileName = "downloaded_file";

    if (disposition && disposition.includes("filename=")) {
      const match = disposition.match(/filename=(?:"([^"]+)"|([^;]+))/);
      if (match) {
        fileName = match[1] || match[2];
      }
    }

    const blob = await response.blob();
    const typedBlob = new Blob([blob], { type: contentType });

    const url = URL.createObjectURL(typedBlob);
    const link = document.createElement("a");
    link.href = url;
    link.setAttribute("download", fileName);

    document.body.appendChild(link);
    link.click();

    setTimeout(() => {
      document.body.removeChild(link);
      URL.revokeObjectURL(url);
    }, 500);

  } catch (error) {
    console.error("Detailed Download Error:", error);
    throw error;
  }
};
