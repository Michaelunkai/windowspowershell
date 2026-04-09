import React from "react";
import { Navigate } from "react-router-dom";

import { useAuth } from "../../hooks/useAuth";

const ProtectedRoute = ({ children, requireAdmin = false }) => {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <div
        style={{
          display: "flex",
          justifyContent: "center",
          alignItems: "center",
          minHeight: "100vh",
          fontSize: "1.1rem",
          color: "#666"
        }}
      >
        Loading...
      </div>
    );
  }

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  if (requireAdmin && user.role !== "admin" && user.role !== "demo") {
    return <Navigate to="/login" replace />;
  }

  return children;
};

export default ProtectedRoute;
