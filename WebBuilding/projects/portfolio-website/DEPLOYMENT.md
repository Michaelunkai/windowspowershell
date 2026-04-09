# Deployment Guide

Complete step-by-step instructions for deploying your portfolio website to production.

---

## 🚀 Pre-Deployment Checklist

Before deploying, verify:

- [ ] All content updated in `data/portfolio.ts`
- [ ] Placeholder images replaced with real images
- [ ] Contact email configured (if needed)
- [ ] Social media links updated
- [ ] Local build succeeds: `npm run build`
- [ ] No TypeScript errors: `npx tsc --noEmit`
- [ ] No ESLint errors: `npm run lint`
- [ ] All links tested locally
- [ ] Mobile responsiveness verified
- [ ] Contact form tested

---

## Option 1: Vercel (Recommended)

**Fastest deployment option with zero configuration.**

### Step 1: Prepare Your Repository

```bash
# Initialize git (if not already done)
cd F:\study\WebBuilding\projects\portfolio-website
git init

# Add files
git add .
git commit -m "Initial commit: Portfolio website"

# Create GitHub repository and push
# (Use GitHub Desktop or GitHub CLI)
gh repo create portfolio-website --public --source=. --remote=origin --push
```

### Step 2: Deploy to Vercel

1. Go to [vercel.com](https://vercel.com)
2. Click **"Add New Project"**
3. **Import your GitHub repository**
4. Vercel auto-detects Next.js:
   - Framework Preset: **Next.js**
   - Root Directory: `./`
   - Build Command: `npm run build`
   - Output Directory: `.next`
5. Add **Environment Variables** (if using email):
   ```
   CONTACT_EMAIL=your-email@example.com
   RESEND_API_KEY=re_xxxxxxxxxxxx
   ```
6. Click **"Deploy"**

### Step 3: Configure Domain (Optional)

1. In Vercel project settings → **Domains**
2. Add your custom domain (e.g., `tilldev.com`)
3. Follow DNS configuration instructions
4. SSL certificate auto-provisioned ✅

### Vercel Features
- ✅ Automatic deployments on git push
- ✅ Preview deployments for branches
- ✅ Edge CDN (global distribution)
- ✅ Automatic SSL certificates
- ✅ Zero configuration
- ✅ Analytics (optional)
- ✅ Free for personal projects

---

## Option 2: Netlify

**Alternative platform with similar ease of use.**

### Step 1: Prepare Your Repository

Same as Vercel (push to GitHub).

### Step 2: Deploy to Netlify

1. Go to [netlify.com](https://netlify.com)
2. Click **"Add new site"** → **"Import an existing project"**
3. Connect to **GitHub** and select your repo
4. Configure build settings:
   - Build command: `npm run build`
   - Publish directory: `.next`
5. Add **Environment Variables**:
   ```
   CONTACT_EMAIL=your-email@example.com
   RESEND_API_KEY=re_xxxxxxxxxxxx
   ```
6. Click **"Deploy site"**

### Step 3: Configure Domain (Optional)

1. Site settings → **Domain management**
2. Add custom domain
3. Update DNS records
4. SSL auto-enabled ✅

### Netlify Features
- ✅ Continuous deployment
- ✅ Branch preview deploys
- ✅ Global CDN
- ✅ Free SSL certificates
- ✅ Forms (alternative to API route)
- ✅ Analytics (optional)

---

## Option 3: Railway

**Deploy with PostgreSQL/Redis if needed later.**

### Step 1: Install Railway CLI

```bash
npm install -g @railway/cli
```

### Step 2: Deploy

```bash
cd F:\study\WebBuilding\projects\portfolio-website

# Login
railway login

# Initialize project
railway init

# Deploy
railway up
```

### Step 3: Configure

```bash
# Set environment variables
railway variables set CONTACT_EMAIL=your-email@example.com
railway variables set RESEND_API_KEY=re_xxxxxxxxxxxx

# Open project dashboard
railway open
```

---

## Option 4: Render

**Free tier with automatic SSL.**

### Step 1: Prepare Repository

Push to GitHub (same as above).

### Step 2: Deploy

1. Go to [render.com](https://render.com)
2. **New Web Service** → Connect GitHub
3. Configure:
   - Name: `portfolio-website`
   - Environment: **Node**
   - Build Command: `npm install && npm run build`
   - Start Command: `npm run start`
4. Add environment variables
5. Create Web Service

---

## Option 5: Self-Hosted (VPS)

**For Nginx/Apache on your own server.**

### Prerequisites
- Ubuntu/Debian VPS
- Node.js 18+ installed
- Domain pointing to server IP

### Step 1: Transfer Files

```bash
# On your VPS
cd /var/www
git clone https://github.com/yourusername/portfolio-website.git
cd portfolio-website
```

### Step 2: Install and Build

```bash
npm install
npm run build
```

### Step 3: Set Up PM2 (Process Manager)

```bash
npm install -g pm2

# Start app
pm2 start npm --name "portfolio" -- start

# Auto-restart on reboot
pm2 startup
pm2 save
```

### Step 4: Configure Nginx

Create `/etc/nginx/sites-available/portfolio`:

```nginx
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Enable site:
```bash
sudo ln -s /etc/nginx/sites-available/portfolio /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Step 5: SSL with Certbot

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

---

## Option 6: Docker

**Containerized deployment for portability.**

### Dockerfile

Create `Dockerfile`:

```dockerfile
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM node:18-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

EXPOSE 3000

CMD ["npm", "start"]
```

### Build and Run

```bash
# Build image
docker build -t portfolio-website .

# Run container
docker run -p 3000:3000 \
  -e CONTACT_EMAIL=your-email@example.com \
  -e RESEND_API_KEY=re_xxxxxxxxxxxx \
  portfolio-website
```

### Docker Compose

Create `docker-compose.yml`:

```yaml
version: '3.8'
services:
  web:
    build: .
    ports:
      - "3000:3000"
    environment:
      - CONTACT_EMAIL=${CONTACT_EMAIL}
      - RESEND_API_KEY=${RESEND_API_KEY}
    restart: always
```

Run:
```bash
docker-compose up -d
```

---

## 📧 Email Configuration

### Option A: Resend (Easiest)

1. Sign up at [resend.com](https://resend.com)
2. Get API key from dashboard
3. Add environment variable:
   ```
   RESEND_API_KEY=re_xxxxxxxxxxxx
   ```
4. Uncomment Resend code in `app/api/contact/route.ts`:
   ```typescript
   import { Resend } from 'resend';
   
   const resend = new Resend(process.env.RESEND_API_KEY);
   
   await resend.emails.send({
     from: 'contact@yourdomain.com',
     to: process.env.CONTACT_EMAIL,
     subject: `New Contact: ${body.projectType}`,
     text: `Name: ${body.name}\nEmail: ${body.email}\n\n${body.details}`,
   });
   ```
5. Install package:
   ```bash
   npm install resend
   ```

### Option B: SendGrid

1. Sign up at [sendgrid.com](https://sendgrid.com)
2. Get API key
3. Install package:
   ```bash
   npm install @sendgrid/mail
   ```
4. Add code to `app/api/contact/route.ts`:
   ```typescript
   import sgMail from '@sendgrid/mail';
   
   sgMail.setApiKey(process.env.SENDGRID_API_KEY);
   
   await sgMail.send({
     to: process.env.CONTACT_EMAIL,
     from: 'contact@yourdomain.com',
     subject: `New Contact: ${body.projectType}`,
     text: `Name: ${body.name}\nEmail: ${body.email}\n\n${body.details}`,
   });
   ```

### Option C: Nodemailer (SMTP)

1. Get SMTP credentials (Gmail, Outlook, etc.)
2. Install package:
   ```bash
   npm install nodemailer
   ```
3. Add code to `app/api/contact/route.ts`:
   ```typescript
   import nodemailer from 'nodemailer';
   
   const transporter = nodemailer.createTransport({
     host: process.env.SMTP_HOST,
     port: parseInt(process.env.SMTP_PORT || '587'),
     auth: {
       user: process.env.SMTP_USER,
       pass: process.env.SMTP_PASS,
     },
   });
   
   await transporter.sendMail({
     from: process.env.SMTP_USER,
     to: process.env.CONTACT_EMAIL,
     subject: `New Contact: ${body.projectType}`,
     text: `Name: ${body.name}\nEmail: ${body.email}\n\n${body.details}`,
   });
   ```

---

## 🔒 Security Best Practices

### Environment Variables
- ✅ Never commit `.env.local` to git (already in `.gitignore`)
- ✅ Use different API keys for dev/prod
- ✅ Rotate keys periodically

### Rate Limiting
- ✅ Already implemented (5 requests/hour per IP)
- ✅ Adjust in `app/api/contact/route.ts` if needed

### HTTPS
- ✅ Automatic on Vercel/Netlify
- ✅ Use Certbot for VPS
- ✅ Force HTTPS redirect in production

### Headers
Add to `next.config.mjs` (optional):
```javascript
async headers() {
  return [
    {
      source: '/:path*',
      headers: [
        { key: 'X-Frame-Options', value: 'DENY' },
        { key: 'X-Content-Type-Options', value: 'nosniff' },
        { key: 'Referrer-Policy', value: 'origin-when-cross-origin' },
      ],
    },
  ];
},
```

---

## 📊 Post-Deployment

### Verify Deployment
- [ ] Visit your live URL
- [ ] Test all pages and links
- [ ] Submit contact form
- [ ] Check mobile responsiveness
- [ ] Test in multiple browsers
- [ ] Verify images load
- [ ] Check console for errors

### Analytics (Optional)

#### Google Analytics
1. Get tracking ID
2. Add to `app/layout.tsx`:
   ```typescript
   import Script from 'next/script'
   
   <Script
     src={`https://www.googletagmanager.com/gtag/js?id=${GA_ID}`}
     strategy="afterInteractive"
   />
   ```

#### Vercel Analytics
1. Enable in Vercel dashboard
2. Install package:
   ```bash
   npm install @vercel/analytics
   ```
3. Add to `app/layout.tsx`:
   ```typescript
   import { Analytics } from '@vercel/analytics/react'
   
   <Analytics />
   ```

### Performance Monitoring

#### Lighthouse
```bash
npm install -g @lhci/cli
lhci autorun --upload.target=temporary-public-storage
```

#### Vercel Speed Insights
Enable in dashboard (free on Pro plan).

---

## 🐛 Troubleshooting Deployment

### Build Fails
```bash
# Check local build
npm run build

# Check TypeScript
npx tsc --noEmit

# Check for missing dependencies
npm install
```

### Environment Variables Not Working
- Verify variable names match exactly
- Restart deployment after adding variables
- Check for typos in `.env.local` keys

### Images Not Loading
- Ensure images exist in `public/images/`
- Check file paths in `data/portfolio.ts`
- Verify Next.js Image component used

### Contact Form Not Sending
- Check API route logs
- Verify email service credentials
- Test rate limiting (5 requests/hour limit)
- Check network tab in browser DevTools

### 404 Errors
- Ensure pages are in `app/` directory
- Check folder structure matches routes
- Verify `page.tsx` files exist

---

## 🎉 Success!

Your portfolio is now live! 🚀

### Next Steps
1. Share your portfolio URL
2. Add to resume/LinkedIn
3. Monitor analytics
4. Keep content updated
5. Add new projects as you build them

---

## 📞 Support

- **Next.js Docs**: https://nextjs.org/docs
- **Vercel Support**: https://vercel.com/support
- **Netlify Support**: https://docs.netlify.com

**Happy deploying!** 🎊
