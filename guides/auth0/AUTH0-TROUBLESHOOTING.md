# Auth0 Troubleshooting Guide

## Common Issues

### JWEDecryptionFailed Error

**Symptoms:**

- Error messages like `JWEDecryptionFailed: decryption operation failed`
- Authentication not working
- 500 errors from `/api/session` endpoint
- Middleware failures

**Causes:**

1. The `AUTH0_SECRET` environment variable doesn't match the one used to encrypt cookies
2. Browser has cookies encrypted with a different secret
3. Auth0 configuration has changed since cookies were created
4. The `AUTH0_SECRET` doesn't meet the 32-character requirement

**Solutions:**

#### 1. Verify AUTH0_SECRET

Ensure the `AUTH0_SECRET` in your environment is exactly 32 characters long:

```bash
# Check the length
echo -n "this-is-exactly-32-chars-long!!" | wc -c
# Should output: 32
```

#### 2. Clear Browser Cookies

Clear browser cookies for your local domain to remove any stale encrypted sessions.

#### 3. Generate a New Secret

If needed, generate a new Auth0 secret:

```bash
# Using OpenSSL (recommended for production)
openssl rand -hex 16  # Generates 32 character hex string

# Or use a memorable 32-character phrase for development
# "this-is-exactly-32-chars-long!!"
```

#### 4. Update Environment Variables

Make sure all your environment files have the same Auth0 configuration:

```
# Required Auth0 Variables
AUTH0_SECRET=this-is-exactly-32-chars-long!!
AUTH0_BASE_URL=http://localhost:3000
AUTH0_ISSUER_BASE_URL=https://dev-s2idqivfjwfrvd1i.us.auth0.com
AUTH0_CLIENT_ID=ERmg3ta1uL5zjahATS8H25gMxvrTAp7i
AUTH0_CLIENT_SECRET=t-xkzOLmYh0oowyIXqoHNhlDjjwinOlCSsDUWBK30jL_vgQi4X-sujyZXI2oL3-4
```

#### 5. Restart Next.js Server

After updating environment variables, restart your Next.js server:

```bash
pkill -f "next dev" && npm run dev
```

## Preventative Measures

### Robust Error Handling

We've implemented error handling in two key locations:

1. **Middleware** - Gracefully handles decryption errors to prevent site-wide failures
2. **Session API** - Returns appropriate responses when Auth0 errors occur

### Environment Variable Management

Follow these best practices:

1. Use `.env.example` to document required variables
2. Keep consistent Auth0 configuration across environments
3. Securely store secrets according to security rule 011-env-var-security
4. Use different Auth0 secrets for development, staging, and production

## Deployment Considerations

When deploying to production:

1. Generate a strong random Auth0 secret unique to each environment
2. Store secrets securely in your deployment platform
3. Avoid checking actual secrets into version control
4. Implement secret rotation procedures for production

## Related Documentation

- [Auth0 Next.js SDK Documentation](https://auth0.github.io/nextjs-auth0/)
- [JWT Debugging Guide](https://jwt.io/)
