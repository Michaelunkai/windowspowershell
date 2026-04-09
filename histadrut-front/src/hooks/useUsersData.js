import { useState, useEffect, useMemo, useCallback } from "react";
import { useSearchParams } from "react-router-dom";

import { fetchUsers, getCvId } from "../api";
import { transformUsersData } from "../api/transformers"; // Add transformUsersData like for jobs
import { DEBOUNCE_TIMEOUT, DEFAULT_PAGE_SIZE } from "../utils/constants"; // Reuse from jobs
import { useDebounce } from "./useDebounce";
import { useSorting } from "./useSorting";

// Custom hook for managing users data with server-side filtering and pagination (like useJobsData)
export const useUsersData = () => {
  const [searchParams, setSearchParams] = useSearchParams();

  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [totalPages, setTotalPages] = useState(1);
  const [totalUsers, setTotalUsers] = useState(0);

  // Use custom sorting hook (like jobs)
  const { sortField, sortDirection, handleSort: handleSortFromHook, sortData } = useSorting();

  // Local state for input values (immediate UI updates)
  const [localSearchTerm, setLocalSearchTerm] = useState(searchParams.get("search") || "");
  const [localLimit, setLocalLimit] = useState(parseInt(searchParams.get("limit")) || DEFAULT_PAGE_SIZE);

  // Derive filters from searchParams (like jobs)
  const filters = useMemo(() => {
    const params = Object.fromEntries([...searchParams]);
    return {
      search: params.search || "",
      limit: parseInt(params.limit) || DEFAULT_PAGE_SIZE
      // Add more filters here if backend supports (e.g., cvStatus: params.cvStatus || "")
    };
  }, [searchParams]);

  // Safe filters fallback (like jobs)
  const safeFilters = filters || {
    search: "",
    limit: DEFAULT_PAGE_SIZE
  };

  const currentPage = parseInt(searchParams.get("page") || "1", 10);

  // Debounced URL param updates (like jobs)
  const debouncedSetParam = useDebounce((field, value) => {
    setSearchParams(prev => {
      const params = new URLSearchParams(prev);
      if (value && value !== "") {
        params.set(field, value);
      } else {
        params.delete(field);
      }
      // Clean empty params
      for (const key of Array.from(params.keys())) {
        if (!params.get(key)) {
          params.delete(key);
        }
      }
      // Reset page to 1 on filter change
      params.set("page", "1");
      return params;
    });
  }, DEBOUNCE_TIMEOUT);

  // Load users (server-side, like loadJobs)
  const loadUsers = useCallback(async (page, limit, searchTerm) => {
    try {
      setLoading(true);
      setError(null);

      const apiResponse = await fetchUsers(page, limit, searchTerm); // Updated API call

      if (!apiResponse) {
        setError("No response received from server");
        setUsers([]);
        setTotalPages(1);
        setTotalUsers(0);
        return;
      }

      const { users: usersData, pagination } = transformUsersData(apiResponse); // Add this transformer

      // Enrichment (like before; keep async post-fetch)
      // usersData = await enrichUsersWithCvIds(usersData); // Uncomment when ready

      setUsers(usersData);
      setTotalPages(pagination.totalPages);
      setTotalUsers(pagination.totalUsers || pagination.totalJobs || 0); // Flexible for backend
    } catch (err) {
      setError(err.message || "Failed to load users. Please try again later.");
      setUsers([]);
      setTotalPages(1);
      setTotalUsers(0);
    } finally {
      setLoading(false);
    }
  }, []);

  // Fetch on filter/page changes (like jobs)
  useEffect(() => {
    loadUsers(
      currentPage,
      safeFilters.limit,
      safeFilters.search
    );
  }, [loadUsers, currentPage, safeFilters.limit, safeFilters.search]);

  // Pagination handlers (like jobs)
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

  // Update filters via URL (like jobs)
  const updateFilters = newFilters => {
    setSearchParams({ ...Object.fromEntries([...searchParams]), ...newFilters, page: "1" });
  };

  // Sync local state with URL (like jobs)
  useEffect(() => {
    setLocalSearchTerm(searchParams.get("search") || "");
    setLocalLimit(parseInt(searchParams.get("limit")) || DEFAULT_PAGE_SIZE);
  }, [searchParams]);

  // Event handlers (backwards compatible)
  const handleSearch = term => {
    setLocalSearchTerm(term);
    debouncedSetParam("search", term);
  };

  const handleLimitChange = limit => {
    setLocalLimit(limit);
    updateFilters({ limit });
  };

  // Alias for backwards compatibility
  const handleSort = handleSortFromHook;

  const resetFilters = () => {
    setSearchParams({ page: "1" });
  };

  // User-specific field mapping for sorting (like jobs)
  const fieldMapping = {
    name: "name",
    email: "email",
    cv_status: "cv_status",
    signed_up: "signed_up",
    total_matches: "total_matches"
  };

  // Client-side sort (no backend sorting assumed; like jobs)
  const filteredUsers = sortData(users, fieldMapping);

  // Re-add enrichUsersWithCvIds here if needed (as a util function)
  // But since server-side now, enrichment can run post-fetch in loadUsers.

  return {
    // Data (like jobs)
    users,
    filteredUsers, // Sorted
    loading,
    error,

    // Pagination
    currentPage,
    totalPages,
    totalUsers,
    goToPage,
    goToNextPage,
    goToPreviousPage,

    // Filter state (backwards compatible)
    searchTerm: localSearchTerm,
    selectedLimit: safeFilters.limit, // Or localLimit

    // Sorting state
    sortField,
    sortDirection,

    // Event handlers (backwards compatible)
    handleSearch,
    handleLimitChange,
    handleSort,
    resetFilters,
    updateFilters,
    refreshUsers: loadUsers, // Backwards compatible

    // Filters object
    filters: {
      ...safeFilters,
      limit: localLimit
    }
  };
};
