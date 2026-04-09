import React, { createContext, useState, useEffect } from "react";

import { loginUser, registerUser, fetchUserFromSession, backendLogout } from "../api";

const AuthContext = createContext();

const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  // Check for existing login token on mount
  useEffect(() => {
    const userData = localStorage.getItem("userData");

    if (userData) {
      try {
        const parsedUser = JSON.parse(userData);
        setUser(parsedUser);
        setLoading(false);
        return;
      } catch {
        localStorage.removeItem("userData");
      }
    }

    // If no user in localStorage, try to fetch from backend session (cookie)
    fetchUserFromSession().then(userFromSession => {
      if (userFromSession) {
        // Omit role if not admin or demo
        const userToStore =
          userFromSession.role === "admin" || userFromSession.role === "demo"
            ? userFromSession
            : { ...userFromSession, role: undefined };
        setUser(userToStore);
        localStorage.setItem("userData", JSON.stringify(userToStore));
      }
      setLoading(false);
    });
  }, []);

  const isKnownRole = role => ["admin", "demo", "user"].includes(role);

  function saveUserToStorage(data) {
    const userData = {
      id: data.id,
      name: data.name,
      email: data.email,
      role: isKnownRole(data.role)? data.role : undefined
    };
    setUser(userData);
    localStorage.setItem("userData", JSON.stringify(userData));
  }

  const login = async (email, password, rememberMe = false) => {
    try {
      const result = await loginUser(email, password, rememberMe);

      // result: { status, data }
      if (result.status === 200 && result.data?.user_authenticated) {
        // Use user data from login response (includes JWT token)
        saveUserToStorage(result.data);

        // Return the full user data including role for redirect logic
        return {
          status: 200,
          data: {
            user_authenticated: true,
            role: result.data.role
          }
        };
      }
      return result;
    } catch (err) {
      return {
        status: undefined,
        data: { message: err.message || "Login failed" }
      };
    }
  };

  const signUp = async (email, password, name, subscribed = true) => {
    try {
      const result = await registerUser(email, password, name || "", subscribed);
      // If registration is successful, try to log in immediately
      if (result.status === 200 || result.status === 201) {
        // Attempt login with the same credentials (will get JWT token)
        const loginResult = await loginUser(email, password);
        if (loginResult.status === 200 && loginResult.data?.user_authenticated) {
          // Use user data from login response
          saveUserToStorage(loginResult.data);

        }
      }
      return result;
    } catch (err) {
      return {
        status: undefined,
        data: { message: err.message || "Registration failed" }
      };
    }
  };

  const logout = async () => {
    try {
      // Try to logout from backend (clear server-side session/cookie)
      await backendLogout();
    } catch (error) {
      console.warn("Backend logout failed:", error);
      // Continue with local cleanup even if backend fails
    }

    // Clear all user-related localStorage data
    localStorage.removeItem("userData");
    // Clean up any existing remember me data (if it exists from before)
    localStorage.removeItem("rememberMe");
    localStorage.removeItem("rememberedEmail");
    localStorage.removeItem("rememberedPassword"); // Clean up any existing stored passwords

    // Try to clear any non-HTTP-only cookies (limited effectiveness)
    // Note: HTTP-only cookies can only be cleared by the backend
    try {
      // Clear common cookie names that might be used for sessions
      const cookiesToClear = ["session", "sessionid", "token", "auth", "jwt"];
      cookiesToClear.forEach(cookieName => {
        document.cookie = `${cookieName}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/;`;
        document.cookie = `${cookieName}=; expires=Thu, 01 Jan 1970 00:00:00 UTC; path=/; domain=${window.location.hostname};`;
      });
    } catch (error) {
      console.warn("Cookie clearing failed:", error);
    }

    // Clear user state
    setUser(null);
  };

  const isAuthenticated = () => {
    return !!user;
  };

  const isAdmin = () => {
    return user?.role === "admin";
  };

  const isAdminOrDemo = () => {
    return user?.role === "admin" || user?.role === "demo";
  };

  const value = {
    user,
    setUser,
    login,
    signUp,
    logout,
    isAuthenticated,
    isAdmin,
    isAdminOrDemo,
    loading
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export { AuthContext, AuthProvider };
