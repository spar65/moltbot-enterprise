# Auth0 Integration Guide for Next.js (v4.6.0+)

This guide provides practical step-by-step instructions for integrating Auth0 with Next.js applications using Auth0's SDK version 4.6.0 or later. Based on real implementation experience, it addresses common challenges and best practices.

## Prerequisites

- Next.js application (Pages Router)
- Node.js 18.17.0 or later
- Auth0 account

## Step 1: Setup Auth0 Application

1. **Create an Auth0 Application**:

   - Log in to your Auth0 Dashboard
   - Go to Applications > Create Application
   - Name your application and select "Regular Web Applications"
   - Click Create

2. **Configure Application Settings**:
   - In your application settings, set the following URLs:
     - Allowed Callback URLs: `http://localhost:3000/auth/callback` (note: no `/api` prefix)
     - Allowed Logout URLs: `http://localhost:3000`
     - Allowed Web Origins: `http://localhost:3000`
   - Save changes

## Step 2: Install Auth0 SDK

1. **Install the Auth0 Next.js SDK**:

   ```bash
   npm install @auth0/nextjs-auth0@4.6.0
   ```

2. **Create environment variables**:
   Create a `.env.local` file in your project root:
   ```
   # Auth0 Configuration
   AUTH0_SECRET=your-32-byte-secret  # Use `openssl rand -hex 32` for production
   APP_BASE_URL=http://localhost:3000
   AUTH0_DOMAIN=your-tenant.region.auth0.com
   AUTH0_CLIENT_ID=your-client-id
   AUTH0_CLIENT_SECRET=your-client-secret
   ```

## Step 3: Implement Auth0 Client and Middleware

1. **Create Auth0 Client** (src/lib/auth0.ts):

   ```typescript
   import { Auth0Client } from "@auth0/nextjs-auth0/server";

   // Minimal client configuration using environment variables
   export const auth0 = new Auth0Client();
   ```

2. **Create Middleware** (middleware.ts in root directory):

   ```typescript
   import type { NextRequest } from "next/server";
   import { auth0 } from "./src/lib/auth0"; // Adjust path if necessary

   export async function middleware(request: NextRequest) {
     return await auth0.middleware(request);
   }

   export const config = {
     matcher: [
       "/((?!_next/static|_next/image|favicon.ico|sitemap.xml|robots.txt).*)",
     ],
   };
   ```

   > ⚠️ **IMPORTANT**: Make sure middleware.ts is in the root directory, not in src/pages!

## Step 4: Create Authentication Components

1. **Create AuthButtons Component** (src/components/AuthButtons.tsx):

   ```tsx
   "use client";
   import { useUser } from "@auth0/nextjs-auth0/client"; // Note the /client suffix

   export function AuthButtons() {
     const { user, isLoading, error } = useUser();

     if (isLoading) return <div>Loading...</div>;
     if (error) return <div>Authentication error: {error.message}</div>;

     if (user) {
       return (
         <div>
           Logged in as: {user.name || user.email}
           <a href="/auth/logout">Logout</a> {/* Note: /auth/ not /api/auth/ */}
         </div>
       );
     }

     return <a href="/auth/login">Login</a>;
     {
       /* Note: /auth/ not /api/auth/ */
     }
   }
   ```

2. **Create UserProfile Component** (src/components/UserProfile.tsx):

   ```tsx
   "use client";
   import { useUser } from "@auth0/nextjs-auth0/client";

   export function UserProfile() {
     const { user, isLoading, error } = useUser();

     if (isLoading) return <div>Loading user profile...</div>;
     if (error) return <div>Error loading profile: {error.message}</div>;
     if (!user) return <div>Not logged in</div>;

     return (
       <div>
         <h2>User Profile</h2>
         {user.picture && (
           <img src={user.picture} alt="Profile" width="100" height="100" />
         )}
         <p>Name: {user.name}</p>
         <p>Email: {user.email}</p>
         <p>ID: {user.sub}</p>
       </div>
     );
   }
   ```

## Step 5: Create Session API and Protected Routes

1. **Create Session API Endpoint** (src/pages/api/session.ts):

   ```typescript
   import { NextApiRequest, NextApiResponse } from "next";
   import { auth0 } from "../../lib/auth0";

   export default async function handler(
     req: NextApiRequest,
     res: NextApiResponse
   ) {
     try {
       const session = await auth0.getSession(req);

       if (!session) {
         return res.status(200).json({
           isLoggedIn: false,
         });
       }

       return res.status(200).json({
         isLoggedIn: true,
         userId: session.user.sub,
         name: session.user.name,
         email: session.user.email,
         picture: session.user.picture,
       });
     } catch (error) {
       console.error("Session API error:", error);
       return res.status(500).json({
         isLoggedIn: false,
         error: "Unable to get session",
       });
     }
   }
   ```

2. **Create Protected API Route** (src/pages/api/protected-data.ts):

   ```typescript
   import { NextApiRequest, NextApiResponse } from "next";
   import { auth0 } from "../../lib/auth0";

   export default async function handler(
     req: NextApiRequest,
     res: NextApiResponse
   ) {
     const session = await auth0.getSession(req);

     if (!session) {
       return res.status(401).json({ error: "Unauthorized" });
     }

     res.status(200).json({
       message: "This is protected data",
       user: session.user,
     });
   }
   ```

3. **Create Protected Profile Page** (src/pages/profile.tsx):

   ```tsx
   import { auth0 } from "../lib/auth0";
   import { GetServerSideProps } from "next";
   import Head from "next/head";

   export default function Profile({ user }) {
     return (
       <div>
         <Head>
           <title>Protected Profile Page</title>
         </Head>
         <h1>Protected Profile Page</h1>
         <pre>{JSON.stringify(user, null, 2)}</pre>
       </div>
     );
   }

   export const getServerSideProps: GetServerSideProps = async (context) => {
     const session = await auth0.getSession(context.req);

     if (!session) {
       return {
         redirect: {
           destination: "/auth/login",
           permanent: false,
         },
       };
     }

     return {
       props: {
         user: session.user,
       },
     };
   };
   ```

## Step 6: Create Test Page

Create a test page to verify everything works (src/pages/auth-test.tsx):

```tsx
import Head from "next/head";
import { AuthButtons } from "../components/AuthButtons";
import { UserProfile } from "../components/UserProfile";

export default function AuthTest() {
  return (
    <div>
      <Head>
        <title>Auth0 Test</title>
      </Head>

      <h1>Auth0 Test Page</h1>

      <div>
        <h2>Authentication</h2>
        <AuthButtons />
      </div>

      <div>
        <h2>User Profile</h2>
        <UserProfile />
      </div>
    </div>
  );
}
```

## Step 7: Testing

1. **Start your development server**:

   ```bash
   npm run dev
   ```

2. **Test the authentication flow**:

   - Visit `http://localhost:3000/auth-test`
   - Click on Login and complete the Auth0 login process
   - You should be redirected back to your application and see your profile information
   - Test the Logout button to ensure you can log out

3. **Test protected routes**:
   - While logged out, visit `http://localhost:3000/profile`
   - You should be redirected to the login page
   - After logging in, you should see your profile information

## Common Issues and Solutions

### 1. Middleware Not Working

**Issue**: Authentication routes not working properly.

**Solutions**:

- Ensure middleware.ts is in the root directory (not in src/pages)
- Check that matcher configuration is correct
- Verify Auth0 environment variables are set correctly

### 2. Route Path Errors

**Issue**: Getting 404 errors when trying to log in/out.

**Solutions**:

- Use `/auth/login` and `/auth/logout` (not `/api/auth/login`)
- Update Auth0 Dashboard callback URLs to match (e.g., `/auth/callback`)
- If you're migrating from v3, ensure all links are updated

### 3. Import Errors

**Issue**: "Module not found" or "Cannot use client hook" errors.

**Solutions**:

- Use `@auth0/nextjs-auth0/client` for client components
- Use `@auth0/nextjs-auth0/server` for server-side imports
- Follow the import patterns from the examples exactly

### 4. Session Not Available

**Issue**: Unable to access user data.

**Solutions**:

- Ensure you're using `auth0.getSession(req)` on server-side
- Check that cookies are being set correctly
- Verify Auth0 callback is completing successfully

## Production Deployment

When deploying to production:

1. **Update environment variables**:

   - Generate a new secure AUTH0_SECRET (`openssl rand -hex 32`)
   - Set APP_BASE_URL to your production URL
   - Use production Auth0 application credentials

2. **Update Auth0 Dashboard configuration**:

   - Add your production URLs to Allowed Callback URLs, Logout URLs, and Web Origins
   - Ensure all URLs use HTTPS for production

3. **Security considerations**:
   - Enable MFA in Auth0 for sensitive applications
   - Configure appropriate session timeouts
   - Implement proper error handling for production

## Resources

- [Auth0 Next.js SDK Documentation](https://auth0.github.io/nextjs-auth0/index.html)
- [Auth0 Dashboard](https://manage.auth0.com/)
- [Next.js Documentation](https://nextjs.org/docs)

## Conclusion

Auth0 v4.6.0+ integration with Next.js provides a powerful authentication solution with minimal boilerplate. By following the middleware-based approach and understanding the key differences from earlier versions, you can implement secure authentication with relative ease.

Remember that the most important aspects are:

1. Correct middleware configuration
2. Using the right route paths (`/auth/*` not `/api/auth/*`)
3. Following version-specific import patterns
4. Proper session handling
