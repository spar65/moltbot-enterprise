# VibeCoder Developer Onboarding Guide

## Introduction

This guide is designed to help new developers quickly get up to speed with the VibeCoder project. It covers setup, development workflow, and essential concepts.

## Getting Started

### Prerequisites

- Node.js (v18+)
- npm (v8+) or yarn (v1.22+)
- Git
- IDE (VS Code recommended)

### Setup Instructions

1. Clone the repository:

   ```bash
   git clone https://github.com/your-org/vibecoder.git
   cd vibecoder
   ```

2. Install dependencies:

   ```bash
   npm install
   # or
   yarn
   ```

3. Set up environment variables:

   ```bash
   cp .env.example .env.local
   # Edit .env.local with your local configuration
   ```

4. Start the development server:
   ```bash
   npm run dev
   # or
   yarn dev
   ```

### IDE Configuration

- Install recommended VS Code extensions (defined in `.vscode/extensions.json`)
- Set up ESLint and Prettier integration
- Configure TypeScript language server

## Development Workflow

### Git Workflow

1. Create a feature branch from main:

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. Make changes and commit with conventional commit messages:

   ```bash
   git commit -m "feat: add new component"
   ```

3. Push to remote and create a pull request:

   ```bash
   git push -u origin feature/your-feature-name
   ```

4. Address review feedback and merge when approved

### Testing

1. Run unit tests:

   ```bash
   npm run test
   # or
   yarn test
   ```

2. Run specific tests:

   ```bash
   npm run test -- -t "component name"
   # or
   yarn test -t "component name"
   ```

3. Update test snapshots:
   ```bash
   npm run test -- -u
   # or
   yarn test -u
   ```

### Building

1. Create a production build:

   ```bash
   npm run build
   # or
   yarn build
   ```

2. Start the production server:
   ```bash
   npm start
   # or
   yarn start
   ```

## Architecture Overview

### Technology Stack

- **Frontend Framework**: Next.js
- **UI Library**: React with Shadcn/UI components
- **Styling**: Tailwind CSS
- **State Management**: React Context + SWR
- **Authentication**: Auth0
- **Payment Processing**: Stripe
- **Email Marketing**: MailChimp
- **Testing**: Jest + React Testing Library

### Key Concepts

#### Next.js Routing

- File-based routing in `/src/pages` directory
- API routes in `/src/pages/api`
- Dynamic routes using `[param]` syntax

#### Component Architecture

- Component-Driven Development approach
- Reusable components in `/src/components`
- Feature-specific components organized by domain

#### Data Fetching

- Server-side rendering with `getServerSideProps`
- Static site generation with `getStaticProps`
- Client-side fetching with SWR

#### State Management

- Local state with useState/useReducer
- Shared state with React Context
- Server state with SWR

## Common Tasks

### Creating a New Page

1. Create a new file in `/src/pages` directory
2. Export a default React component
3. Implement data fetching using appropriate Next.js methods
4. Add navigation links to the new page

### Adding a New Component

1. Create a new directory in `/src/components`
2. Implement the component with TypeScript types
3. Write tests for the component
4. Document the component API

### Working with API Routes

1. Create a new file in `/src/pages/api`
2. Export a handler function
3. Implement request handling and response formatting
4. Test the API endpoint

### Authentication Flow

1. Understand Auth0 integration
2. Use authentication hooks for protected resources
3. Implement role-based access control

## Troubleshooting

### Common Issues

- Environment variable configuration
- Authentication token expiration
- API endpoint permissions
- Build errors due to type issues

### Debugging Tools

- React Developer Tools
- Next.js Error Overlay
- Chrome DevTools Network tab
- Jest Debug Mode

### Getting Help

- Check existing documentation in `/docs`
- Review GitHub issues for similar problems
- Ask in the team Slack channel
- Create a detailed GitHub issue if needed

## Best Practices

### Code Quality

- Follow TypeScript best practices
- Use ESLint and Prettier for code formatting
- Write meaningful commit messages
- Keep components focused and composable

### Performance

- Optimize images using Next.js Image component
- Implement code splitting for large components
- Use appropriate data fetching strategies
- Monitor bundle size with build analytics

### Accessibility

- Ensure proper semantic HTML
- Add appropriate ARIA attributes
- Test with keyboard navigation
- Support screen readers

### Security

- Never expose API keys in client-side code
- Validate all user inputs
- Implement proper authentication checks
- Follow security best practices for Auth0 and Stripe
