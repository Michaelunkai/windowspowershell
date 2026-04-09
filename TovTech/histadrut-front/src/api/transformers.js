import { API_BASE_URL } from "../utils/config.js";
import { AGE_THRESHOLDS, AGE_CATEGORIES } from "../utils/constants.js";

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

const formatDateDDMMYYYY = dateStr => {
  if (!dateStr) {
    return "";
  }

  const d = new Date(dateStr);
  return new Intl.DateTimeFormat("en-CA", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  }).format(d);
};

const isValidLink = link => link && link !== "No link found" && link.trim() !== "";

const getAgeCategory = daysOld => {
  if (daysOld <= AGE_THRESHOLDS.NEW) {
    return AGE_CATEGORIES.ONE_DAY;
  }
  if (daysOld <= AGE_THRESHOLDS.FRESH) {
    return AGE_CATEGORIES.TWO_TO_FIVE;
  }
  if (daysOld <= AGE_THRESHOLDS.STALE) {
    return AGE_CATEGORIES.SIX_TO_FOURTEEN;
  }
  return AGE_CATEGORIES.FIFTEEN_PLUS;
};

export const getAbsoluteUrl = path => {
  if (!path) {
    return null;
  }
  if (path.startsWith("http://") || path.startsWith("https://")) {
    return path;
  }
  return `${API_BASE_URL}${path.startsWith("/") ? "" : "/"}${path}`;
};

// ============================================================================
// DATA TRANSFORMERS
// ============================================================================

export const transformJobsData = apiResponse => {
  if (!apiResponse) {
    throw new Error("No response received from server");
  }

  if (!apiResponse.jobs) {
    throw new Error("Invalid response format: missing jobs array");
  }

  const jobs = apiResponse.jobs.map((job, index) => {
    const jobLink = (isValidLink(job.link) ? job.link : null)
      || (job.matches?.[0] && isValidLink(job.matches[0].link) ? job.matches[0].link : null)
      || null;

    return {
      id: job._id || `job-${index}`,
      jobTitle: job.job_title || "Unknown Position",
      company: job.company_name || "Unknown Company",
      region: job.region || "",
      location: job.location || "",
      dateAdded: formatDateDDMMYYYY(job.discovered),
      rawDate: job.discovered,
      jobDescription: job.job_description || "No description available",
      link: jobLink,
      matchedCandidates: (job.matches || []).map((match, matchIndex) => ({
        name: match.name || `Candidate ${matchIndex + 1}`,
        score: match.score || 0,
        status: match.job_status || "pending",
        relevance: match.job_relevant || "neutral",
        cv: !!match.cv_link,
        cvLink: match.cv_link ? getAbsoluteUrl(match.cv_link) : null,
        mmr: match.mandatory_req ? "YES" : "NO",
        _metadata: {
          matchId: match._id,
          candidateId: match.ID_candiate,
          coverLetter: match.cover_letter,
          createdAt: match.created_at,
          overview: match.overall_overview,
          strengths: match.strengths || [],
          weaknesses: match.weeknesses || []
        }
      })),
      job_id: job.job_id || ""
    };
  });

  const totalPages = Math.max(1, apiResponse.pagination?.total_pages ?? 1);
  const totalJobs = Math.max(0, apiResponse.pagination?.total_items ?? 0);

  return {
    jobs,
    pagination: {
      currentPage: apiResponse.pagination?.current_page ?? 1,
      totalPages,
      totalJobs
    }
  };
};

export const transformJobListingsData = apiResponse => {
  if (!apiResponse) {
    throw new Error("No response received from server");
  }

  if (!Array.isArray(apiResponse.jobs)) {
    return {
      jobs: [],
      pagination: { totalJobs: 0, totalPages: 1, currentPage: 1, pageSize: 0 }
    };
  }

  const jobs = apiResponse.jobs.map((job, index) => {
    const daysAgo = job.days_old || 0;

    return {
      id: job.id || job.job_id || `job-${index}`,
      job_id: job.job_id || `job-${index}`,
      title: job.job_title || "Unknown Position",
      company: job.company_name || "Unknown Company",
      posted: formatDateDDMMYYYY(job.posted) || formatDateDDMMYYYY(new Date().toISOString()),
      age: `${daysAgo} days`,
      daysOld: daysAgo,
      ageCategory: getAgeCategory(daysAgo),
      ageDisplay: `${daysAgo} days`,
      job_description: job.job_description || "",
      field: job.field || "",
      position_link: job.position_link || "",
      location: job.location || "",
      region: job.region || ""
    };
  });

  const pagination = {
    totalJobs: apiResponse.pagination?.total_jobs || apiResponse.pagination?.total_items || jobs.length,
    totalPages: apiResponse.pagination?.total_pages || 1,
    currentPage: apiResponse.pagination?.current_page || 1,
    pageSize: apiResponse.pagination?.page_size || jobs.length
  };

  return { jobs, pagination };
};

// ============================================================================
// USERS DATA TRANSFORMER (NEW - for useUsersData hook)
// ============================================================================

export const transformUsersData = apiResponse => {
  if (!apiResponse) {
    throw new Error("No response received from server");
  }

  const rawUsers = apiResponse.users || [];
  if (!Array.isArray(rawUsers)) {
    return {
      users: [],
      pagination: { totalUsers: 0, totalPages: 1 }
    };
  }

  const users = rawUsers.map(user => ({
    _id: user._id || user.id,
    name: user.name || "Unknown User",
    email: user.email || "",
    cv_status: user.cv_status || "missing",
    signed_up: user.signed_up || "",       // Already formatted by backend
    total_matches: parseInt(user.total_matches || 0, 10),
    cv_id: user.cv_id || null
  }));

  const pagination = apiResponse.pagination || {};

  return {
    users,
    pagination: {
      totalPages: Math.max(1, pagination.total_pages || 1),
      totalUsers: Math.max(0, pagination.total_users || rawUsers.length)
    }
  };
};

export const transformStatsData = apiResponse => ({
  candidates: apiResponse.Number_of_candidtes ?? 0,
  jobs: apiResponse.Number_of_jobs ?? 0,
  jobsLastDay: apiResponse.Number_of_jobs_last_day ?? 0,
  jobsLastWeek: apiResponse.Number_of_jobs_last_week ?? 0,
  matches: apiResponse.Number_of_matches ?? 0
});

export const transformCompaniesData = apiResponse => {
  return Object.entries(apiResponse).map(([companyName, jobsCount], index) => ({
    id: index + 1,
    name: companyName,
    jobsCount: jobsCount || 0
  }));
};

export { formatDateDDMMYYYY };
