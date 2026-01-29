# Auth0 Database Synchronization Guide

This guide explains how to keep your Auth0 users in sync with your database users.

## Overview

When using Auth0 as an authentication provider, it's important to ensure that user data is properly synchronized between Auth0 and your application's database. This guide provides tools and best practices for maintaining this synchronization.

## Available Scripts

We've created several scripts to help you manage user synchronization:

1. **check-auth0-db-sync.js** - Checks for discrepancies between Auth0 and database users
2. **sync-auth0-users.js** - Interactive script to sync Auth0 users to the database
3. **cron-sync-auth0-users.js** - Automated script for scheduled synchronization

## Prerequisites

- Auth0 account with proper API credentials
- Neon PostgreSQL database
- Node.js environment

## Environment Variables

The following environment variables must be set:

```
DATABASE_URL=your_database_connection_string
AUTH0_ISSUER_BASE_URL=https://your-tenant.auth0.com
AUTH0_CLIENT_ID=your_client_id
AUTH0_CLIENT_SECRET=your_client_secret
CRON_API_KEY=your_api_key_for_cron_jobs (optional)
```

## Checking Synchronization Status

To check if your Auth0 users are in sync with your database:

```bash
node scripts/check-auth0-db-sync.js
```

This will:

- Fetch all users from Auth0
- Fetch all users from the database
- Identify users in Auth0 but missing from the database
- Identify users in the database but missing from Auth0
- Check for data inconsistencies between matching users

## Manual Synchronization

To manually sync Auth0 users to your database:

```bash
node scripts/sync-auth0-users.js
```

This interactive script will:

1. Show you what changes would be made (dry run)
2. Ask for confirmation before making any changes
3. Create missing users in the database
4. Update inconsistent user data

## Automated Synchronization (CRON Job)

For regular automated synchronization, use the CRON script:

```bash
node scripts/cron-sync-auth0-users.js [api_key]
```

This script is designed to run as a scheduled job (e.g., daily) and will:

- Automatically sync users without requiring manual confirmation
- Log all actions to a file in the `logs` directory
- Optionally validate an API key for security

### Setting Up a CRON Job

To set up a daily synchronization job:

```bash
# Example crontab entry (runs daily at 2 AM)
0 2 * * * cd /path/to/your/app && node scripts/cron-sync-auth0-users.js your_api_key >> /path/to/your/app/logs/cron.log 2>&1
```

## Synchronization Strategy

Our synchronization approach follows these principles:

1. **Auth0 as the Source of Truth**: We consider Auth0 to be the authoritative source for user identity data.

2. **One-Way Sync**: We sync from Auth0 to the database, not the other way around.

3. **Data Fields Synchronized**:

   - User ID (Auth0 user_id)
   - Email
   - Name
   - Nickname
   - Profile picture URL
   - Email verification status

4. **Error Handling**: All operations are logged and errors are captured without stopping the process.

## Best Practices

1. **Regular Synchronization**: Run the sync job daily to ensure data consistency.

2. **Monitor Logs**: Check the logs regularly for any synchronization errors.

3. **Database Triggers**: Consider implementing database triggers that prevent direct modifications to user fields that should be managed by Auth0.

4. **Auth0 Rules/Actions**: Use Auth0 Rules or Actions to ensure consistent user data at login time.

5. **API Security**: Always protect your synchronization endpoints with proper authentication.

## Troubleshooting

### Common Issues

1. **Missing Auth0 Users in Database**:

   - This is normal for new users and will be fixed by the sync script
   - Check if the user creation in the database is failing due to constraints

2. **Data Inconsistencies**:

   - Check if users are being updated directly in the database
   - Verify that Auth0 profile information is correct

3. **API Permission Errors**:
   - Ensure your Auth0 client has the necessary permissions (read:users)
   - Check that your client credentials are correct

### Logs

Synchronization logs are stored in the `logs` directory with the naming pattern:

```
auth0-sync-YYYY-MM-DD.log
```

## Additional Resources

- [Auth0 Management API Documentation](https://auth0.com/docs/api/management/v2)
- [Neon PostgreSQL Documentation](https://neon.tech/docs/introduction)
- [Auth0 Identity Lifecycle Best Practices](https://auth0.com/docs/authenticate/identity-providers)
