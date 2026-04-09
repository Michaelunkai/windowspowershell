import { useRef, useCallback, useEffect } from "react";

/**
 * Custom hook for debouncing function calls
 * The function will only execute after the specified delay has passed since the last call
 * @param {Function} callback - The function to debounce
 * @param {number} delay - The delay in milliseconds to wait after the last call
 * @returns {Function} - The debounced function
 */
export function useDebounce(callback, delay) {
  const timeoutRef = useRef(null);

  // Cleanup timeout on unmount
  useEffect(() => {
    return () => {
      if (timeoutRef.current) {
        clearTimeout(timeoutRef.current);
      }
    };
  }, []);

  return useCallback((...args) => {
    // Clear the previous timeout if it exists
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
    }

    // Set a new timeout
    timeoutRef.current = setTimeout(() => {
      callback(...args);
    }, delay);
  }, [callback, delay]);
}
