// Translation strings for the application
const translations = {
  // TODO: make sure all the code uses the common.pagination one instead of the others per page
  // Login page
  login: {
    en: {
      title: "Login",
      subtitle: "Manage your CVs and view your matched jobs",
      emailLabel: "Email",
      passwordLabel: "Password",
      loginButton: "Login",
      rememberMe: "Remember Me",
      forgotPassword: "Forgot Password?",
      showPassword: "Show password",
      hidePassword: "Hide password",
      signUpPrompt: "Don't have an account?",
      signUpLink: "Sign Up",
      resetPasswordTitle: "Reset Password",
      cookieWarning: "⚠️ This site requires third-party cookies to log in. Please enable them in your browser settings.",
      cookieBlockedTitle: "Third-Party Cookies Required",
      cookieBlockedMessage: "We need permission to use cookies for secure authentication. Click 'Allow' to grant access, or enable third-party cookies manually in your browser settings.",
      cookieAllowButton: "Allow Cookies",
      cookieCancelButton: "Cancel",
      cookieManualInstructions: "Please enable third-party cookies manually in your browser settings:\n\nChrome: Settings → Privacy and security → Third-party cookies → Allow\nFirefox: Settings → Privacy & Security → Custom → Cookies → Allow\nSafari: Settings → Privacy → Uncheck 'Block all cookies'",
      cookieManualTitle: "Manual Setup Required",
      cookieManualDescription: "Your browser is blocking cookies via a manual setting (Hard Block). We cannot fix this automatically.",
      cookieManualStep1: "Click the Eye/Lock icon in your address bar",
      cookieManualStep2: "Turn OFF 'Third-party cookies blocked'",
      cookieManualStep3: "Click the button below to try logging in again",
      cookieManualRetryButton: "I Fixed It - Try Again",
      errors: {
        loginFailed: "Login failed",
        userNotFound: "User or password not found. Please check your credentials.",
        genericError: "An error occurred. Please try again.",
        sessionExpired: "Your session has expired. Please log in again."
      }
    },
    he: {
      title: "התחברות",
      subtitle: "נהל את קורות החיים שלך וצפה במשרות המותאמות לך",
      emailLabel: "אימייל",
      passwordLabel: "סיסמה",
      loginButton: "התחבר",
      rememberMe: "זכור אותי",
      forgotPassword: "שכחת סיסמה?",
      showPassword: "הצג סיסמה",
      hidePassword: "הסתר סיסמה",
      signUpPrompt: "אין לך חשבון?",
      signUpLink: "הירשם",
      resetPasswordTitle: "איפוס סיסמה",
      cookieWarning: "⚠️ אתר זה דורש קובצי Cookie מצד שלישי כדי להתחבר. אנא אפשר אותם בהגדרות הדפדפן שלך.",
      cookieBlockedTitle: "נדרשים קובצי Cookie מצד שלישי",
      cookieBlockedMessage: "אנחנו צריכים הרשאה להשתמש בקובצי Cookie לאימות מאובטח. לחץ על 'אפשר' כדי לתת הרשאה, או אפשר קובצי Cookie מצד שלישי באופן ידני בהגדרות הדפדפן.",
      cookieAllowButton: "אפשר קובצי Cookie",
      cookieCancelButton: "ביטול",
      cookieManualInstructions: "אנא אפשר קובצי Cookie מצד שלישי באופן ידני בהגדרות הדפדפן:\n\nChrome: הגדרות → פרטיות ואבטחה → קובצי Cookie של צד שלישי → אפשר\nFirefox: הגדרות → פרטיות ואבטחה → מותאם אישית → קובצי Cookie → אפשר\nSafari: הגדרות → פרטיות → בטל את הסימון 'חסום את כל קובצי ה-Cookie'",
      cookieManualTitle: "נדרשת הגדרה ידנית",
      cookieManualDescription: "הדפדפן שלך חוסם קובצי Cookie באמצעות הגדרה ידנית. איננו יכולים לתקן זאת באופן אוטומטי.",
      cookieManualStep1: "לחץ על אייקון העין/המנעול בשורת הכתובת",
      cookieManualStep2: "כבה את 'קובצי Cookie של צד שלישי חסומים'",
      cookieManualStep3: "לחץ על הכפתור למטה כדי לנסות להתחבר שוב",
      cookieManualRetryButton: "תיקנתי - נסה שוב",
      errors: {
        loginFailed: "ההתחברות נכשלה",
        userNotFound: "משתמש או סיסמה לא נמצאו. אנא בדוק את הפרטים שלך.",
        genericError: "אירעה שגיאה. אנא נסה שוב.",
        sessionExpired: "תוקף הסשן שלך פג. אנא התחבר שוב."
      }
    }
  },

  // Navigation panel
  navigation: {
    en: {
      title: "Navigation",
      welcome: "Welcome",
      overview: "Overview",
      users: "Users",
      jobsListings: "Jobs Listings",
      jobMatches: "Job Matches",
      companies: "Companies",
      reporting: "Reporting",
      profile: "Profile",
      logout: "Logout",
      expandNav: "Expand navigation",
      collapseNav: "Collapse navigation",
      openNav: "Open navigation"
    },
    he: {
      title: "ניווט",
      welcome: "ברוך הבא",
      overview: "סקירה כללית",
      users: "משתמשים",
      jobsListings: "רשימת משרות",
      jobMatches: "התאמות משרות",
      companies: "חברות",
      reporting: "דוחות",
      profile: "פרופיל",
      logout: "התנתק",
      expandNav: "הרחב ניווט",
      collapseNav: "כווץ ניווט",
      openNav: "פתח ניווט"
    }
  },

  // Profile page
  profile: {
    en: {
      title: "Profile",
      downloadCV: "Download CV",
      uploadCV: "Upload CV",
      reUploadCV: "Re-upload CV",
      subscribeEmails: "Subscribe to email notifications",
      unsubscribeEmails: "Unsubscribe from email notifications",
      noCV: "No CV available to download.",
      emailSubscriptionStatus: "You are currently {status} to receive job matches via email.",
      subscribed: "subscribed",
      unsubscribed: "unsubscribed",
      doNotWishEmails: "I do not wish to receive job matches via email",
      wishToReceiveEmails: "I wish to receive job match alerts via email",
      unsubscribe: "Unsubscribe",
      subscribe: "Subscribe",
      unsubscribeSuccess: "You have been unsubscribed from job offer emails.",
      subscribeSuccess: "You have been subscribed to job offer emails.",
      unsubscribeFailed: "Failed to unsubscribe. Please try again.",
      subscribeFailed: "Failed to subscribe. Please try again.",
      email: "Email",
      role: "Role",
      cvStatus: "CV Status",
      welcome: "Welcome",
      language: "Language",
      maxAlerts: "I want to get <b>up to</b>",
      maxAlertsEachDay: "alerts each day",
      saveChanges: "Save Changes",
      alertPreferences: "Alert preferences",
      alertToggleKeyboardHint: "Press Space to toggle this switch.",
      studentAlertsRequiresEmail: "Enable job match alerts first to turn on student job alerts.",
      dismissFeedback: "Dismiss feedback message",
      maxAlertsUpdated: "Max alerts updated successfully!",
      maxAlertsUpdateFailed: "Failed to update max alerts. Please try again.",
      receiveStudentJobAlerts: "I wish to receive student job alerts",
      studentJobAlertsUpdated: "Student job alerts preference updated successfully!",
      studentJobAlertsUpdateFailed: "Failed to update student job alerts preference. Please try again.",
      downloading: "Preparing download...",
      downloadError: "Could not download CV. Session may have expired.",
      professional_info: {
        title: "Professional Snapshot",
        subtitle: "Derrived from your CV analysis",
        has_degree: "Has degree",
        is_student: "Is student",
        fields_of_expertise: "Fields of Expertise",
        years_of_experience: "Experience",
        yes: "Yes",
        no: "No",
        experience_time_unit: "year(s)"
      }
    },
    he: {
      title: "פרופיל",
      downloadCV: "הורדת קורות חיים",
      uploadCV: "העלאת קורות חיים",
      reUploadCV: "העלאת קורות חיים מחדש",
      subscribeEmails: "הרשמה להודעות אימייל",
      unsubscribeEmails: "ביטול הרשמה להודעות אימייל",
      noCV: "אין קורות חיים זמינים להורדה.",
      emailSubscriptionStatus: "אתה כרגע {status} לקבל התאמות עבודה באמצעות אימייל.",
      subscribed: "רשום",
      unsubscribed: "לא רשום",
      doNotWishEmails: "אני לא רוצה לקבל התאמות עבודה באמצעות אימייל",
      wishToReceiveEmails: "אני מעוניין לקבל התראות התאמות עבודה באימייל",
      unsubscribe: "בטל הרשמה",
      subscribe: "הירשם",
      unsubscribeSuccess: "בוטלה ההרשמה שלך לקבלת הצעות עבודה באימייל.",
      subscribeSuccess: "נרשמת לקבלת הצעות עבודה באימייל.",
      unsubscribeFailed: "ביטול ההרשמה נכשל. אנא נסה שוב.",
      subscribeFailed: "ההרשמה נכשלה. אנא נסה שוב.",
      email: "אימייל",
      role: "תפקיד",
      cvStatus: "סטטוס קורות חיים",
      welcome: "ברוך הבא",
      language: "שפה",
      maxAlerts: "אני רוצה לקבל <b>עד</b>",
      maxAlertsEachDay: "התראות בכל יום",
      saveChanges: "שמור שינויים",
      alertPreferences: "העדפות התראות",
      alertToggleKeyboardHint: "לחצו על מקש הרווח כדי להחליף את מצב המתג.",
      studentAlertsRequiresEmail: "יש להפעיל תחילה התראות התאמות עבודה כדי להפעיל התראות למשרות סטודנט.",
      dismissFeedback: "סגירת הודעת המשוב",
      maxAlertsUpdated: "מספר ההתראות המקסימלי עודכן בהצלחה!",
      maxAlertsUpdateFailed: "עדכון מספר ההתראות המקסימלי נכשל. אנא נסה שוב.",
      receiveStudentJobAlerts: "אני מעוניין לקבל התראות למשרות סטודנט",
      studentJobAlertsUpdated: "העדפת ההתראות למשרות סטודנט עודכנה בהצלחה!",
      studentJobAlertsUpdateFailed: "עדכון העדפת ההתראות למשרות סטודנט נכשל. אנא נסה שוב.",
      downloading: "מכין הורדה...",
      downloadError: "לא ניתן להוריד את הקובץ. ייתכן שהחיבור פקע.",
      professional_info: {
        title: "המידע המקצועי שלך",
        subtitle: "נלקח מקורות החיים שלך", // Or: "מבוסס על קורות החיים שלך"
        has_degree: "בעל תואר אקדמי",
        is_student: "סטודנט", // "סטודנט כעת" is also fine, but "סטודנט" is cleaner
        fields_of_expertise: "תחומי התמחות",
        years_of_experience: "ניסיון",
        yes: "כן",
        no: "לא",
        experience_time_unit: "שנים"
      }
    }
  },

  // Overview/Dashboard
  overview: {
    en: {
      title: "Dashboard Overview",
      totalActiveJobs: "Total Active Jobs",
      totalCandidates: "Total Candidates",
      totalMatches: "Total Matches",
      jobsAddedLastDay: "Jobs Added Last Day",
      jobsAddedLastWeek: "Jobs Added Last Week",
      newJobsByCompanyToday: "New Jobs by Company Today",
      loadingStats: "Loading statistics...",
      errorLoadingStats: "Error loading stats"
    },
    he: {
      title: "סקירת לוח בקרה",
      totalActiveJobs: "סה\"כ משרות פעילות",
      totalCandidates: "סה\"כ מועמדים",
      totalMatches: "סה\"כ התאמות",
      jobsAddedLastDay: "משרות שנוספו אתמול",
      jobsAddedLastWeek: "משרות שנוספו השבוע",
      newJobsByCompanyToday: "משרות חדשות לפי חברה היום",
      loadingStats: "טוען סטטיסטיקות...",
      errorLoadingStats: "שגיאה בטעינת סטטיסטיקות"
    }
  },

  // CVUpload page
  cvUpload: {
    en: {
      title: "Find Your Perfect Job Match",
      subtitle: "Upload your resume to instantly discover jobs that match your skills",
      description: "Once you upload your CV, our algorithm checks relevant job openings. If a suitable job is found, you'll receive a personalized email, every day, starting tomorrow.",
      startingTomorrow: "starting tomorrow",
      uploadYourResume: "Upload Your Resume",
      dragAndDropInstructions: "Drag and drop your resume here or",
      clickToBrowse: "click to browse",
      supportedFormats: "Supported formats: PDF, DOCX • English or Hebrew CVs • Up to 1MB",
      remove: "Remove",
      back: "← Back",
      uploadLater: "Upload Later",
      uploadButton: "Upload Resume",
      uploading: "Uploading...",
      successTitle: "CV Uploaded Successfully!",
      successMessage: "Your resume was uploaded. We'll notify you if a match is found.",
      okButton: "OK",
      errors: {
        invalidFileType: "Please upload a PDF or Word document.",
        noFileSelected: "Please select a file to upload.",
        uploadError: "An error occurred while uploading your CV."
      }
    },
    he: {
      title: "מצא את ההתאמה המושלמת לעבודה",
      subtitle: "העלה את קורות החיים שלך כדי לגלות מיד עבודות שמתאימות לכישורים שלך",
      description: "ברגע שתעלה את קורות החיים שלך, האלגוריתם שלנו בודק משרות רלוונטיות. אם נמצאת עבודה מתאימה, תקבל אימייל אישי, כל יום, החל ממחר.",
      startingTomorrow: "החל ממחר",
      uploadYourResume: "העלה קורות חיים",
      dragAndDropInstructions: "גרור ושחרר את קורות החיים שלך כאן או",
      clickToBrowse: "לחץ לעיון",
      supportedFormats: "פורמטים נתמכים: PDF, DOCX • קורות חיים באנגלית או עברית • עד 1MB",
      remove: "הסר",
      back: "חזור ←",
      uploadLater: "העלה מאוחר יותר",
      uploadButton: "העלה קורות חיים",
      uploading: "מעלה...",
      successTitle: "קורות החיים הועלו בהצלחה!",
      successMessage: "קורות החיים שלך הועלו. נודיע לך אם נמצאה התאמה.",
      okButton: "אישור",
      errors: {
        invalidFileType: "אנא העלה מסמך PDF או Word.",
        noFileSelected: "אנא בחר קובץ להעלאה.",
        uploadError: "אירעה שגיאה בהעלאת קורות החיים שלך."
      }
    }
  },

  // Matches page
  matches: {
    en: {
      title: "Job Match Dashboard",
      subtitle: "Aggregated view of manually sourced jobs and matched candidates.",
      subtitleUser: "Explore job matches found for you! See your compatibility scores and understand the reasoning behind each match.\nProvide feedback on our assessments and track which positions you've applied to.",
      demoWarning: "Demo Mode: You are currently watching non-real candidates over real jobs",
      demoCVDownloadTitle: "Demo Mode - CV Download",
      demoCVDownloadMessage: "This button would download the candidate's CV if this were a real candidate.",
      filtersTitle: "Filters",
      showFilters: "Show Filters",
      hideFilters: "Hide Filters",
      viewCandidates: "View Candidates",
      hideCandidates: "Hide Candidates",
      showDetails: "Show Details",
      hideDetails: "Hide Details",
      pagination: {
        previous: "← Previous",
        next: "Next →",
        pageInfo: "Page {current} of {total}",
        totalJobs: "Total: {total} jobs",
        showLabel: "Show",
        jobsPerPage: "jobs per page",
        pageSize20: "20",
        pageSize50: "50",
        pageSize100: "100"
      },
      filters: {
        openSearch: "Open Search",
        openSearchPlaceholder: "e.g., python, react, machine learning",
        companyName: "Company Name",
        companyNamePlaceholder: "e.g., Example Tech",
        jobTitle: "Job Title",
        jobTitlePlaceholder: "e.g., Backend Developer",
        candidateName: "Candidate Name",
        candidateNamePlaceholder: "e.g., Shy",
        jobId: "Job ID",
        jobIdPlaceholder: "e.g., 12345",
        appliedStatus: "Applied Status",
        allStatuses: "All Statuses",
        pending: "Pending",
        sent: "Sent",
        appliedStatusHelp: "View the matches you have applied for",
        appliedStatusHelpAdmin: "View the matches candidates have applied for",
        meetingMMR: "Meets Mandatory Requirements",
        allMMR: "All",
        positiveMMR: "Yes",
        negativeMMR: "No",
        postedAfter: "Posted after",
        postedAfterHelp: "Show jobs posted after this date",
        minRelevanceScore: "Min. Relevance Score ({score})",
        scoreRange: ["0", "10"],
        regions: "Regions",
        regionsPlaceholder: "e.g., {examples}",
        locations: "Locations",
        locationsPlaceholder: "e.g., Tel Aviv, Jerusalem, Haifa",
        region: "Region",
        regionPlaceholder: "e.g., {examples}",
        location: "Location",
        locationPlaceholder: "e.g., Tel Aviv, Haifa",
        clear: "Clear",
        clearAll: "Clear All",
        applyFilters: "Apply"
      },
      table: {
        headers: {
          jobId: "Job ID",
          jobTitle: "Job Title",
          company: "Company",
          dateAdded: "Date Added",
          linkToJob: "Link to Job",
          matchedCandidates: "Matched Candidates",
          candidateName: "Candidate Name",
          score: "Score",
          matchScore: "Match Score",
          showDetailedReport: "Show Detailed Report",
          cv: "CV",
          downloadCV: "Download CV",
          mmr: "Meets Mandatory Requirements",
          candidateMeetingMMR: "Meets Mandatory Requirements",
          meetsMandatoryReq: "Meets Mandatory Req.",
          appliedStatus: "Applied Status",
          relevant: "Relevant?",
          wasMatchRelevant: "Was the match relevant?",
          region: "Region",
          location: "Location",
          actions: ""
        },
        tooltips: {
          mmr: "Meets Mandatory Requirements - (Does the candidate/Do you) meet ALL mandatory requirements for this job?",
          relevant: "(Each candidate can mark if the job was relevant for them/Tell us if this Job was relevant for you.)",
          appliedStatus: "Did (the candidate/you) send (their/your) CV to this job?"
        },
        noMatches: "No matches yet! If you've recently uploaded your CV, please check back in 1-2 days. Our algorithm is working to find the perfect job matches for you.",
        noMatchesFiltered: "No jobs match the current filters.",
        loading: "Loading matches...",
        viewJob: "View job description",
        viewCandidate: "View candidate details",
        markAsSent: "Mark as sent",
        markAsPending: "Mark as pending",
        downloadCV: "Download CV",
        downloadCVFor: "Download CV for {name}",
        viewDetails: "View Details",
        showDetailedReport: "Show Detailed Report",
        cvNotAvailable: "CV not available",
        jobLinkNotAvailable: "Job link not available",
        linkToJob: "Link to Job",
        updating: "Updating...",
        revertStatus: "Revert Status",
        statusValues: {
          yes: "YES",
          no: "NO",
          pending: "Pending",
          sent: "Sent"
        },
        relevanceValues: {
          neutral: "Neutral",
          relevant: "Relevant",
          irrelevant: "Irrelevant"
        },
        relevanceActions: {
          markRelevant: "Mark as relevant",
          markIrrelevant: "Mark as irrelevant",
          markNeutral: "Mark as neutral"
        },
        expandAll: "Expand All",
        collapseAll: "Collapse All"
      }
    },
    he: {
      title: "לוח התאמות משרות",
      subtitle: "תצוגה מרוכזת של משרות שנאספו ידנית ומועמדים מתאימים.",
      subtitleUser: "גלה התאמות משרות שמצאנו עבורך! ראה את ציוני ההתאמה שלך והבן את ההיגיון מאחורי כל התאמה.\nספק משובים על ההערכות שלנו ועקוב אחר המשרות שפנית אליהן.",
      demoWarning: "מצב הדגמה: אתה צופה כעת במועמדים לא אמיתיים על משרות אמיתיות",
      demoCVDownloadTitle: "מצב הדגמה - הורדת קורות חיים",
      demoCVDownloadMessage: "כפתור זה היה מוריד את קורות החיים של המועמד אם זה היה מועמד אמיתי.",
      filtersTitle: "מסננים",
      showFilters: "הצג מסננים",
      hideFilters: "הסתר מסננים",
      viewCandidates: "הצג מועמדים",
      hideCandidates: "הסתר מועמדים",
      showDetails: "הצג פרטים",
      hideDetails: "הסתר פרטים",
      pagination: {
        previous: "הקודם ←",
        next: "→ הבא",
        pageInfo: "עמוד {current} מתוך {total}",
        totalJobs: "סה״כ: {total} משרות",
        showLabel: "משרות בעמוד",
        jobsPerPage: "הצג",
        pageSize20: "20",
        pageSize50: "50",
        pageSize100: "100"
      },
      filters: {
        openSearch: "חיפוש חופשי",
        openSearchPlaceholder: "למשל, פייתון, ריאקט, למידת מכונה",
        companyName: "שם חברה",
        companyNamePlaceholder: "למשל, Example Tech",
        jobTitle: "תפקיד",
        jobTitlePlaceholder: "למשל, מפתח Backend",
        candidateName: "שם מועמד",
        candidateNamePlaceholder: "למשל, שי",
        jobId: "מזהה משרה",
        jobIdPlaceholder: "למשל, 12345",
        appliedStatus: "סטטוס הגשה",
        allStatuses: "כל הסטטוסים",
        pending: "ממתין",
        sent: "נשלח",
        appliedStatusHelp: "הצג את ההתאמות שהגשת",
        appliedStatusHelpAdmin: "הצג את ההתאמות שמועמדים הגישו",
        meetingMMR: "עומד בדרישות חובה",
        allMMR: "הכל",
        positiveMMR: "כן",
        negativeMMR: "לא",
        postedAfter: "פורסם לאחר",
        postedAfterHelp: "הצג משרות שפורסמו לאחר תאריך זה",
        minRelevanceScore: "ציון רלוונטיות מינימלי ({score})",
        scoreRange: ["0", "10"],
        regions: "אזורים",
        regionsPlaceholder: "למשל, {examples}",
        regionPlaceholder: "למשל, {examples}",
        location: "מיקום",
        locationPlaceholder: "למשל, תל אביב, חיפה",
        clear: "נקה",
        clearAll: "נקה הכל",
        applyFilters: "החל"
      },
      table: {
        headers: {
          jobId: "מזהה משרה",
          jobTitle: "תפקיד",
          company: "חברה",
          dateAdded: "תאריך הוספה",
          linkToJob: "קישור למשרה",
          matchedCandidates: "מועמדים מתאימים",
          candidateName: "שם המועמד",
          score: "ציון",
          matchScore: "ציון התאמה",
          showDetailedReport: "הצג דוח מפורט",
          cv: "קו\"ח",
          downloadCV: "הורד קו\"ח",
          mmr: "עומד בדרישות חובה",
          candidateMeetingMMR: "מועמד עומד בדרישות חובה",
          meetsMandatoryReq: "עומד בדרישות חובה",
          appliedStatus: "סטטוס הגשה",
          relevant: "רלוונטי?",
          wasMatchRelevant: "האם ההתאמה הייתה רלוונטית?",
          location: "מיקום",
          actions: ""
        },
        tooltips: {
          mmr: "דירוג דרישות חובה - האם (המועמד עומד/אתה עומד) בכל הדרישות החובה למשרה זו?",
          relevant: "(כל מועמד יכול לסמן אם המשרה הייתה רלוונטית עבורו/ספר לנו אם המשרה הזו הייתה רלוונטית עבורך.)",
          appliedStatus: "האם (המועמד שלח/שלחת) את (קורות החיים שלו/קורות החיים שלך) למשרה זו?"
        },
        noMatches: "אין התאמות עדיין! אם העלית לאחרונה את קורות החיים שלך, אנא בדוק שוב בעוד יום-יומיים. האלגוריתם שלנו עובד כדי למצוא עבורך את ההתאמות המושלמות.",
        noMatchesFiltered: "אין משרות התואמות למסננים הנוכחיים.",
        loading: "טוען התאמות...",
        viewJob: "הצג תיאור משרה",
        viewCandidate: "הצג פרטי מועמד",
        markAsSent: "סמן כנשלח",
        markAsPending: "סמן כממתין",
        downloadCV: "הורד קורות חיים",
        downloadCVFor: "הורד קורות חיים עבור {name}",
        viewDetails: "צפה בפרטים",
        showDetailedReport: "הצג דוח מפורט",
        cvNotAvailable: "קורות חיים לא זמינים",
        jobLinkNotAvailable: "קישור למשרה לא זמין",
        linkToJob: "קישור למשרה",
        updating: "מעדכן...",
        revertStatus: "החזר סטטוס",
        statusValues: {
          yes: "כן",
          no: "לא",
          pending: "ממתין",
          sent: "נשלח"
        },
        relevanceValues: {
          neutral: "ניטרלי",
          relevant: "רלוונטי",
          irrelevant: "לא רלוונטי"
        },
        relevanceActions: {
          markRelevant: "סמן כרלוונטי",
          markIrrelevant: "סמן כלא רלוונטי",
          markNeutral: "סמן כניטרלי"
        },
        expandAll: "הרחב הכל",
        collapseAll: "כווץ הכל"
      }
    }
  },

  // Companies page
  companies: {
    en: {
      title: "Company Management",
      loading: "Loading companies...",
      error: "Error loading companies",
      noCompanies: "No companies found.",
      filters: {
        searchPlaceholder: "Search by company name...",
        clear: "Clear search"
      },
      table: {
        headers: {
          id: "",
          companyName: "Company Name",
          jobsCount: "Jobs Count",
          actions: ""
        }
      },
      actions: {
        viewJobs: "View {company} jobs",
        viewJobsShort: "View Jobs",
        deleteCompany: "Delete {company}"
      },
      modal: {
        deleteTitle: "Confirm Deletion",
        deleteMessage: "You're about to delete {company}, that have {jobsCount} active jobs.",
        deleteConfirm: "Are you sure?",
        cancel: "Cancel",
        delete: "Delete",
        successTitle: "Success",
        errorTitle: "Error"
      }
    },
    he: {
      title: "ניהול חברות",
      loading: "טוען חברות...",
      error: "שגיאה בטעינת חברות",
      noCompanies: "לא נמצאו חברות.",
      filters: {
        searchPlaceholder: "חיפוש לפי שם חברה...",
        clear: "נקה חיפוש"
      },
      table: {
        headers: {
          id: "",
          companyName: "שם החברה",
          jobsCount: "מספר משרות",
          actions: ""
        }
      },
      actions: {
        viewJobs: "הצג משרות של {company}",
        viewJobsShort: "הצג משרות",
        deleteCompany: "מחק את {company}"
      },
      modal: {
        deleteTitle: "אישור מחיקה",
        deleteMessage: "אתה עומד למחוק את {company}, שיש לה {jobsCount} משרות פעילות.",
        deleteConfirm: "האם אתה בטוח?",
        cancel: "בטל",
        delete: "מחק",
        successTitle: "הצלחה",
        errorTitle: "שגיאה"
      }
    }
  },

  // Modal components
  modals: {
    en: {
      candidateModal: {
        matchScore: "Match Score",
        mmr: "Meets Mandatory Requirements",
        matchedAt: "Matched at",
        candidateOverview: "Candidate Overview",
        strengths: "Strengths",
        weaknesses: "Weaknesses",
        noStrengthsListed: "No strengths listed.",
        noWeaknessesListed: "No weaknesses listed.",
        noOverviewAvailable: "No overview available"
      },
      jobModal: {
        company: "Company",
        dateAdded: "Date Added",
        jobDescription: "Job Description",
        noDescriptionAvailable: "No description available"
      },
      jobDescriptionModal: {
        company: "Company",
        dateAdded: "Date Added",
        jobDescription: "Job Description",
        jobDetails: "Job Details",
        noDescriptionAvailable: "No description available"
      },
      jobViewModal: {
        description: "Description"
      }
    },
    he: {
      candidateModal: {
        matchScore: "ציון התאמה",
        mmr: "עומד בדרישות חובה",
        matchedAt: "הותאם ב",
        candidateOverview: "סקירת מועמד",
        strengths: "חוזקות",
        weaknesses: "חולשות",
        noStrengthsListed: "לא רשומות חוזקות.",
        noWeaknessesListed: "לא רשומות חולשות.",
        noOverviewAvailable: "אין סקירה זמינה"
      },
      jobModal: {
        company: "חברה",
        dateAdded: "תאריך הוספה",
        jobDescription: "תיאור המשרה",
        noDescriptionAvailable: "אין תיאור זמין"
      },
      jobDescriptionModal: {
        company: "חברה",
        dateAdded: "תאריך הוספה",
        jobDescription: "תיאור המשרה",
        jobDetails: "פרטי המשרה",
        noDescriptionAvailable: "אין תיאור זמין"
      },
      jobViewModal: {
        description: "תיאור"
      }
    }
  },

  // Common elements
  common: {
    en: {
      loading: "Loading...",
      updating: "Updating...",
      error: "Error",
      cancel: "Cancel",
      save: "Save",
      delete: "Delete",
      edit: "Edit",
      close: "Close",
      ok: "OK",
      done: "Done",
      success: "Success",
      clear: "Clear",
      clearAll: "Clear All",
      clearSearch: "Clear search",
      clearFilters: "Clear Filters",
      apply: "Apply",
      deleting: "Deleting...",
      showFilters: "Show Filters",
      hideFilters: "Hide Filters",
      showPassword: "Show password",
      hidePassword: "Hide password",
      genericError: "An error occurred. Please try again.",
      removeRegion: "Remove {region}",
      pagination: {
        previous: "← Previous",
        next: "Next →",
        pageInfo: "Page {current} of {total}",
        totalJobs: "Total: {total} jobs",
        totalUsers: "Total: {total} users",
        showLabel: "Show",
        usersPerPage: "users per page",
        jobsPerPage: "jobs per page",
        itemsPerPage: "items per page",
        pageSize10: "10",
        pageSize20: "20",
        pageSize50: "50",
        pageSize100: "100"
      }
    },
    he: {
      loading: "טוען...",
      updating: "מעדכן...",
      error: "שגיאה",
      cancel: "בטל",
      save: "שמור",
      delete: "מחק",
      edit: "ערוך",
      close: "סגור",
      ok: "אישור",
      done: "סיום",
      success: "הצלחה",
      clear: "נקה",
      clearAll: "נקה הכל",
      clearSearch: "נקה חיפוש",
      clearFilters: "נקה מסננים",
      apply: "החל",
      deleting: "מוחק...",
      showFilters: "הצג מסננים",
      hideFilters: "הסתר מסננים",
      showPassword: "הצג סיסמה",
      hidePassword: "הסתר סיסמה",
      genericError: "אירעה שגיאה. אנא נסה שוב.",
      removeRegion: "הסר {region}",
      pagination: {
        previous: "הקודם ←",
        next: "→ הבא",
        pageInfo: "עמוד {current} מתוך {total}",
        totalJobs: "סה״כ: {total} משרות",
        totalUsers: "סה״כ: {total} משתמשים",
        showLabel: "הצג",
        usersPerPage: "משתמשים בעמוד",
        jobsPerPage: "משרות בעמוד",
        itemsPerPage: "",
        pageSize10: "10",
        pageSize20: "20",
        pageSize50: "50",
        pageSize100: "100"
      }
    }
  },

  // Users page
  users: {
    en: {
      title: "All Users",
      loading: "Loading users...",
      error: "Failed to load users.",
      noUsersFound: "No users found",
      filters: {
        searchPlaceholder: "Search by name or email...",
        clear: "Clear search"
      },
      table: {
        headers: {
          name: "Name",
          email: "Email",
          cvStatus: "CV Status",
          signedUp: "Signed Up",
          totalMatches: "Total Matches",
          actions: ""
        }
      },
      actions: {
        deleteUser: "Delete user",
        viewCV: "View CV",
        downloadCV: "Download CV"
      },
      cvModal: {
        download: "Download",
        loading: "Loading CV..."
      },
      modal: {
        deleteTitle: "Confirm Deletion",
        deleteMessage: "Are you sure you want to completely delete the user {userName}",
        deleteMessageWithCV: ", their CV",
        deleteMessageWithMatches: " and {matchCount} matches",
        deleteWarning: "This action can't be reversed!",
        deleting: "Deleting...",
        delete: "Delete",
        cancel: "Cancel",
        successTitle: "User Deleted",
        successMessage: "User was deleted successfully.",
        ok: "OK"
      }
    },
    he: {
      title: "כל המשתמשים",
      loading: "טוען משתמשים...",
      error: "כשל בטעינת משתמשים.",
      noUsersFound: "לא נמצאו משתמשים",
      filters: {
        searchPlaceholder: "חיפוש לפי שם או אימייל...",
        clear: "נקה חיפוש"
      },
      table: {
        headers: {
          name: "שם",
          email: "אימייל",
          cvStatus: "סטטוס קורות חיים",
          signedUp: "תאריך הרשמה",
          totalMatches: "סה״כ התאמות",
          actions: ""
        }
      },
      actions: {
        deleteUser: "מחק משתמש",
        viewCV: "צפה בקורות חיים",
        downloadCV: "הורד קורות חיים"
      },
      cvModal: {
        download: "הורדה",
        loading: "טוען קורות חיים..."
      },
      modal: {
        deleteTitle: "אישור מחיקה",
        deleteMessage: "האם אתה בטוח שברצונך למחוק לחלוטין את המשתמש {userName}",
        deleteMessageWithCV: ", את קורות החיים שלו",
        deleteMessageWithMatches: " ו-{matchCount} התאמות",
        deleteWarning: "פעולה זו אינה ניתנת לביטול!",
        deleting: "מוחק...",
        delete: "מחק",
        cancel: "בטל",
        successTitle: "המשתמש נמחק",
        successMessage: "המשתמש נמחק בהצלחה.",
        ok: "אישור"
      }
    }
  },

  // Reporting page
  reporting: {
    en: {
      title: "Reporting",
      loading: "Loading report data...",
      error: "Failed to load report data",
      filters: {
        sortBy: "Sort by",
        sortOptions: {
          companyAZ: "Company (A-Z)",
          matchesHighLow: "Matches (High → Low)"
        },
        minScore: "Min Score:",
        showCompany: "Show Company"
      },
      charts: {
        jobsWithHighScoreMatches: "Jobs with high-scoring matches (above {minScore} score)",
        topCompaniesByJobs: "Top Companies by Number of Jobs",
        scoreDensityAcrossJobs: "Score density across top jobs",
        numberOfMatches: "Number of Matches",
        jobs: "Jobs",
        job: "Job",
        score: "Score",
        company: "Company",
        matches: "Matches",
        avgScore: "Avg. Score",
        clickToViewJobMatches: "Click to view job matches",
        notEnoughData: "Not enough data to display the plot.",
        chartRequiresData: "This chart requires at least one job with scores.",
        count: "Count",
        other: "Other"
      }
    },
    he: {
      title: "דוחות",
      loading: "טוען נתוני דוח...",
      error: "כשל בטעינת נתוני דוח",
      filters: {
        sortBy: "מיין לפי",
        sortOptions: {
          companyAZ: "חברה (א-ת)",
          matchesHighLow: "התאמות (גבוה → נמוך)"
        },
        minScore: "ציון מינימלי:",
        showCompany: "הצג חברה"
      },
      charts: {
        jobsWithHighScoreMatches: "משרות עם התאמות בציון גבוה (מעל {minScore})",
        topCompaniesByJobs: "חברות מובילות לפי מספר משרות",
        scoreDensityAcrossJobs: "צפיפות ציונים במשרות מובילות",
        numberOfMatches: "מספר התאמות",
        jobs: "משרות",
        job: "משרה",
        score: "ציון",
        company: "חברה",
        matches: "התאמות",
        avgScore: "ציון ממוצע",
        clickToViewJobMatches: "לחץ לצפייה בהתאמות משרה",
        notEnoughData: "אין מספיק נתונים להצגת הגרף.",
        chartRequiresData: "גרף זה דורש לפחות משרה אחת עם ציונים.",
        count: "כמות",
        other: "חברות אחרות"
      }
    }
  },

  // Job Listings page
  jobListings: {
    en: {
      title: "Job Listings Management",
      addNewJob: "Add New Job",
      loading: "Loading jobs...",
      errorLoading: "Error loading jobs",

      // Pagination section
      pagination: {
        previous: "← Previous",
        next: "Next →",
        pageInfo: "Page {current} of {total}",
        totalJobs: "Total: {total} jobs",
        showLabel: "Show",
        jobsPerPage: "jobs per page",
        pageSize20: "20",
        pageSize50: "50",
        pageSize100: "100"
      },

      // Filters section
      filters: {
        title: "Filters",
        showFilters: "Show Filters",
        hideFilters: "Hide Filters",
        searchJobTitle: "Job Title",
        jobTitlePlaceholder: "Search by job title...",
        searchJobDescription: "Job Description",
        jobDescriptionPlaceholder: "Search by job description...",
        jobId: "Job ID",
        jobIdPlaceholder: "e.g., 12345",
        companyFilter: "Company",
        companyPlaceholder: "All Companies",
        statusFilter: "Status",
        statusPlaceholder: "All Statuses",
        regions: "Regions",
        regionsPlaceholder: "e.g., {examples}",
        postedAfter: "Posted after",
        minRelevanceScore: "Min. Relevance Score ({score})",
        scoreRange: ["0", "10"],
        meetingMMR: "Meets Mandatory Requirements",
        allMMR: "All",
        positiveMMR: "Yes",
        negativeMMR: "No",
        clearFilters: "Clear Filters",
        clear: "Clear",
        clearAll: "Clear All",
        applyFilters: "Apply",
        closeDrawer: "Close filters"
      },

      // Table headers and content
      table: {
        headers: {
          jobId: "Job ID",
          title: "Job Title",
          company: "Company",
          region: "Region",
          location: "Location",
          status: "Status",
          age: "Age",
          matchCount: "Matches",
          datePosted: "Date Posted",
          linkToJob: "Link to Job",
          actions: "Actions"
        },
        loading: "Loading jobs...",
        error: "Error loading jobs: {error}",
        noJobs: "No jobs found",
        noJobsFiltered: "No jobs match the current filters",

        // Age indicators
        ageLabels: {
          new: "New",
          fresh: "Fresh",
          stale: "Stale",
          old: "Old",
          // Day-specific labels from API
          "1 day": "1 day",
          "2-5 days": "2-5 days",
          "6-14 days": "6-14 days",
          "15+ days": "15+ days",
          today: "Today"
        },

        // Action tooltips
        actions: {
          view: "View job details",
          edit: "Edit job",
          delete: "Delete job",
          openLink: "Open job link"
        },

        // Link status
        linkNotAvailable: "Job link not available"
      },

      // Delete confirmation modal
      deleteModal: {
        title: "Delete Job and Matches",
        warningText: "Are you sure you want to delete this job and <b>all of its matches</b>? This action cannot be undone.",
        jobId: "Job ID",
        job: "Job",
        company: "Company",
        cancel: "Cancel",
        delete: "Delete",
        deleting: "Deleting...",
        errorDeleting: "Failed to delete job."
      },

      // Success modal after deletion
      successModal: {
        title: "Job Deleted",
        message: "Job and all its matches were deleted successfully.",
        instruction: "Close this message to refresh the list."
      }
    },
    he: {
      title: "ניהול רשימת משרות",
      addNewJob: "הוסף משרה חדשה",
      loading: "טוען משרות...",
      errorLoading: "שגיאה בטעינת משרות",

      // Pagination section
      pagination: {
        previous: "הקודם ←",
        next: "→ הבא",
        pageInfo: "עמוד {current} מתוך {total}",
        totalJobs: "סה״כ: {total} משרות",
        showLabel: "משרות בעמוד",
        jobsPerPage: "הצג",
        pageSize20: "20",
        pageSize50: "50",
        pageSize100: "100"
      },

      // Filters section
      filters: {
        title: "מסננים",
        showFilters: "הצג מסננים",
        hideFilters: "הסתר מסננים",
        searchJobTitle: "כותרת משרה",
        jobTitlePlaceholder: "חפש לפי כותרת משרה...",
        searchJobDescription: "תיאור משרה",
        jobDescriptionPlaceholder: "חפש לפי תיאור משרה...",
        jobId: "מזהה משרה",
        jobIdPlaceholder: "למשל, 12345",
        companyFilter: "חברה",
        companyPlaceholder: "כל החברות",
        statusFilter: "סטטוס",
        statusPlaceholder: "כל הסטטוסים",
        regions: "אזורים",
        regionsPlaceholder: "למשל, {examples}",
        postedAfter: "פורסם לאחר",
        minRelevanceScore: "ציון רלוונטיות מינימלי ({score})",
        scoreRange: ["0", "10"],
        meetingMMR: "עומד בדרישות חובה",
        allMMR: "הכל",
        positiveMMR: "כן",
        negativeMMR: "לא",
        clearFilters: "נקה מסננים",
        clear: "נקה",
        clearAll: "נקה הכל",
        applyFilters: "החל",
        closeDrawer: "סגור מסנני חיפוש"
      },

      // Table headers and content
      table: {
        headers: {
          jobId: "מזהה משרה",
          title: "כותרת המשרה",
          company: "חברה",
          region: "אזור",
          location: "מיקום",
          status: "סטטוס",
          age: "נוסף לפני",
          matchCount: "התאמות",
          datePosted: "תאריך פרסום",
          linkToJob: "קישור למשרה",
          actions: "פעולות"
        },
        loading: "טוען משרות...",
        error: "שגיאה בטעינת משרות: {error}",
        noJobs: "לא נמצאו משרות",
        noJobsFiltered: "לא נמצאו משרות התואמות למסננים הנוכחיים",

        // Age indicators
        ageLabels: {
          new: "חדש",
          fresh: "טרי",
          stale: "ישן",
          old: "מיושן",
          // Day-specific labels from API
          "1 day": "יום 1",
          "2-5 days": "ימים 2-5",
          "6-14 days": "ימים 6-14",
          "15+ days": "ימים 15+",
          today: "היום"
        },

        // Action tooltips
        actions: {
          view: "הצג פרטי משרה",
          edit: "ערוך משרה",
          delete: "מחק משרה",
          openLink: "פתח קישור למשרה"
        },

        // Link status
        linkNotAvailable: "קישור למשרה לא זמין"
      },

      // Delete confirmation modal
      deleteModal: {
        title: "מחק משרה והתאמות",
        warningText: "האם אתה בטוח שברצונך למחוק את המשרה הזו ו<b>את כל ההתאמות שלה</b>? פעולה זו אינה ניתנת לביטול.",
        jobId: "מזהה משרה",
        job: "משרה",
        company: "חברה",
        cancel: "בטל",
        delete: "מחק",
        deleting: "מוחק...",
        errorDeleting: "כשל במחיקת המשרה."
      },

      // Success modal after deletion
      successModal: {
        title: "המשרה נמחקה",
        message: "המשרה וכל ההתאמות שלה נמחקו בהצלחה.",
        instruction: "סגור הודעה זו כדי לרענן את הרשימה."
      }
    }
  },

  // Add Job page
  addJob: {
    en: {
      title: "Add a New Job",

      // Form fields
      form: {
        jobTitle: "Job Title",
        jobTitlePlaceholder: "e.g. Software Developer, Marketing Manager",

        positionLink: "Position Link",
        positionLinkPlaceholder: "https://example.com/careers/position",

        company: "Company",
        companyPlaceholder: "Select a company",
        companyOther: "Other",
        newCompanyName: "New Company Name",
        newCompanyPlaceholder: "Enter new company name",

        field: "Field",
        fieldPlaceholder: "Select a field",

        jobId: "Job ID",
        jobIdPlaceholder: "e.g. JOB-2024-001",

        region: "Region",
        regionPlaceholder: "e.g. Center, North, South",

        scope: "Scope",
        scopePlaceholder: "Select scope...",
        scopeFullTime: "Full-time",
        scopePartTime: "Part-time",

        jobDescription: "Job Description",
        jobDescriptionPlaceholder: "Describe the responsibilities, requirements, and expectations for this role.",

        required: "Required field"
      },

      // Actions
      actions: {
        cancel: "Cancel",
        submit: "Add Job",
        update: "Update Job"
      },

      // Success modal
      successModal: {
        title: "Success",
        message: "Job added successfully!",
        messageUpdate: "Job updated successfully!"
      },

      // Error handling
      errors: {
        failedToAdd: "Failed to add job",
        failedToUpdate: "Failed to update job",
        pleaseCheck: "Please check the form and try again."
      }
    },
    he: {
      title: "הוסף משרה חדשה",

      // Form fields
      form: {
        jobTitle: "כותרת המשרה",
        jobTitlePlaceholder: "לדוגמה: מפתח תוכנה, מנהל שיווק",

        positionLink: "קישור למשרה",
        positionLinkPlaceholder: "https://example.com/careers/position",

        company: "חברה",
        companyPlaceholder: "בחר חברה",
        companyOther: "אחר",
        newCompanyName: "שם חברה חדש",
        newCompanyPlaceholder: "הכנס שם חברה חדש",

        field: "תחום",
        fieldPlaceholder: "בחר תחום",

        jobId: "מזהה משרה",
        jobIdPlaceholder: "לדוגמה: JOB-2024-001",

        region: "אזור",
        regionPlaceholder: "לדוגמה: מרכז, צפון, דרום",

        scope: "היקף משרה",
        scopePlaceholder: "בחר היקף משרה...",
        scopeFullTime: "משרה מלאה",
        scopePartTime: "משרה חלקית",

        jobDescription: "תיאור המשרה",
        jobDescriptionPlaceholder: "תאר את האחריות, הדרישות והציפיות לתפקיד זה.",

        required: "שדה חובה"
      },

      // Actions
      actions: {
        cancel: "בטל",
        submit: "הוסף משרה",
        update: "עדכן משרה"
      },

      // Success modal
      successModal: {
        title: "הצלחה",
        message: "המשרה נוספה בהצלחה!",
        messageUpdate: "המשרה עודכנה בהצלחה!"
      },

      // Error handling
      errors: {
        failedToAdd: "כשל בהוספת המשרה",
        failedToUpdate: "כשל בעדכון המשרה",
        pleaseCheck: "אנא בדוק את הטופס ונסה שוב."
      }
    }
  },

  // Sign Up page
  signUp: {
    en: {
      title: "Sign Up",
      subtitle: "Create your account to get started",

      // Form fields
      form: {
        email: "Email",
        emailPlaceholder: "Enter your email",

        name: "Name",
        namePlaceholder: "Enter your name",

        password: "Password",
        passwordPlaceholder: "Enter your password",

        confirmPassword: "Confirm Password",
        confirmPasswordPlaceholder: "Re-enter your password",

        showPassword: "Show password",
        hidePassword: "Hide password",

        subscribeToEmails: "I wish to receive new matches notifications via email"
      },

      // Actions
      actions: {
        signUp: "Sign Up",
        loading: "Please wait...",
        signIn: "Sign In"
      },

      // Footer
      footer: {
        alreadyHaveAccount: "Already have an account?",
        cookieWarning: "⚠️ This site requires third-party cookies to log in. Please enable them in your browser settings."
      },

      // Error messages
      errors: {
        nameRequired: "Name is required.",
        passwordsMismatch: "Passwords do not match.",
        registrationFailed: "Registration failed",
        genericError: "An error occurred. Please try again."
      }
    },
    he: {
      title: "הרשמה",
      subtitle: "צור את החשבון שלך כדי להתחיל",

      // Form fields
      form: {
        email: "אימייל",
        emailPlaceholder: "הכנס את האימייל שלך",

        name: "שם",
        namePlaceholder: "הכנס את השם שלך",

        password: "סיסמה",
        passwordPlaceholder: "הכנס את הסיסמה שלך",

        confirmPassword: "אימות סיסמה",
        confirmPasswordPlaceholder: "הכנס שוב את הסיסמה שלך",

        showPassword: "הצג סיסמה",
        hidePassword: "הסתר סיסמה",

        subscribeToEmails: "אני מעוניין לקבל התראות על התאמות חדשות באימייל"
      },

      // Actions
      actions: {
        signUp: "הירשם",
        loading: "אנא המתן...",
        signIn: "התחבר"
      },

      // Footer
      footer: {
        alreadyHaveAccount: "כבר יש לך חשבון?",
        cookieWarning: "⚠️ אתר זה דורש עוגיות צד שלישי כדי להתחבר. אנא אפשר אותן בהגדרות הדפדפן שלך."
      },

      // Error messages
      errors: {
        nameRequired: "שם הוא שדה חובה.",
        passwordsMismatch: "הסיסמאות אינן תואמות.",
        registrationFailed: "ההרשמה נכשלה",
        genericError: "אירעה שגיאה. אנא נסה שוב."
      }
    }
  },

  // Password Reset Modal
  resetPassword: {
    en: {
      title: "Reset Password",
      emailLabel: "Email",
      emailPlaceholder: "Enter your email",
      sendResetLink: "Send Reset Link",
      sending: "Sending...",
      successMessage: "Check your email for a reset link.",
      failedToSend: "Failed to send reset email"
    },
    he: {
      title: "איפוס סיסמה",
      emailLabel: "אימייל",
      emailPlaceholder: "הכנס את האימייל שלך",
      sendResetLink: "שלח קישור איפוס",
      sending: "שולח...",
      successMessage: "בדוק את האימייל שלך לקישור איפוס.",
      failedToSend: "כשל בשליחת אימייל איפוס"
    }
  },

  // New Password Page
  newPassword: {
    en: {
      title: "Set New Password",
      newPassword: "New Password",
      newPasswordPlaceholder: "Enter new password",
      confirmPassword: "Confirm Password",
      confirmPasswordPlaceholder: "Confirm new password",
      setPassword: "Set Password",
      setting: "Setting...",
      showPassword: "Show password",
      hidePassword: "Hide password",

      errors: {
        fillAllFields: "Please fill in all fields.",
        passwordsMismatch: "Passwords do not match.",
        failedToSet: "Failed to set new password"
      }
    },
    he: {
      title: "הגדר סיסמה חדשה",
      newPassword: "סיסמה חדשה",
      newPasswordPlaceholder: "הכנס סיסמה חדשה",
      confirmPassword: "אימות סיסמה",
      confirmPasswordPlaceholder: "אמת את הסיסמה החדשה",
      setPassword: "הגדר סיסמה",
      setting: "מגדיר...",
      showPassword: "הצג סיסמה",
      hidePassword: "הסתר סיסמה",

      errors: {
        fillAllFields: "אנא מלא את כל השדות.",
        passwordsMismatch: "הסיסמאות אינן תואמות.",
        failedToSet: "כשל בהגדרת סיסמה חדשה"
      }
    }
  }
};

// Helper function to get translation with template variable support
export const getTranslation = (section, key, language = "en", variables = {}) => {
  try {
    // Handle nested keys like 'errors.loginFailed'
    const keys = key.split(".");
    let value = translations[section]?.[language];

    for (const k of keys) {
      value = value?.[k];
    }

    // If not found in current language, try fallback to English
    if (value === undefined && language !== "en") {
      let fallbackValue = translations[section]?.["en"];
      for (const k of keys) {
        fallbackValue = fallbackValue?.[k];
      }
      value = fallbackValue;
    }

    // If still not found, return the key as fallback
    if (value === undefined) {
      console.warn(`Translation not found for: ${section}.${key} in ${language}`);
      return key;
    }

    // Replace template variables like {current} and {total}
    if (typeof value === "string" && Object.keys(variables).length > 0) {
      return value.replace(/\{(\w+)}/g, (match, varName) => {
        return variables[varName] !== undefined ? variables[varName] : match;
      });
    }

    return value;
  } catch (_error) {
    console.warn(`Translation not found for: ${section}.${key} in ${language}`);
    return key; // return the key as fallback
  }
};

// Hook to get translations for a specific section (to be used with LanguageContext)
import { useLanguage } from "../contexts/LanguageContext";

export const useTranslations = section => {
  const { currentLanguage } = useLanguage();

  const t = (key, variables = {}) => getTranslation(section, key, currentLanguage, variables);

  return { t, currentLanguage };
};
