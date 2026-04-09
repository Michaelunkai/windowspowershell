# TovTech Matcher Frontend

## Overview

Candidate-facing React application where TovTech members can upload CVs, view job matches, and manage their profile. This is the primary user interface for the Internal Matcher system.

**Note**: Current working name is "TovTech Matcher" - naming to be revisited.

## Production

- **URL**: https://app.tovtech.org
- **Login URL**: https://app.tovtech.org/login
- **Deployment**: Cloudflare

### Repository Information

- **Repository**: https://github.com/TovTechOrg/histadrut-front.git
- **Active Branch**: `production` (production deployment)

## Staging

- **URL**: https://staging.tovtech.org/

### Repository Information

- **Repository**: https://github.com/TovTechOrg/histadrut-front
- **Active Branch**: `staging`

## Technical Stack

- **Framework**: React (19.1.0)
- **Build Tool**: Vite (7.0.0)
- **Routing**: React Router DOM (7.6.3)
- **Charts**: Highcharts (12.3.0) with highcharts-react-official (3.2.2)
- **Icons**: Lucide React (0.562.0)
- **Emoji**: React Twemoji (0.6.0)
- **Deployment**: Cloudflare (automatic from GitHub)
- **Backend API**: CV-Scout (api.tovtech.org)

### Local Configuration

To run locally, edit `src/utils/config.js`:

```javascript
// Uncomment for local development:
export const API_BASE_URL = "http://127.0.0.1:5000";
```

## Key Features

1. **CV Upload**: Members upload their resume/CV
2. **Match Viewing**: View all matches (good and not-good)
3. **Job Browsing**: Browse available jobs
4. **Profile Management**: Manage candidate profile
5. **Email Notifications**: Receive match notifications

## Operations

### Deployment Process

- Automatic deployment via Cloudflare Pages
- Production deploys from `production` branch
- Staging deploys from `staging` branch

### Making Changes

1. Make changes in staging branch
2. Test at https://staging.tovtech.org/
3. Merge to `production` for production
4. Cloudflare automatically deploys


## Planned Improvements

- [ ] **Analytics**: Add Google Analytics to track user behavior and identify where users get stuck
- [ ] **Dashboard Team**: Orad to build dashboard to display analytics
- [ ] **React to Svelte**: Aviahy interested in converting from React to Svelte
- [ ] **Knowledge Transfer**: Star to lead React knowledge transfer to new devs

## To-Do

- [ ] Add Google Analytics
- [ ] Create comprehensive README
- [ ] Document local development setup
- [ ] Document environment variables
- [ ] Document API endpoints used from backend

## Team

- **Primary Owner**: _[To be assigned]_
- **Secondary (Shadow)**: _[To be assigned]_
- **React Lead**: Star
- **Svelte Exploration**: Aviahy


_Last Updated: Feb 4, 2026_
