import { useState, useEffect, useCallback } from "react";
import { useSearchParams } from "react-router-dom";

import { fetchCompanies, transformCompaniesData } from "../api";
import { useSorting } from "./useSorting";

// Custom hook for managing companies data with sorting and search
export const useCompaniesData = () => {
  const [companiesData, setCompaniesData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [lastFetch, setLastFetch] = useState(null);

  const [searchParams, setSearchParams] = useSearchParams();

  // Use custom sorting hook
  const { sortField, sortDirection, handleSort, sortData } = useSorting();

  // Search state
  const [searchTerm, setSearchTerm] = useState(searchParams.get("search") || "");

  const loadCompanies = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);

      const apiResponse = await fetchCompanies();
      const companies = transformCompaniesData(apiResponse);

      setCompaniesData(companies);
      setLastFetch(new Date());
    } catch (err) {
      console.error("Error loading companies:", err);
      setError("Failed to load companies. Please try again later.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadCompanies();
  }, [loadCompanies]);

  // Search functionality
  const handleSearch = term => {
    setSearchTerm(term);

    // Update URL params
    const params = { ...Object.fromEntries([...searchParams]) };
    if (term.trim()) {
      params.search = term;
    } else {
      delete params.search;
    }
    setSearchParams(params);
  };

  // Filter companies based on search term
  const filteredCompanies = companiesData.filter(company => {
    if (!searchTerm.trim()) {
      return true;
    }

    const searchLower = searchTerm.toLowerCase();
    const name = (company.name || "").toLowerCase();

    return name.includes(searchLower);
  });

  // Apply sorting to the filtered data using custom hook
  const sortedCompanies = sortData(filteredCompanies);

  return {
    companiesData,
    sortedCompanies,
    loading,
    error,
    lastFetch,
    sortField,
    sortDirection,
    handleSort,
    searchTerm,
    handleSearch,
    refetch: loadCompanies
  };
};
