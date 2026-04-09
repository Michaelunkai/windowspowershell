import { useState, useEffect, useMemo, useCallback } from "react";
import { useSearchParams } from "react-router-dom";

import { fetchJobs, transformJobsData } from "../api";
import { injectDemoMatchesIntoJobs } from "../data/demoMatchesData";
import { DEFAULT_PAGE_SIZE, DEFAULT_MIN_RELEVANCE_SCORE } from "../utils/constants";
import { useAuth } from "./useAuth";
import { useSorting } from "./useSorting";

// Custom hook for managing matches data and filtering

export const useMatchesData = () => {
  const [jobsData, setJobsData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [lastFetch, setLastFetch] = useState(null);
  const [totalPages, setTotalPages] = useState(1);
  const [totalJobs, setTotalJobs] = useState(0);

  const [searchParams, setSearchParams] = useSearchParams();
  const { user } = useAuth();
  const isDemoUser = user?.role === "demo";

  // Use custom sorting hook
  const { sortField, sortDirection, handleSort, sortData } = useSorting();

  // Always derive filters from searchParams
  const filters = useMemo(() => {
    const params = Object.fromEntries([...searchParams]);
    return {
      openSearch: params.openSearch || "",
      // Accept snake_case `company_name` but fall back to legacy `companyName`
      companyName: params.company_name || params.companyName || "",
      job_title: params.job_title || "",
      candidateName: params.candidateName || "",
      addedSince: params.addedSince || "",
      minRelevanceScore: params.minRelevanceScore ? parseFloat(params.minRelevanceScore) : DEFAULT_MIN_RELEVANCE_SCORE,
      job_id: params.job_id || "",
      match_status: params.match_status || "",
      region: params.regions || params.locations || "",
      mmr: params.mmr || "",
      limit: parseInt(params.limit) || DEFAULT_PAGE_SIZE
    };
  }, [searchParams]);

  const currentPage = parseInt(searchParams.get("page") || "1", 10);

  const loadJobs = useCallback(async (page, limit, minScore, createdAt, companyName, candidateName, job_title, job_id, match_status, region, openSearch, mmr) => {
    try {
      setLoading(true);
      setError(null);

      let apiResponse = await fetchJobs(page, limit, minScore, createdAt, companyName, candidateName, job_title, job_id, match_status, region, openSearch, mmr);

      // If response is empty or missing jobs key, prompt user to upload CV
      if (!apiResponse || !apiResponse.jobs) {
        setError("No jobs found. Please upload your CV to get matches.");
        setJobsData([]);
        setTotalPages(1);
        setLastFetch(new Date());
        return;
      }

      // If user is demo, inject demo matches into the response
      if (isDemoUser) {
        apiResponse = injectDemoMatchesIntoJobs(apiResponse);
      }

      const { jobs, pagination } = transformJobsData(apiResponse);
      setJobsData(jobs);
      setTotalPages(pagination.totalPages);
      setTotalJobs(pagination.totalJobs || 0);
      setLastFetch(new Date());
    } catch {
      setError("Failed to load jobs. Please try again later.");
      setJobsData([]);
      setTotalPages(1);
      setTotalJobs(0);
    } finally {
      setLoading(false);
    }
  }, [isDemoUser]);

  // Helper function to format date to MM-DD-YYYY
  const formatDateForAPI = dateString => {
    if (!dateString) {
      return null;
    }
    const date = new Date(dateString);
    if (isNaN(date.getTime())) {
      return null;
    }

    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    const year = date.getFullYear();

    return `${month}-${day}-${year}`;
  };

  useEffect(() => {
    const formattedDate = formatDateForAPI(filters.addedSince);
    loadJobs(
      currentPage,
      filters.limit,
      filters.minRelevanceScore,
      formattedDate,
      filters.companyName,
      filters.candidateName,
      filters.job_title,
      filters.job_id,
      filters.match_status,
      filters.region,
      filters.openSearch,
      filters.mmr
    );
  }, [
    loadJobs,
    currentPage,
    filters.limit,
    filters.minRelevanceScore,
    filters.addedSince,
    filters.companyName,
    filters.candidateName,
    filters.job_title,
    filters.job_id,
    filters.match_status,
    filters.region,
    filters.openSearch,
    filters.mmr
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
  const updateFilters = useCallback(newFilters => {
    setSearchParams(prev => {
      const current = Object.fromEntries([...prev]);
      return { ...current, ...newFilters, page: "1" };
    });
  }, [setSearchParams]);

  const handleLimitChange = useCallback(limit => {
    updateFilters({ limit: limit });
  }, [updateFilters]);

  // Field mapping for sorting (maps UI field names to data property names)
  const fieldMapping = {
    job_id: "id",
    job_title: "jobTitle",
    company: "company",
    region: "region",
    location: "location",
    dateAdded: job => new Date(job.rawDate),
    score: job => {
      const score = job.matchedCandidates?.[0]?.score;
      return score ? parseFloat(score) : 0;
    }
  };

  // Apply sorting to the jobs data using the custom hook
  const filteredJobs = sortData(jobsData, fieldMapping);

  return {
    jobsData,
    filteredJobs,
    loading,
    error,
    filters,
    updateFilters,
    handleLimitChange,
    lastFetch,
    currentPage,
    totalPages,
    totalJobs,
    goToNextPage,
    goToPreviousPage,
    sortField,
    sortDirection,
    handleSort
  };
};
