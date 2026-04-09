import { useState, useCallback } from "react";
import { useSearchParams } from "react-router-dom";

import { SORT_DIRECTION } from "../utils/constants";

/**
 * Custom hook for managing three-state sorting (desc → asc → none)
 * @param {string|null} initialField - Initial sort field from URL params
 * @param {string} initialDirection - Initial sort direction from URL params
 * @returns {Object} - Object with sortField, sortDirection, handleSort, and sortData functions
 */
export const useSorting = (initialField = null, initialDirection = SORT_DIRECTION.ASC) => {
  const [searchParams, setSearchParams] = useSearchParams();
  const [sortField, setSortField] = useState(initialField || searchParams.get("sortField") || null);
  const [sortDirection, setSortDirection] = useState(initialDirection || searchParams.get("sortDirection") || SORT_DIRECTION.ASC);

  /**
   * Handle sorting column click
   * Cycles through: desc → asc → none → desc
   */
  const handleSort = useCallback(field => {
    let newSortField = field;
    let newSortDirection = SORT_DIRECTION.DESC;

    // Three-state sorting
    if (sortField === field) {
      // Same field clicked
      if (sortDirection === SORT_DIRECTION.DESC) {
        newSortDirection = SORT_DIRECTION.ASC;
      } else if (sortDirection === SORT_DIRECTION.ASC) {
        // Reset to no sorting
        newSortField = null;
        newSortDirection = SORT_DIRECTION.DESC;
      }
    }

    setSortField(newSortField);
    setSortDirection(newSortDirection);

    // Update URL parameters
    setSearchParams(prev => {
      const params = new URLSearchParams(prev);
      if (newSortField) {
        params.set("sortField", newSortField);
        params.set("sortDirection", newSortDirection);
      } else {
        params.delete("sortField");
        params.delete("sortDirection");
      }
      return params;
    });
  }, [sortField, sortDirection, setSearchParams]);

  /**
   * Generic sorting function for arrays
   * @param {Array} data - Array to sort
   * @param {Object} fieldMapping - Optional mapping of field names to object properties
   * @returns {Array} - Sorted array
   */
  const sortData = useCallback((data, fieldMapping = {}) => {
    if (!sortField || !sortDirection || !Array.isArray(data)) {
      return data;
    }

    return [...data].sort((a, b) => {
      // Get the actual field name from mapping or use as-is
      const mapping = fieldMapping[sortField];

      let aValue, bValue;

      if (typeof mapping === "function") {
        aValue = mapping(a);
        bValue = mapping(b);
      } else {
        const actualField = mapping || sortField;
        aValue = a[actualField];
        bValue = b[actualField];
      }

      // Handle null/undefined values
      if (aValue == null) {
        aValue = "";
      }
      if (bValue == null) {
        bValue = "";
      }

      // Type-specific comparisons
      if (typeof aValue === "number" && typeof bValue === "number") {
        return sortDirection === SORT_DIRECTION.ASC ? aValue - bValue : bValue - aValue;
      }

      if (aValue instanceof Date && bValue instanceof Date) {
        return sortDirection === SORT_DIRECTION.ASC
          ? aValue.getTime() - bValue.getTime()
          : bValue.getTime() - aValue.getTime();
      }

      // String comparison (case-insensitive)
      const aStr = String(aValue).toLowerCase();
      const bStr = String(bValue).toLowerCase();

      if (sortDirection === SORT_DIRECTION.ASC) {
        return aStr < bStr ? -1 : aStr > bStr ? 1 : 0;
      } else {
        return aStr > bStr ? -1 : aStr < bStr ? 1 : 0;
      }
    });
  }, [sortField, sortDirection]);

  return {
    sortField,
    sortDirection,
    handleSort,
    sortData
  };
};
