// Demo matches data for demo users
const demoMatches = [
  {
    ID_Job: "782dcf3ea3b21900baea9b32",
    ID_candiate: "7999d601575afc1e7348fdb5",
    company: "Wix",
    cover_letter: "לאחר סיום לימודי מדעי המחשב בטכניון ופרויקט גמר שהתמקד ב-React Native, אני מחפשת את האתגר הבא שלי בפיתוח Front End. יש לי תשוקה עזה ל-UI/UX ואני שולטת ב-CSS ברמה גבוהה מאוד, כולל אנימציות ו-Flexbox. בניתי מספר אפליקציות צד-לקוח עצמאיות ואני מאמינה שאוכל להשתלב במהירות בצוות ה-Corvid שלכם.",
    created_at: "Thu, 04 Dec 2025 09:15:22 GMT",
    cv_link: "demo",
    job_relevant: "relevant",
    job_status: "pending",
    job_title: "Junior Frontend Developer",
    link: "https://wix.com/jobs/tel-aviv/frontend/112233",
    location: "תל אביב",
    mandatory_req: true,
    name: "מאיה כהן",
    overall_overview: "מאיה היא מועמדת ג'וניורית מבטיחה עם בסיס אקדמי חזק. תיק העבודות שלה מראה הבנה מעמיקה של עקרונות עיצוב וקוד נקי. היא חסרה ניסיון תעסוקתי רשמי בחברה גדולה, אך הפרויקטים האישיים שלה מפצים על כך חלקית.",
    score: 8.2,
    strengths: [
      "תואר ראשון במדעי המחשב (הצטיינות)",
      "שליטה מצוינת ב-React ו-Redux",
      "הבנה עמוקה של CSS3 ו-SASS",
      "תיק עבודות מרשים ב-Github"
    ],
    weeknesses: [
      "חוסר ניסיון בעבודה בצוות Agile",
      "לא מכירה מספיק כלי CI/CD"
    ],
    _id: "7930167699c9a229fdd43f21"
  },
  {
    ID_Job: "892dcf3ea3b21900baea8c43",
    ID_candiate: "8889d601575afc1e7348fdc6",
    company: "CyberArk",
    cover_letter: "עם 5 שנות ניסיון ב-DevOps וניהול תשתיות ענן ב-AWS, אני מביא עמי ידע נרחב ב-Kubernetes ו-Terraform. בתפקידי האחרון בסטארטאפ FinTech, הייתי אחראי על מיגרציה מלאה לענן והטמעת תהליכי אבטחת מידע ב-Pipeline. אני מחפש תפקיד שבו אוכל להוביל ארכיטקטורה.",
    created_at: "Tue, 02 Dec 2025 14:30:10 GMT",
    cv_link: "demo",
    job_relevant: "relevant",
    job_status: "sent",
    job_title: "Senior DevOps Engineer",
    link: "https://cyberark.com/careers/job/devops-senior/445566",
    location: "פתח תקווה",
    mandatory_req: true,
    name: "דוד לוי",
    overall_overview: "דוד הוא מועמד חזק מאוד טכנית עם התאמה גבוהה לדרישות התפקיד. הניסיון שלו במיגרציות ענן הוא יתרון משמעותי. הוא מפגין ידע רחב בכלים המודרניים ביותר בשוק.",
    score: 9.1,
    strengths: [
      "5 שנות ניסיון ב-AWS (הסמכת SA Professional)",
      "מומחיות ב-Kubernetes ו-Helm Charts",
      "ניסיון בכתיבת שתיות כקוד (IaC) עם Terraform",
      "רקע חזק באבטחת מידע (DevSecOps)"
    ],
    weeknesses: [
      "ציפיות שכר גבוהות מהממוצע",
      "פחות מנוסה ב-Azure (החברה עובדת Multi-cloud)"
    ],
    _id: "8930167699c9a229fdd44g32"
  },
  {
    ID_Job: "992dcf3ea3b21900baea9d54",
    ID_candiate: "9889d601575afc1e7348fde7",
    company: "Monday.com",
    cover_letter: "אני מנהלת מוצר עם רקע טכני בפיתוח, מה שמאפשר לי לתקשר בצורה מעולה עם צוותי R&D. ב-3 השנים האחרונות הובלתי מוצרי B2B משלב האיפיון ועד להשקה. אני מאמינה בגישת Data Driven Product Management ומחפשת סביבה דינמית.",
    created_at: "Fri, 05 Dec 2025 11:12:00 GMT",
    cv_link: "demo",
    job_relevant: "neutral",
    job_status: "pending",
    job_title: "Product Manager - Mobile",
    link: "https://monday.com/jobs/pm/mobile/778899",
    location: "תל אביב",
    mandatory_req: false,
    name: "גלית ירון",
    overall_overview: "גלית מציגה יכולות ניהול מוצר טובות, אך הניסיון שלה הוא בעיקר במוצרי Web Desktop. המשרה דורשת ניסיון ספציפי באפליקציות Mobile Native ו-iOS guidelines שחסר לה כרגע.",
    score: 6.5,
    strengths: [
      "יכולת ניתוח נתונים (SQL, Mixpanel)",
      "רקע קודם בפיתוח תוכנה",
      "אנגלית ברמת שפת אם",
      "ניסיון בעבודה מול לקוחות Enterprise"
    ],
    weeknesses: [
      "חוסר ניסיון בניהול מוצרי מובייל (iOS/Android)",
      "לא עבדה עם כלי B2C בהיקפים גדולים"
    ],
    _id: "9930167699c9a229fdd45h43"
  },
  {
    ID_Job: "102dcf3ea3b21900baea0e65",
    ID_candiate: "1089d601575afc1e7348fdf8",
    company: "Mobileye",
    cover_letter: "אני בוגר תואר שני במתמטיקה שימושית עם התמחות בראייה ממוחשבת. אני שולט ב-Python, PyTorch ו-OpenCV. עבדתי על פרויקטים אקדמיים בתחום הנהיגה האוטונומית ואני מחפש את התפקיד הראשון שלי בתעשייה כדי ליישם את הידע התיאורטי שלי.",
    created_at: "Wed, 03 Dec 2025 08:00:45 GMT",
    cv_link: "demo",
    job_relevant: "relevant",
    job_status: "sent",
    job_title: "Algorithm Developer",
    link: "https://mobileye.com/careers/algo/556677",
    location: "ירושלים",
    mandatory_req: true,
    name: "איתי שפירא",
    overall_overview: "איתי הוא מועמד אקדמי מבריק עם התאמה מושלמת לצוות האלגוריתמיקה. היעדר ניסיון תעשייתי פחות קריטי בתפקיד זה מכיוון שמחפשים חוקרים. ההתמחות שלו בראייה ממוחשבת רלוונטית ישירות.",
    score: 8.9,
    strengths: [
      "תואר שני במתמטיקה (ממוצע 95)",
      "שליטה ב-Python וספריות Deep Learning",
      "פרסם מאמר בכנס CVPR",
      "יכולת פתרון בעיות מתמטיות מורכבות"
    ],
    weeknesses: [
      "חוסר ניסיון בכתיבת קוד Production (C++)",
      "לא מכיר כלי Version Control לעומק"
    ],
    _id: "1030167699c9a229fdd46i54"
  },
  {
    ID_Job: "112dcf3ea3b21900baea1f76",
    ID_candiate: "1189d601575afc1e7348fdg9",
    company: "Amdocs",
    cover_letter: "בודק תוכנה ידני (QA) עם ניסיון של שנתיים בבדיקות מערכות CRM. בעל הסמכת ISTQB. יש לי ידע בסיסי ב-SQL ועבודה מול בסיסי נתונים. אני מעוניין להתפתח לתחום האוטומציה וללמוד Java/Selenium תוך כדי עבודה.",
    created_at: "Mon, 01 Dec 2025 16:20:30 GMT",
    cv_link: "demo",
    job_relevant: "irrelevant",
    job_status: "pending",
    job_title: "QA Engineer (Manual + Automation)",
    link: "https://amdocs.com/jobs/qa/raanana/990011",
    location: "רעננה",
    mandatory_req: false,
    name: "רועי גולן",
    overall_overview: "רועי הוא בודק ידני יסודי, אך המשרה דורשת 50% כתיבת קוד לאוטומציה. הוא מתאים למשרת ג'וניור אוטומציה, אך למשרה הנוכחית יידרש ליווי צמוד והכשרה משמעותית.",
    score: 7.0,
    strengths: [
      "הסמכת ISTQB Foundation",
      "ניסיון מוכח בבדיקות מערכות מורכבות (CRM/Billing)",
      "ידע בכתיבת שאילתות SQL מורכבות",
      "דייקנות וירידה לפרטים"
    ],
    weeknesses: [
      "חוסר ידע מעשי בתכנות (Java/Python)",
      "לא התנסה בכתיבת סקריפטים לאוטומציה"
    ],
    _id: "1130167699c9a229fdd47j65"
  },
  {
    ID_Job: "122dcf3ea3b21900baea2g87",
    ID_candiate: "1289d601575afc1e7348fdh0",
    company: "AppsFlyer",
    cover_letter: "Data Analyst מנוסה עם רקע חזק בסטטיסטיקה וכלכלה. מומחית ב-Tableau ו-PowerBI ליצירת דשבורדים ויזואליים להנהלה. אני שולטת ב-SQL ו-Python לניתוח נתונים, ויש לי ניסיון בעבודה בחברות AdTech, כך שאני מכירה את עולם הפרסום הדיגיטלי היטב.",
    created_at: "Sun, 07 Dec 2025 12:45:15 GMT",
    cv_link: "demo",
    job_relevant: "relevant",
    job_status: "sent",
    job_title: "Senior Marketing Analyst",
    link: "https://appsflyer.com/careers/data/herzliya/223344",
    location: "הרצליה",
    mandatory_req: true,
    name: "נועה ברק",
    overall_overview: "נועה היא התאמה מצוינת (\"בול\"). הניסיון שלה ב-AdTech הוא נדיר וחוסך זמן לימוד יקר. היא מביאה שילוב של יכולות טכניות (Python/SQL) עם ראייה עסקית רחבה.",
    score: 9.4,
    strengths: [
      "ניסיון ספציפי בתחום ה-AdTech/Marketing",
      "יכולות ויזואליזציה גבוהות (Tableau Expert)",
      "תואר בכלכלה וסטטיסטיקה",
      "שליטה מלאה ב-Python (Pandas, NumPy)"
    ],
    weeknesses: [
      "פחות מנוסה ב-Big Data Tools (Spark/Hadoop)"
    ],
    _id: "1230167699c9a229fdd48k76"
  }
];

// Helper function to inject demo matches into jobs data
export const injectDemoMatchesIntoJobs = apiResponse => {
  if (!apiResponse || !apiResponse.jobs || apiResponse.jobs.length === 0) {
    return apiResponse;
  }

  // Create a copy of the response
  const modifiedResponse = { ...apiResponse };

  // Replace matches in each job with demo matches
  modifiedResponse.jobs = apiResponse.jobs.map(job => ({
    ...job,
    matches: demoMatches
  }));

  return modifiedResponse;
};
