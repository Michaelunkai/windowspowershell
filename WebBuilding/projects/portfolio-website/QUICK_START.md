# Quick Start Guide

## 🚀 Your Portfolio Website is Ready!

**Project Location:** `F:\study\WebBuilding\projects\portfolio-website`  
**Dev Server:** http://localhost:3000 (already running!)  
**Status:** ✅ All tests passed, production-ready

---

## 📝 Immediate Next Steps

### 1. View Your Website (Right Now!)
Open your browser and go to: **http://localhost:3000**

- **Home Page**: `/` - Full portfolio with all sections
- **Services Page**: `/services` - Professional services and contact form

### 2. Customize Your Content (5 minutes)

Edit **ONE file**: `data/portfolio.ts`

```typescript
// Change these fields to your real info:
personal: {
  name: "Till Thelet",        // ← Your name
  title: "Full-Stack Dev...", // ← Your title
  brand: "TillDev",           // ← Your brand
  email: "till@tilldev.com",  // ← Your email
  bio: "...",                 // ← Your bio
  // etc.
}
```

**What you can customize:**
- ✏️ Personal information (name, title, bio)
- 🔗 Social links (GitHub, Twitter, LinkedIn, YouTube, TikTok, Discord)
- 📊 Stats (projects count, years experience)
- 💼 Projects (4 projects with images, tech stacks, links)
- 📦 Templates (3 open-source templates)
- 💰 Services (3 service offerings with pricing)
- 🔄 Process steps (your workflow)
- 🛠️ Tech stack (technologies you use)

**Save the file** → Changes appear instantly (hot reload)!

### 3. Replace Images (10 minutes)

**Required images:**
```
public/images/
├── avatar.svg           ← Your profile photo (replace with .jpg/.png)
├── projects/
│   ├── project1.svg    ← Screenshot of Project 1
│   ├── project2.svg    ← Screenshot of Project 2
│   ├── project3.svg    ← Screenshot of Project 3
│   └── project4.svg    ← Screenshot of Project 4
└── templates/
    ├── logo1.svg       ← Template 1 logo
    ├── logo2.svg       ← Template 2 logo
    ├── logo3.svg       ← Template 3 logo
    ├── preview1.svg    ← Template 1 preview
    ├── preview2.svg    ← Template 2 preview
    └── preview3.svg    ← Template 3 preview
```

**Tip:** You can use .jpg or .png instead of .svg. Just update the extensions in `data/portfolio.ts`.

### 4. Set Up Contact Form Email (Optional)

To receive contact form submissions:

1. **Edit** `.env.local`
2. **Add your email service credentials:**

```env
CONTACT_EMAIL=your-email@example.com

# Option A: Resend (easiest)
RESEND_API_KEY=re_xxxxxxxxxxxx

# Option B: SMTP
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
```

3. **Uncomment email integration** in `app/api/contact/route.ts` (see comments)

---

## 🧪 Test Your Changes

### Manual Testing:
1. Navigate through both pages (/ and /services)
2. Click all buttons and links
3. Test the mobile menu (resize browser window)
4. Expand/collapse sections:
   - Projects: "Show All Projects"
   - About: "View My Journey"
5. Submit the contact form (test validation)
6. Test responsive design (resize browser)

### Automated Checks:
```bash
npm run build    # Build for production (should succeed)
npx tsc --noEmit # TypeScript check (should show 0 errors)
```

---

## 🌐 Deploy to Production

### Option 1: Vercel (Easiest)
1. Push your code to GitHub
2. Go to [vercel.com](https://vercel.com)
3. Click "Import Project"
4. Select your GitHub repo
5. Add environment variables (if using email)
6. Deploy! ✨

### Option 2: Netlify
1. Push to GitHub
2. Go to [netlify.com](https://netlify.com)
3. "New site from Git"
4. Build command: `npm run build`
5. Publish directory: `.next`
6. Deploy! ✨

### Option 3: Any Node.js Host
```bash
npm run build
npm run start
```

---

## 📚 Additional Resources

- **README.md** - Full documentation
- **TESTING_CHECKLIST.md** - All 50+ verified tests
- **Next.js Docs** - https://nextjs.org/docs
- **Tailwind Docs** - https://tailwindcss.com/docs
- **Framer Motion** - https://www.framer.com/motion/

---

## 🛠️ Common Customizations

### Change Colors
Edit `tailwind.config.ts`:
```typescript
colors: {
  accent: {
    purple: "#7c3aed",  // ← Change this
  }
}
```

### Add a New Section
1. Create component in `components/home/`
2. Import and add to `app/page.tsx`

### Add a New Page
1. Create folder in `app/` (e.g., `app/blog/`)
2. Add `page.tsx` inside it
3. Auto-routed! (e.g., `/blog`)

### Change Fonts
Edit `app/layout.tsx` - currently using Inter from Google Fonts

---

## ⚡ Performance Tips

- Images: Use WebP format (smaller files)
- Keep animations subtle (don't overdo it)
- Test on mobile devices
- Check Lighthouse score in Chrome DevTools

---

## 🐛 Troubleshooting

### Build fails?
```bash
npm run dev  # Check console for errors
npx tsc --noEmit  # See TypeScript errors
```

### Images not showing?
- Check file paths in `data/portfolio.ts`
- Ensure images exist in `public/images/`
- File extensions must match (.svg, .jpg, .png)

### Animations not working?
- Check browser console for errors
- Ensure Framer Motion is installed: `npm list framer-motion`

### Contact form not working?
- Test in browser DevTools Network tab
- Check `/api/contact` logs
- Verify rate limiting (5 requests/hour per IP)

---

## 🎉 You're All Set!

Your portfolio website is production-ready. Customize the content, replace the images, and deploy!

**Questions?** Check the README or open an issue on GitHub.

**Happy coding!** 🚀
