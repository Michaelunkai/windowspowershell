import { useState, useEffect, useMemo, useCallback } from "react";
import { useSearchParams } from "react-router-dom";

import { fetchJobListings, transformJobListingsData } from "../api";
import { DEBOUNCE_TIMEOUT, DEFAULT_PAGE_SIZE, AGE_CATEGORIES } from "../utils/constants";
import { useDebounce } from "./useDebounce";
import { useSorting } from "./useSorting";

// Custom hook for managing job listings data with server-side filtering and pagination
export const useJobsData = () => {
  const [searchParams, setSearchParams] = useSearchParams();

  const [jobs, setJobs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [totalPages, setTotalPages] = useState(1);
  const [totalJobs, setTotalJobs] = useState(0);

  // Use custom sorting hook
  const { sortField, sortDirection, handleSort: handleSortFromHook, sortData } = useSorting();

  // Local state for input values (for immediate UI updates)
  const [localJobTitle, setLocalJobTitle] = useState(searchParams.get("jobTitleTerm") || "");
  const [localJobDescription, setLocalJobDescription] = useState(searchParams.get("jobDescriptionTerm") || "");
  const [localJobId, setLocalJobId] = useState(searchParams.get("job_id") || "");
  const [localLimit, setLocalLimit] = useState(parseInt(searchParams.get("limit")) || DEFAULT_PAGE_SIZE);
  const [localPostedAfter, setLocalPostedAfter] = useState(searchParams.get("postedAfter") || "");
  const [localMinRelevanceScore, setLocalMinRelevanceScore] = useState(parseFloat(searchParams.get("minRelevanceScore")) || 0);
  const [localMMR, setLocalMMR] = useState(searchParams.get("mmr") || "");

  // Get company filter from URL parameter for backwards compatibility
  const companyFromUrl = searchParams.get("company");

  // Always derive filters from searchParams
  const filters = useMemo(() => {
    const params = Object.fromEntries([...searchParams]);
    return {
      jobTitleTerm: params.jobTitleTerm || "",
      jobDescriptionTerm: params.jobDescriptionTerm || "",
      job_id: params.job_id || "",
      selectedCompany: params.selectedCompany || companyFromUrl || "",
      selectedStatus: params.selectedStatus || AGE_CATEGORIES.ALL,
      selectedRegions: params.selectedRegions || "",
      postedAfter: params.postedAfter || "",
      minRelevanceScore: params.minRelevanceScore ? parseFloat(params.minRelevanceScore) : 0,
      mmr: params.mmr || "",
      limit: parseInt(params.limit) || DEFAULT_PAGE_SIZE
    };
  }, [searchParams, companyFromUrl]);

  // Ensure filters is always defined before using it
  const safeFilters = filters || {
    jobTitleTerm: "",
    jobDescriptionTerm: "",
    job_id: "",
    selectedCompany: "",
    selectedStatus: AGE_CATEGORIES.ALL,
    selectedRegions: "",
    postedAfter: "",
    minRelevanceScore: 0,
    mmr: "",
    limit: DEFAULT_PAGE_SIZE
  };

  const currentPage = parseInt(searchParams.get("page") || "1", 10);

  // Debounced function to update URL parameters
  const debouncedSetParam = useDebounce((field, value) => {
    setSearchParams(prev => {
      const params = new URLSearchParams(prev);
      if (value && value !== "") {
        params.set(field, value);
      } else {
        params.delete(field);
      }
      // Remove all empty params
      for (const key of Array.from(params.keys())) {
        if (!params.get(key)) {
          params.delete(key);
        }
      }
      // Always reset page to 1 on filter change
      params.set("page", "1");
      return params;
    });
  }, DEBOUNCE_TIMEOUT);

  // Helper function to parse age category into min/max days
  const parseAgeCategory = ageCategory => {
    if (!ageCategory || ageCategory === AGE_CATEGORIES.ALL) {
      return { minDaysOld: null, maxDaysOld: null };
    }

    // Parse different age formats
    if (ageCategory === AGE_CATEGORIES.ONE_DAY) {
      return { minDaysOld: 0, maxDaysOld: 1 };
    } else if (ageCategory === AGE_CATEGORIES.TWO_TO_FIVE) {
      return { minDaysOld: 2, maxDaysOld: 5 };
    } else if (ageCategory === AGE_CATEGORIES.SIX_TO_FOURTEEN) {
      return { minDaysOld: 6, maxDaysOld: 14 };
    } else if (ageCategory === AGE_CATEGORIES.FIFTEEN_PLUS) {
      return { minDaysOld: 15, maxDaysOld: null };
    }

    return { minDaysOld: null, maxDaysOld: null };
  };

  const loadJobs = useCallback(async (page, limit, companyName, jobTitle, searchString, selectedStatus, jobId, regions, postedAfter, minRelevanceScore, mmr) => {
    try {
      setLoading(true);
      setError(null);

      const { minDaysOld, maxDaysOld } = parseAgeCategory(selectedStatus);

      const apiResponse = await fetchJobListings(
        page,
        limit,
        companyName,
        jobTitle,
        searchString,
        minDaysOld,
        maxDaysOld,
        jobId,
        regions,
        postedAfter,
        minRelevanceScore,
        mmr
      );

      if (!apiResponse) {
        setError("No response received from server");
        setJobs([]);
        setTotalPages(1);
        setTotalJobs(0);
        return;
      }

      const { jobs: jobsData, pagination } = transformJobListingsData(apiResponse);
      setJobs(jobsData);
      setTotalPages(pagination.totalPages);
      setTotalJobs(pagination.totalJobs);
    } catch (err) {
      setError(err.message || "Failed to load jobs. Please try again later.");
      setJobs([]);
      setTotalPages(1);
      setTotalJobs(0);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadJobs(
      currentPage,
      safeFilters.limit,
      safeFilters.selectedCompany,
      safeFilters.jobTitleTerm,
      safeFilters.jobDescriptionTerm,
      safeFilters.selectedStatus,
      safeFilters.job_id,
      safeFilters.selectedRegions,
      safeFilters.postedAfter,
      safeFilters.minRelevanceScore,
      safeFilters.mmr
    );
  }, [
    loadJobs,
    currentPage,
    safeFilters.limit,
    safeFilters.selectedCompany,
    safeFilters.jobTitleTerm,
    safeFilters.jobDescriptionTerm,
    safeFilters.selectedStatus,
    safeFilters.job_id,
    safeFilters.selectedRegions,
    safeFilters.postedAfter,
    safeFilters.minRelevanceScore,
    safeFilters.mmr
  ]);

  const goToPage = page => {
    const clamped = Math.max(1, Math.min(page, totalPages));
    setSearchParams({ ...Object.fromEntries([...searchParams]), page: clamped.toString() });
  };

  const goToNextPage = () => {
    if (currentPage < totalPages) {
      goToPage(currentPage + 1);
    }
  };

  const goToPreviousPage = () => {
    if (currentPage > 1) {
      goToPage(currentPage - 1);
    }
  };

  // Update filters by updating the URL search params
  const updateFilters = newFilters => {
    const params = { ...Object.fromEntries([...searchParams]), ...newFilters, page: "1" };
    // Remove empty params to keep URLs clean
    Object.keys(params).forEach(key => {
      if (params[key] === "" || params[key] === null || params[key] === undefined) {
        delete params[key];
      }
    });
    setSearchParams(params);
  };

  // Sync local state with URL params if they change externally
  useEffect(() => {
    setLocalJobTitle(searchParams.get("jobTitleTerm") || "");
    setLocalJobDescription(searchParams.get("jobDescriptionTerm") || "");
    setLocalJobId(searchParams.get("job_id") || "");
    setLocalLimit(parseInt(searchParams.get("limit")) || DEFAULT_PAGE_SIZE);
    setLocalPostedAfter(searchParams.get("postedAfter") || "");
    setLocalMinRelevanceScore(parseFloat(searchParams.get("minRelevanceScore")) || 0);
    setLocalMMR(searchParams.get("mmr") || "");
  }, [searchParams]);

  // Get unique companies and statuses for filter dropdowns from current data
  const companies = useMemo(() => {
    if (!Array.isArray(jobs) || jobs.length === 0) {
      return [];
    }

    // noinspection UnnecessaryLocalVariableJS
    const uniqueCompanies = jobs
      .map(job => job.company)
      .filter(company => company && company.trim())
      .filter((company, index, arr) => arr.indexOf(company) === index);

    return uniqueCompanies;
  }, [jobs]);

  const statuses = useMemo(() => [
    AGE_CATEGORIES.ALL,
    AGE_CATEGORIES.ONE_DAY,
    AGE_CATEGORIES.TWO_TO_FIVE,
    AGE_CATEGORIES.SIX_TO_FOURTEEN,
    AGE_CATEGORIES.FIFTEEN_PLUS
  ], []);

  // Event handlers for backwards compatibility
  const handleJobTitleChange = term => {
    setLocalJobTitle(term);
    debouncedSetParam("jobTitleTerm", term);
  };

  const handleJobDescriptionChange = term => {
    setLocalJobDescription(term);
    debouncedSetParam("jobDescriptionTerm", term);
  };

  const handleJobIdChange = term => {
    setLocalJobId(term);
    debouncedSetParam("job_id", term);
  };

  const handleCompanyChange = company => {
    updateFilters({ selectedCompany: company });
  };

  const handleStatusChange = status => {
    updateFilters({ selectedStatus: status });
  };

  const handleRegionsChange = regions => {
    updateFilters({ selectedRegions: regions });
  };

  const handlePostedAfterChange = date => {
    setLocalPostedAfter(date);
    updateFilters({ postedAfter: date });
  };

  const handleMinRelevanceScoreChange = score => {
    setLocalMinRelevanceScore(score);
    updateFilters({ minRelevanceScore: score });
  };

  const handleMMRChange = mmr => {
    setLocalMMR(mmr);
    updateFilters({ mmr });
  };

  const handleLimitChange = limit => {
    setLocalLimit(limit);
    updateFilters({ limit: limit });
  };

  // Alias for handleSort to maintain backward compatibility
  const handleSort = handleSortFromHook;

  const resetFilters = () => {
    setSearchParams({ page: "1" });
  };

  // Field mapping for date fields that need special handling
  const fieldMapping = {
    posted: "posted",
    date_posted: "posted",
    region: "region",
    location: "location"
  };

  // All filtering is now handled by the backend, apply sorting client-side using custom hook
  const filteredJobs = sortData(jobs, fieldMapping);

  return {
    // Data
    jobs,
    filteredJobs,
    loading,
    error,
    companies,
    statuses,

    // Pagination
    currentPage,
    totalPages,
    totalJobs,
    goToPage,
    goToNextPage,
    goToPreviousPage,

    // Filter state (for backwards compatibility)
    jobTitleTerm: localJobTitle,
    jobDescriptionTerm: localJobDescription,
    jobIdTerm: localJobId,
    selectedCompany: safeFilters.selectedCompany,
    selectedStatus: safeFilters.selectedStatus,
    selectedRegions: safeFilters.selectedRegions,
    postedAfter: localPostedAfter,
    minRelevanceScore: localMinRelevanceScore,
    mmr: localMMR,

    // Sorting state
    sortField,
    sortDirection,

    // Event handlers
    handleJobTitleChange,
    handleJobDescriptionChange,
    handleJobIdChange,
    handleCompanyChange,
    handleStatusChange,
    handleRegionsChange,
    handlePostedAfterChange,
    handleMinRelevanceScoreChange,
    handleMMRChange,
    handleLimitChange,
    handleSort,
    resetFilters,
    updateFilters,

    // Filters object for direct access
    filters: {
      ...safeFilters,
      limit: localLimit
    }
  };
};
