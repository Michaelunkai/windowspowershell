# Job Task Tracker

A professional job documentation and task management application built with React, TypeScript, and Tailwind CSS. This application helps you track daily work activities with a clean, Todoist-inspired interface.

## Features

- **Task Management**: Create, edit, and delete tasks with priorities (P1-P4)
- **Project Organization**: Organize tasks into multiple projects
- **Date Tracking**: Set due dates and track when tasks were created/completed
- **Search & Filter**: Search tasks and filter by today, upcoming, or specific projects
- **Dark Mode**: Toggle between light and dark themes
- **Local Storage**: All data persists in browser local storage
- **Export**: Export tasks to JSON or CSV format
- **Responsive Design**: Clean, professional interface that works on all devices

## Current Tasks

The application comes pre-loaded with your job documentation tasks from December 2025:

1. **SUM 23 12 25** - DB diagnostics work
2. **SUM 24 12 25** - Database tasks
3. **sum 25 12 25** - TovPlay Infrastructure
4. **sum 29 12 25** - Fixed daily backup script on production
5. **sum 30 12 25** - Summary for Itamar (macOS conversion)
6. **sum 31 12 25** - Staging Backend Crash Loop fix

## Tech Stack

- **React 18.2** - UI library
- **TypeScript** - Type safety
- **Vite** - Build tool and dev server
- **Tailwind CSS** - Styling
- **@dnd-kit** - Drag and drop functionality
- **date-fns** - Date manipulation
- **lucide-react** - Icon library

## Getting Started

### Prerequisites

- Node.js (v16 or higher)
- npm or yarn

### Installation

1. Clone the repository:
```bash
git clone https://github.com/Michaelunkai/job-task-tracker.git
cd job-task-tracker
```

2. Install dependencies:
```bash
npm install
```

3. Start the development server:
```bash
npm run dev
```

4. Open your browser and navigate to `http://localhost:5173`

## Building for Production

```bash
npm run build
```

The production-ready files will be in the `dist` folder.

## Deployment

### Deploy to Vercel (Recommended - Free)

1. Go to [vercel.com](https://vercel.com)
2. Sign in with your GitHub account
3. Click "Add New Project"
4. Import the `Michaelunkai/job-task-tracker` repository
5. Vercel will automatically detect it's a Vite project
6. Click "Deploy"
7. Your app will be live at `https://job-task-tracker-[your-username].vercel.app`

### Deploy to Netlify (Alternative - Free)

1. Go to [netlify.com](https://netlify.com)
2. Sign in with your GitHub account
3. Click "Add new site" → "Import an existing project"
4. Select the `Michaelunkai/job-task-tracker` repository
5. Build command: `npm run build`
6. Publish directory: `dist`
7. Click "Deploy site"

## Project Structure

```
job-task-tracker/
├── src/
│   ├── App.tsx              # Main application component
│   ├── main.tsx             # Application entry point
│   ├── styles/
│   │   └── index.css        # Global styles and Tailwind
│   ├── types/
│   │   └── index.ts         # TypeScript type definitions
│   └── utils/
│       ├── initialData.ts   # Initial tasks and projects
│       └── storage.ts       # Local storage utilities
├── index.html               # HTML template
├── package.json             # Dependencies and scripts
├── tailwind.config.js       # Tailwind CSS configuration
├── tsconfig.json            # TypeScript configuration
└── vite.config.ts           # Vite configuration
```

## Usage

### Adding a Task

1. Type your task in the input field at the bottom
2. Select a due date
3. Choose a priority level (P1-P4)
4. Click "Add Task" or press Enter

### Managing Tasks

- Click the circle checkbox to mark a task as complete
- Click the trash icon to delete a task
- Use the search bar to filter tasks by content

### Switching Views

- **Inbox**: All unorganized tasks
- **Today**: Tasks due today
- **Upcoming**: All future tasks
- **Projects**: Filter by specific project

### Exporting Data

Click "Export JSON" in the sidebar to download all your tasks and projects.

## Development

### Available Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run preview` - Preview production build locally
- `npm run lint` - Run ESLint

## License

MIT

## Repository

GitHub: [https://github.com/Michaelunkai/job-task-tracker](https://github.com/Michaelunkai/job-task-tracker)

## Live Demo

🚀 **[View Live Application](https://job-task-tracker-vercel.vercel.app/)**

The application is deployed and running 24/7 on Vercel's free tier at:
**https://job-task-tracker-vercel.vercel.app/**
