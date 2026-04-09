# Demo User Role Implementation Summary

## Overview
Added support for a new "demo" user role that behaves like an admin user everywhere in the application EXCEPT on the matches page, where they see the user view with demo data instead of real backend data.

## Changes Made

### 1. AuthContext (`src/contexts/AuthContext.jsx`)
- Updated to preserve "demo" role during authentication (alongside "admin" role)
- Added new helper function `isAdminOrDemo()` to check if user is admin OR demo
- Modified `login()`, `signUp()`, and session initialization to store demo role
- Exported `isAdminOrDemo` in the context value

### 2. Navigation Panel (`src/components/NavPanel/NavPanel.jsx`)
- Updated to use `isAdminOrDemo()` helper
- Demo users now see admin navigation options

### 3. Protected Routes (`src/components/Auth/ProtectedRoute.jsx`)
- Updated to allow "demo" users to access admin-required routes
- Changed condition: `user.role !== "admin" && user.role !== "demo"`

### 4. Job Listings (`src/components/JobsListings/JobsListings.jsx`)
- Updated to use `isAdminOrDemo()` helper
- Demo users see admin view of job listings

### 5. Companies Pages
- **Companies.jsx**: Updated to use `isAdminOrDemo()` helper
- **CompaniesMobile.jsx**: Updated to use `isAdminOrDemo()` helper
- Demo users see admin view of companies

### 6. Profile Page (`src/components/Profile.jsx`)
- Updated to treat demo users like admins
- Hides CV upload section for demo users
- Hides email subscription section for demo users
- Demo users don't need to manage their profile like regular users

### 7. Matches Page (`src/components/Matches/Matches.jsx`)
- **IMPORTANT**: Only checks for `role === 'admin'` (NOT demo)
- Demo users see the subtitle for admins but use MatchesTableUser component
- Demo users get the user experience on the matches page

### 8. Matches Data Hook (`src/hooks/useMatchesData.js`)
- Added import for `useAuth` hook
- Added import for `getDemoMatchesData` function
- Checks if user is demo (`isDemoUser`)
- When demo user, returns demo data instead of making API calls
- Real users still fetch data from backend

### 9. Demo Data File (`src/data/demoMatchesData.js`)
- **NEW FILE**: Created structure for demo matches data
- Includes `demoMatchesData` object with empty jobs array
- Includes `getDemoMatchesData()` helper function to apply filters
- **TODO**: Populate with actual demo data later

## How It Works

1. **Authentication**: Backend assigns role "demo" to demo users
2. **Most Pages**: Use `isAdminOrDemo()` to check permissions → demo users get admin view
3. **Matches Page Exception**: Explicitly checks only for "admin" role → demo users get user view
4. **Demo Data**: When demo user loads matches, `useMatchesData` hook returns demo data from `demoMatchesData.js` instead of calling backend API

## Next Steps

### To populate demo data:
1. Open `src/data/demoMatchesData.js`
2. Add demo job objects to the `jobs` array in `demoMatchesData`
3. Each job should follow this structure:
   ```javascript
   {
     id: "demo-1",
     job_id: "DEMO-001",
     jobTitle: "Software Engineer",
     company: "Tech Corp",
     location: "Tel Aviv",
     dateAdded: "2025-12-10",
     link: "https://example.com/job",
     matchedCandidates: [{
       name: "Demo Candidate",
       score: "8.5",
       cv: true,
       cvLink: "https://example.com/cv",
       mmr: "YES",
       relevance: "neutral",
       status: "pending",
       _metadata: { matchId: "demo-match-1" }
     }]
   }
   ```
4. Update `totalJobs` and `totalPages` accordingly
5. Optionally implement filtering logic in `getDemoMatchesData()`

## Testing Checklist

- [ ] Demo user can log in
- [ ] Demo user sees admin navigation panel
- [ ] Demo user can access Job Listings (admin view)
- [ ] Demo user can access Companies (admin view)
- [ ] Demo user can access Reporting (admin view)
- [ ] Demo user can access Users/Admin page
- [ ] Demo user sees user view on Matches page
- [ ] Demo user sees demo data on Matches page (not real backend data)
- [ ] Demo user doesn't see CV upload section in Profile
- [ ] Demo user doesn't see email subscription section in Profile
- [ ] Regular users still work as before
- [ ] Admin users still work as before
