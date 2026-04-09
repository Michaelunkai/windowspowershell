import { API_BASE_URL } from "../utils/config.js";

// ============================================================================
// CUSTOM ERROR CLASSES
// ============================================================================

class SessionExpiredError extends Error {
  constructor(message = "Session expired. Please log in again.") {
    super(message);
    this.name = "SessionExpiredError";
    this.isSessionError = true;
  }
}

class ValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = "ValidationError";
    this.isValidationError = true;
  }
}

class NetworkError extends Error {
  constructor(message) {
    super(message);
    this.name = "NetworkError";
    this.isNetworkError = true;
  }
}

// ============================================================================
// SESSION MANAGEMENT
// ============================================================================

let isHandlingSessionExpiration = false;

const handleSessionExpired = () => {
  if (isHandlingSessionExpiration) {
    return;
  }

  isHandlingSessionExpiration = true;

  // Check if there was an actual user session before marking as expired
  const userData = localStorage.getItem("userData");

  // If no user data exists, this is not a session expiration - just no session
  // Don't set sessionExpired flag for first-time visitors
  if (!userData) {
    isHandlingSessionExpiration = false;
    return;
  }

  // Only proceed with session expiration handling if user was logged in
  localStorage.removeItem("userData");
  localStorage.setItem("sessionExpired", "true");

  // Dispatch custom event for React app to handle UI
  window.dispatchEvent(new CustomEvent("session-expired"));

  // Reset flag after a delay
  setTimeout(() => {
    isHandlingSessionExpiration = false;
  }, 100);
};

// ============================================================================
// HTTP CLIENT
// ============================================================================

export const authenticatedFetch = async (url, options = {}) => {
  const defaultOptions = {
    credentials: "include",
    headers: {
      ...options.headers
    }
  };

  const finalOptions = { ...defaultOptions, ...options };

  try {
    const response = await fetch(url, finalOptions);

    if (response.status === 401) {
      handleSessionExpired();
      throw new SessionExpiredError();
    }

    if (response.status === 400) {
      const error = await response.json().catch(() => ({ error: "Validation failed" }));
      throw new ValidationError(error.error || error.message || "Validation failed");
    }

    if (response.status === 403) {
      const error = await response.json().catch(() => ({ error: "Access forbidden" }));
      throw new ValidationError(error.error || error.message || "You don't have permission to perform this action");
    }

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: `Request failed with status ${response.status}` }));
      throw new Error(error.error || error.message || `Request failed with status ${response.status}`);
    }

    return response;
  } catch (error) {
    if (error instanceof SessionExpiredError || error instanceof ValidationError || error instanceof NetworkError) {
      throw error;
    }

    if (error.message.includes("fetch") || error.message.includes("network") || error.message.includes("Failed to fetch")) {
      throw new NetworkError("Network error. Please check your connection.");
    }

    throw error;
  }
};

// Helper wrapper for JSON API requests
export const apiRequest = async (endpoint, options = {}) => {
  const response = await authenticatedFetch(`${API_BASE_URL}${endpoint}`, {
    headers: { "Content-Type": "application/json", ...options.headers },
    ...options
  });
  return await response.json();
};
