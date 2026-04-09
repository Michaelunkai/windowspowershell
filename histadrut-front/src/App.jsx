import { useEffect, useState } from "react";
import {
  BrowserRouter as Router,
  Routes,
  Route,
  Navigate
} from "react-router-dom";

import "./App.css";
import AdminUsers from "./components/Auth/AdminUsers";
import CVUpload from "./components/Auth/CVUpload";
import Login from "./components/Auth/Login";
import NewPasswordPage from "./components/Auth/NewPasswordPage";
import ProtectedRoute from "./components/Auth/ProtectedRoute";
import SignUp from "./components/Auth/SignUp";
import Companies from "./components/Companies/Companies";
import AddJob from "./components/JobsListings/AddJob";
import JobsListings from "./components/JobsListings/JobsListings";
import Matches from "./components/Matches/Matches";
import NavPanel from "./components/NavPanel/NavPanel";
import Overview from "./components/Overview/Overview";
import Profile from "./components/Profile";
import Reporting from "./components/Reporting/Reporting";
import LanguagePicker from "./components/shared/LanguagePicker";
import SessionExpiredModal from "./components/shared/SessionExpiredModal";
import { AuthProvider } from "./contexts/AuthContext";
import { LanguageProvider, useLanguage } from "./contexts/LanguageContext";
import { ViewportProvider } from "./contexts/ViewportContext";
import "./components/shared/Page.css";
import "./components/JobsListings/JobForm.css";

const ProtectedPage = ({ children, requireAdmin = false }) => {
  const { currentLanguage } = useLanguage();

  return (
    <ProtectedRoute requireAdmin={requireAdmin}>
      <NavPanel key={currentLanguage} />
      <main className="main-content">
        {children}
      </main>
    </ProtectedRoute>
  );
};

function App() {
  const [showSessionModal, setShowSessionModal] = useState(false);

  useEffect(() => {
    const handleSessionExpired = () => {
      setShowSessionModal(true);
    };

    window.addEventListener("session-expired", handleSessionExpired);
    return () => window.removeEventListener("session-expired", handleSessionExpired);
  }, []);

  const handleSessionModalConfirm = () => {
    setShowSessionModal(false);
    window.location.href = "/login";
  };

  return (
    <LanguageProvider>
      <AuthProvider>
        <ViewportProvider>
          <Router>
            <div className="app">
              <LanguagePicker size="small" position="top-right" />
              {showSessionModal && (
                <SessionExpiredModal onConfirm={handleSessionModalConfirm} />
              )}
              <Routes>
                {/* Public routes */}
                <Route path="/login" element={<Login />} />
                <Route path="/signup" element={<SignUp />} />
                <Route path="/reset_password/:token" element={<NewPasswordPage />} />
                {/* Protected routes */}
                <Route
                  path="/cv-upload"
                  element={
                    <ProtectedRoute>
                      <CVUpload />
                    </ProtectedRoute>
                  }
                />
                {/* User protected routes */}
                <Route
                  path="/profile"
                  element={
                    <ProtectedPage>
                      <Profile />
                    </ProtectedPage>
                  }
                />
                <Route
                  path="/user/matches"
                  element={
                    <ProtectedPage>
                      <Matches />
                    </ProtectedPage>
                  }
                />
                {/* Redirect old routes */}
                <Route
                  path="/matches"
                  element={<Navigate to="/user/matches" replace />}
                />
                <Route
                  path="/jobs"
                  element={<Navigate to="/jobs-listings" replace />}
                />
                {/* Admin protected routes */}
                <Route
                  path="/"
                  element={
                    <ProtectedPage requireAdmin>
                      <Overview />
                    </ProtectedPage>
                  }
                />
                <Route
                  path="/overview"
                  element={
                    <ProtectedPage requireAdmin>
                      <Overview />
                    </ProtectedPage>
                  }
                />
                <Route
                  path="/jobs-listings"
                  element={
                    <ProtectedPage>
                      <JobsListings />
                    </ProtectedPage>
                  }
                />
                <Route
                  path="/jobs/add"
                  element={
                    <ProtectedPage>
                      <AddJob />
                    </ProtectedPage>
                  }
                />
                <Route
                  path="/companies"
                  element={
                    <ProtectedPage>
                      <Companies />
                    </ProtectedPage>
                  }
                />
                <Route
                  path="/reporting"
                  element={
                    <ProtectedPage>
                      <Reporting />
                    </ProtectedPage>
                  }
                />
                <Route
                  path="/admin/matches"
                  element={
                    <ProtectedPage requireAdmin>
                      <Matches />
                    </ProtectedPage>
                  }
                />
                <Route
                  path="/admin/users"
                  element={
                    <ProtectedPage requireAdmin>
                      <AdminUsers />
                    </ProtectedPage>
                  }
                />
              </Routes>
            </div>
          </Router>
        </ViewportProvider>
      </AuthProvider>
    </LanguageProvider>
  );
}

export default App;
