# Portfolio Website

A modern, fully-featured portfolio website built with Next.js 16, TypeScript, Tailwind CSS, Framer Motion, and Shadcn/UI.

**🌐 Live Site:** https://portfolio-website-psi-jade-83.vercel.app/

![Portfolio Preview](https://via.placeholder.com/1200x600?text=Portfolio+Website)

## ✨ Features

### Pages
- **Home Page**
  - Hero section with animated introduction
  - Focus areas showcase
  - Featured project spotlight
  - Projects gallery with expand/collapse
  - Free templates section
  - About section with expandable journey
  - Team/personal profile

- **Services Page**
  - Professional services overview
  - 4-step process visualization
  - Pricing cards with "Most Popular" badge
  - Contact form with validation

### Components
- Responsive navigation with mobile menu
- Smooth scroll anchors
- Animated section reveals
- Expandable content sections
- Project and template cards
- Social media links
- Professional footer

### Technical Features
- **TypeScript**: Full type safety across the entire codebase
- **Framer Motion**: Smooth animations with `whileInView`, stagger effects, and expand/collapse
- **Form Validation**: react-hook-form + zod for robust client-side validation
- **API Route**: Contact form submission with rate limiting (5 requests/hour per IP)
- **SEO Optimized**: Meta tags, OpenGraph, Twitter cards, sitemap, robots.txt
- **Responsive Design**: Mobile-first, fully responsive across all devices
- **Dark Theme**: Beautiful dark color scheme with purple accents
- **Accessibility**: ARIA labels, semantic HTML, keyboard navigation

## 🚀 Getting Started

### Prerequisites
- Node.js 18+ 
- npm or yarn

### Installation

1. **Clone or navigate to the project:**
   ```bash
   cd F:\study\WebBuilding\projects\portfolio-website
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Run development server:**
   ```bash
   npm run dev
   ```

4. **Open browser:**
   Navigate to [http://localhost:3000](http://localhost:3000)

### Build for Production

```bash
npm run build
npm run start
```

## 📁 Project Structure

```
portfolio-website/
├── app/
│   ├── api/contact/        # Contact form API route
│   ├── services/           # Services page
│   ├── layout.tsx          # Root layout
│   ├── page.tsx            # Home page
│   ├── globals.css         # Global styles
│   ├── robots.ts           # robots.txt generator
│   └── sitemap.ts          # sitemap.xml generator
├── components/
│   ├── layout/             # Navbar, Footer
│   ├── home/               # Home page sections
│   ├── services/           # Services page sections
│   └── ui/                 # Reusable UI components
├── data/
│   └── portfolio.ts        # All content data (EDIT THIS!)
├── lib/
│   ├── animations.ts       # Framer Motion variants
│   └── utils.ts            # Utility functions
├── public/
│   └── images/             # Placeholder images
├── tailwind.config.ts      # Tailwind configuration
├── tsconfig.json           # TypeScript configuration
└── package.json            # Dependencies
```

## 🎨 Customization

### 1. Update Your Content

Edit `data/portfolio.ts` to customize all content:

```typescript
export const portfolio = {
  personal: {
    name: "Your Name",
    title: "Your Title",
    // ... more fields
  },
  socials: { /* ... */ },
  projects: [ /* ... */ ],
  templates: [ /* ... */ ],
  services: [ /* ... */ ],
  // ...
};
```

### 2. Replace Images

Replace placeholder SVGs in `public/images/`:
- `avatar.svg` → Your profile photo
- `projects/*.svg` → Project screenshots
- `templates/*.svg` → Template previews and logos

### 3. Configure Email

Update `.env.local` for contact form:

```env
CONTACT_EMAIL=your-email@example.com

# Option 1: Resend API
RESEND_API_KEY=re_xxxxxxxxxxxx

# Option 2: SMTP
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=your-smtp-user
SMTP_PASS=your-smtp-password
```

Then uncomment email integration in `app/api/contact/route.ts`.

### 4. Update Branding

Colors are defined in `tailwind.config.ts`:

```typescript
colors: {
  accent: {
    purple: "#7c3aed",      // Main accent
    purpleLight: "#a855f7", // Light accent
    green: "#10b981",       // Success
    blue: "#3b82f6",        // Info
  },
}
```

## 🛠️ Technologies

- **Framework**: [Next.js 16](https://nextjs.org/) (App Router, TypeScript)
- **Styling**: [Tailwind CSS](https://tailwindcss.com/)
- **Animations**: [Framer Motion](https://www.framer.com/motion/)
- **UI Components**: [Shadcn/UI](https://ui.shadcn.com/)
- **Form Handling**: [React Hook Form](https://react-hook-form.com/) + [Zod](https://zod.dev/)
- **Icons**: [Lucide React](https://lucide.dev/) + [React Icons](https://react-icons.github.io/react-icons/)
- **Type Safety**: [TypeScript](https://www.typescriptlang.org/)

## 📋 Available Scripts

```bash
npm run dev      # Start development server (localhost:3000)
npm run build    # Build for production
npm run start    # Start production server
npm run lint     # Run ESLint
```

## 🧪 Testing

All 50+ checklist items verified:
- ✅ TypeScript compilation (0 errors)
- ✅ Production build success
- ✅ All components render correctly
- ✅ Animations smooth and performant
- ✅ Form validation working
- ✅ API rate limiting functional
- ✅ Responsive design tested
- ✅ SEO tags present
- ✅ Accessibility standards met

See `TESTING_CHECKLIST.md` for complete details.

## 🌐 Deployment

### Vercel (Recommended)

1. Push to GitHub
2. Import on [Vercel](https://vercel.com)
3. Add environment variables
4. Deploy!

### Netlify

1. Build command: `npm run build`
2. Publish directory: `.next`
3. Add environment variables
4. Deploy!

### Other Platforms

- **Build**: `npm run build`
- **Start**: `npm run start`
- **Port**: 3000 (or set PORT env var)

## 📝 License

MIT License - Feel free to use this template for your own portfolio!

## 🙏 Credits

- Built with [Next.js](https://nextjs.org/)
- UI components from [Shadcn/UI](https://ui.shadcn.com/)
- Icons from [Lucide](https://lucide.dev/) and [React Icons](https://react-icons.github.io/react-icons/)
- Animations powered by [Framer Motion](https://www.framer.com/motion/)

## 📧 Support

Found a bug or have a feature request? Open an issue or submit a pull request!

---

**Made with ❤️ using Next.js and TypeScript**
