import { API_BASE_URL } from "../utils/config.js";
import { authenticatedFetch } from "./client.js";
import { getAbsoluteUrl } from "./transformers.js";

// ============================================================================
// AUTHENTICATION ENDPOINTS
// ============================================================================

export const loginUser = async (email, password, rememberMe = false) => {
  const formData = new FormData();
  formData.append("email", email);
  formData.append("password", password);
  if (rememberMe) {
    formData.append("remember", "true");
  }
  const response = await fetch(`${API_BASE_URL}/login`, {
    method: "POST",
    credentials: "include",
    body: formData
  });
  const data = await response.json().catch(() => ({}));
  return { status: response.status, data };
};

export const registerUser = async (email, password, name, subscribe = true) => {
  const formData = new FormData();
  formData.append("email", email);
  formData.append("password", password);
  formData.append("name", name);
  formData.append("subscribe", subscribe);

  const response = await fetch(`${API_BASE_URL}/register`, {
    method: "POST",
    body: formData
  });
  const data = await response.json().catch(() => ({}));
  return { status: response.status, data };
};

export const resetPassword = async email => {
  const body = new URLSearchParams();
  body.append("email", email);
  const response = await fetch(`${API_BASE_URL}/reset_password`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString()
  });
  if (!response.ok) {
    throw new Error("Failed to send reset email");
  }
  return response.json();
};

export const setNewPassword = async (token, password, confirmPassword) => {
  const body = new URLSearchParams();
  body.append("password", password);
  body.append("confirm_password", confirmPassword);
  const response = await fetch(`${API_BASE_URL}/reset_password/${encodeURIComponent(token)}`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString()
  });
  if (!response.ok) {
    throw new Error("Failed to set new password");
  }
  return response.json();
};

export const fetchUserFromSession = async () => {
  try {
    const res = await authenticatedFetch(`${API_BASE_URL}/me`);
    const data = await res.json();
    if (data && data.user && data.user.email && data.user.role) {
      const userObject = {
        email: data.user.email,
        role: data.user.role,
        name: data.user.name,
        id: data.user.id,
        cv_status: data.user.cv_status,
        cv_id: data.user.cv_id,
        cv_link: (data.user.cv_link && data.user.cv_link !== "NA") ? getAbsoluteUrl(data.user.cv_link) : null,
        subscribed: data.user.subscribed === true || data.user.subscribed === "true",
        receive_student_jobs: data.user.receive_student_jobs === true || data.user.receive_student_jobs === "true",
        max_alerts: typeof data.user.max_num_alerts === "number" ? data.user.max_num_alerts : 5
      };
      return userObject;
    }
    return null;
  } catch {
    return null;
  }
};

export const backendLogout = async () => {
  try {
    const response = await fetch(`${API_BASE_URL}/logout`, {
      method: "GET",
      credentials: "include"
    });
    if (!response.ok) {
      throw new Error(`Logout failed: ${response.status}`);
    }
    return { success: true };
  } catch (error) {
    console.error("Backend logout error:", error);
    throw error;
  }
};
