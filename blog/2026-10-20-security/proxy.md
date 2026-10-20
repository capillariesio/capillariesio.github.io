# SSO-Protected Reverse Proxy for a Web API + Svelte UI

## Question

> I have web API that works via HTTP. It has no authentication or authorization features. I also have a Svelte application that uses that webapi, also no security features. Svelte app is currently served with NGINX. I want to put my webapi and the UI Svelte app behind some kind of proxy that would allow only authorized user to work with them. Users will be authenticated via some SSO infra, like Okta. I would like to use NGINX as this proxy, if it fits the bill, or some other out-of-the-box product. Design a deployment architecture and give some sample configurations for this kind of proxy.

## Answer

I'd use NGINX in front of everything, with **oauth2-proxy** handling the Okta sign-in. NGINX open source has no built-in OIDC support. What it does have is the `auth_request` module, which asks a small auth service "is this request logged in?" before passing it on. oauth2-proxy is a free, widely used project built to be that service.

## 1. Architecture

```
                        ┌──────────────────────── Okta (OIDC IdP) ───────────────────────┐
                        │  /authorize   /token   /keys   /logout                         │
                        └───────▲───────────────────────────────▲────────────────────────┘
                                │ (browser redirect)             │ (back-channel: code→token,
                                │                                │  JWKS, refresh)
 ┌─────────┐   HTTPS   ┌────────┴──────────────────────┐   ┌─────┴──────────┐   ┌───────┐
 │ Browser │──────────▶│ NGINX (edge, TLS termination) │──▶│  oauth2-proxy  │──▶│ Redis │
 └─────────┘  :443     │                               │   │  (auth svc)    │   │session│
                       │  /oauth2/*  → oauth2-proxy    │   └────────────────┘   └───────┘
                       │  /          → Svelte static   │  auth_request subrequest
                       │  /api/*     → Web API         │  on every protected request
                       └───────────────┬───────────────┘
                                       │ plain HTTP, private network only
                               ┌───────▼───────┐
                               │   Web API     │  ← NOT reachable except from NGINX
                               └───────────────┘
```

**Design decisions:**

1. **One public hostname, one origin.** For example `https://app.example.com/` for the UI and `https://app.example.com/api/` for the API. Because both share the same origin and the same session cookie, you need no CORS setup and the Svelte app doesn't have to manage tokens.
2. **NGINX is the only way in.** The API must be on a private network, firewalled, or bound to an internal interface. If anyone can reach it directly, they bypass all of this security, because the API itself checks nothing.
3. **Each request gets checked.** NGINX sends a quick subrequest to oauth2-proxy (`/oauth2/auth`), which answers:
   - 202: logged in, let it through.
   - 401: not logged in.
   - 403: logged in but not in the allowed group.
4. **The browser and the API are treated differently when not logged in:**
   - Page loads under `/` get redirected to the Okta login.
   - Calls to `/api/` get a plain 401. The Svelte app catches it and starts the login itself (redirecting a background fetch call doesn't work).
5. **User identity goes to the API as headers.** NGINX adds `X-User`, `X-Email`, `X-Groups`, and optionally `Authorization: Bearer <Okta access token>`. The API can use these for auditing or finer-grained permissions, and can later validate the JWT itself for extra protection.
6. **Sessions are stored in Redis**, not in the cookie. Okta tokens are large, so storing them in the cookie bloats every request. Redis also lets you run more than one oauth2-proxy instance.
7. **Access control:**
   - Basic: only users in a given Okta group (e.g. `app-users`) get in at all.
   - Per path: NGINX can require a different group for specific paths (e.g. `app-admins` for `/api/admin/`).

### Login flow

```
Browser → GET /dashboard → NGINX → auth_request → oauth2-proxy: no cookie → 401
NGINX → 302 /oauth2/start?rd=/dashboard → oauth2-proxy → 302 Okta /authorize (PKCE, state)
User logs in at Okta → 302 /oauth2/callback?code=… → oauth2-proxy exchanges code, checks groups,
  stores session in Redis, Set-Cookie: _app_session (Secure, HttpOnly, SameSite=Lax) → 302 /dashboard
Browser → GET /dashboard (+cookie) → auth_request → 202 → NGINX serves index.html
Svelte → fetch /api/items (+cookie) → auth_request → 202 + identity headers → proxied to API
```

---

## 2. Okta setup

1. **Applications → Create App Integration:** choose OIDC, type **Web Application** (it has a client secret, which is right because the secret lives in oauth2-proxy, not the browser).
   - Sign-in redirect URI: `https://app.example.com/oauth2/callback`
   - Sign-out redirect URI: `https://app.example.com/`
   - Grant types: Authorization Code and Refresh Token
2. **Assignments:** assign the `app-users` group (and `app-admins` if you want per-path rules).
3. **Security → API → Authorization Servers → `default`** (or your own):
   - Under Claims, add `groups`, include it in the ID token, set the value type to "Groups", and use a filter such as "Starts with `app-`".
   - Optionally add a `groups` scope.
4. Note the issuer URL: `https://<your-org>.okta.com/oauth2/default`.

---

## 3. Sample configurations

### `docker-compose.yml`

```yaml
services:
  nginx:
    image: nginx:stable-alpine
    ports: ["80:80", "443:443"]
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./nginx/snippets:/etc/nginx/snippets:ro
      - ./certs:/etc/nginx/certs:ro
      - ./ui/build:/usr/share/nginx/html:ro      # Svelte build output (adapter-static)
    depends_on: [oauth2-proxy, api]
    networks: [edge, backend]

  oauth2-proxy:
    image: quay.io/oauth2-proxy/oauth2-proxy:latest   # pin a specific v7.x tag in production
    command: ["--config=/etc/oauth2-proxy/oauth2-proxy.cfg"]
    volumes:
      - ./oauth2-proxy/oauth2-proxy.cfg:/etc/oauth2-proxy/oauth2-proxy.cfg:ro
    environment:
      OAUTH2_PROXY_CLIENT_ID: ${OKTA_CLIENT_ID}
      OAUTH2_PROXY_CLIENT_SECRET: ${OKTA_CLIENT_SECRET}
      OAUTH2_PROXY_COOKIE_SECRET: ${COOKIE_SECRET}
    depends_on: [redis]
    networks: [edge, backend]        # needs outbound access to Okta

  redis:
    image: redis:7-alpine
    networks: [backend]

  api:
    image: your-registry/your-webapi:latest
    # NO "ports:" – only reachable from inside the backend network
    networks: [backend]

networks:
  edge: {}
  backend:
    internal: true                   # no outbound internet; drop this if the API needs it
```

Generate the cookie secret with:
```bash
dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 | tr -d '\n' | tr '+/' '-_'; echo
```

### `oauth2-proxy/oauth2-proxy.cfg`

```toml
## --- Provider (Okta via generic OIDC) ---
provider            = "oidc"
provider_display_name = "Okta"
oidc_issuer_url     = "https://YOUR_ORG.okta.com/oauth2/default"
redirect_url        = "https://app.example.com/oauth2/callback"
scope               = "openid profile email groups offline_access"  # drop "groups" if your claim isn't scope-bound
code_challenge_method = "S256"                                      # PKCE
oidc_groups_claim   = "groups"

## --- Who is allowed in (baseline authorization) ---
email_domains   = ["example.com"]        # or ["*"] and rely on groups only
allowed_groups  = ["app-users", "app-admins"]

## --- Running behind NGINX auth_request ---
http_address    = "0.0.0.0:4180"
reverse_proxy   = true                   # trust X-Forwarded-* from NGINX
upstreams       = ["static://202"]       # we never proxy through it; it only answers auth checks
skip_provider_button = true              # go straight to Okta, no "Sign in with" page
set_xauthrequest  = true                 # emit X-Auth-Request-User/-Email/-Groups headers
pass_access_token = true                 # emit X-Auth-Request-Access-Token

## --- Session / cookie ---
cookie_name     = "_app_session"
cookie_secure   = true
cookie_httponly = true
cookie_samesite = "lax"                  # "strict" breaks the redirect back from Okta
cookie_expire   = "8h"
cookie_refresh  = "15m"                  # refresh Okta tokens in the background
session_store_type    = "redis"
redis_connection_url  = "redis://redis:6379"

## --- Misc ---
whitelist_domains = ["app.example.com"]  # where ?rd= may redirect after login
silence_ping_logging = true
```

### `nginx/snippets/security-headers.conf`

In NGINX, if a `location` block has any `add_header` of its own, it silently drops every `add_header` from the `server` block. That's why these headers go in a snippet that every such location includes.

```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Content-Type-Options    "nosniff" always;
add_header X-Frame-Options           "DENY" always;
add_header Referrer-Policy           "strict-origin-when-cross-origin" always;
add_header Content-Security-Policy   "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; frame-ancestors 'none'" always;
```

### `nginx/snippets/oauth2-auth.conf` (reused by every protected location)

```nginx
auth_request /oauth2/auth;

# Pass refreshed session cookie back to the browser
auth_request_set $auth_cookie $upstream_http_set_cookie;
add_header Set-Cookie $auth_cookie;

# Identity from oauth2-proxy
auth_request_set $auth_user   $upstream_http_x_auth_request_user;
auth_request_set $auth_email  $upstream_http_x_auth_request_email;
auth_request_set $auth_groups $upstream_http_x_auth_request_groups;
auth_request_set $auth_token  $upstream_http_x_auth_request_access_token;

include /etc/nginx/snippets/security-headers.conf;
```

### `nginx/snippets/proxy-common.conf`

```nginx
proxy_http_version 1.1;
proxy_set_header Connection        "";
proxy_set_header Host              $host;
proxy_set_header X-Real-IP         $remote_addr;
proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Host  $host;
```

### `nginx/conf.d/app.conf`

```nginx
upstream oauth2_proxy { server oauth2-proxy:4180; keepalive 16; }
upstream webapi       { server api:8080;          keepalive 32; }

server {
    listen 80;
    server_name app.example.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    http2 on;
    server_name app.example.com;

    ssl_certificate     /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;

    # Okta/oauth2-proxy cookies & headers can be large
    large_client_header_buffers 4 32k;
    proxy_buffer_size        128k;
    proxy_buffers            4 256k;
    proxy_busy_buffers_size  256k;

    include /etc/nginx/snippets/security-headers.conf;

    # ---------- oauth2-proxy public endpoints: /oauth2/start, /callback, /sign_out, /userinfo
    location /oauth2/ {
        include /etc/nginx/snippets/proxy-common.conf;
        proxy_set_header X-Auth-Request-Redirect $request_uri;
        proxy_pass http://oauth2_proxy;
    }

    # ---------- auth check subrequest (internal only)
    location = /oauth2/auth {
        internal;
        include /etc/nginx/snippets/proxy-common.conf;
        proxy_set_header X-Original-URI  $request_uri;
        proxy_set_header Content-Length  "";
        proxy_pass_request_body off;
        proxy_pass http://oauth2_proxy;
    }

    # ---------- stricter check for admin APIs (group-based authorization)
    location = /oauth2/auth-admin {
        internal;
        include /etc/nginx/snippets/proxy-common.conf;
        proxy_set_header Content-Length "";
        proxy_pass_request_body off;
        proxy_pass http://oauth2_proxy/oauth2/auth?allowed_groups=app-admins;
    }

    # ---------- Web API: 401/403 returned as-is so the SPA can react
    location /api/ {
        include /etc/nginx/snippets/oauth2-auth.conf;
        include /etc/nginx/snippets/proxy-common.conf;

        # Identity for the API. proxy_set_header overwrites any client-supplied value.
        proxy_set_header X-User        $auth_user;
        proxy_set_header X-Email       $auth_email;
        proxy_set_header X-Groups      $auth_groups;
        proxy_set_header Authorization "Bearer $auth_token";
        # Strip headers a client could use to spoof identity
        proxy_set_header X-Auth-Request-User   "";
        proxy_set_header X-Auth-Request-Email  "";
        proxy_set_header X-Auth-Request-Groups "";

        proxy_pass http://webapi;          # use http://webapi/ to strip the /api prefix
    }

    location /api/admin/ {
        auth_request /oauth2/auth-admin;   # 403 unless user is in app-admins
        auth_request_set $auth_user   $upstream_http_x_auth_request_user;
        auth_request_set $auth_email  $upstream_http_x_auth_request_email;
        auth_request_set $auth_groups $upstream_http_x_auth_request_groups;
        auth_request_set $auth_token  $upstream_http_x_auth_request_access_token;
        include /etc/nginx/snippets/security-headers.conf;
        include /etc/nginx/snippets/proxy-common.conf;
        proxy_set_header X-User        $auth_user;
        proxy_set_header X-Email       $auth_email;
        proxy_set_header X-Groups      $auth_groups;
        proxy_set_header Authorization "Bearer $auth_token";
        proxy_pass http://webapi;
    }

    # ---------- Svelte SPA: unauthenticated users get redirected to Okta
    location / {
        include /etc/nginx/snippets/oauth2-auth.conf;
        error_page 401 = @login;

        root /usr/share/nginx/html;
        try_files $uri $uri/ /index.html;   # SPA client-side routing
    }

    # Hashed, immutable build assets: long cache (still protected)
    location /_app/immutable/ {
        include /etc/nginx/snippets/oauth2-auth.conf;
        error_page 401 = @login;
        root /usr/share/nginx/html;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    location @login {
        return 302 /oauth2/start?rd=$scheme://$host$request_uri;
    }
}
```

### Svelte side (small change)

```ts
// src/lib/api.ts
export async function api(path: string, init: RequestInit = {}) {
  const res = await fetch(`/api${path}`, { credentials: 'same-origin', ...init });
  if (res.status === 401) {
    // Session expired: top-level navigation to restart the OIDC flow
    const rd = encodeURIComponent(location.pathname + location.search);
    location.href = `/oauth2/start?rd=${rd}`;
    throw new Error('redirecting to login');
  }
  if (res.status === 403) throw new Error('forbidden');
  return res;
}

// Current user for the header bar: { user, email, groups, preferredUsername }
export const me = () => fetch('/oauth2/userinfo').then(r => r.json());
```

- **Logout:** link to `/oauth2/sign_out?rd=<url-encoded Okta logout URL>`. The Okta logout URL is `https://YOUR_ORG.okta.com/oauth2/default/v1/logout?client_id=…&post_logout_redirect_uri=https://app.example.com/`. This clears the local session and the Okta session.
- **Build:** use `adapter-static` and point NGINX at the build output.

---

## 4. Hardening checklist

- **Network isolation of the API.** This is the most important item; without it there is no security at all.
- **CSRF:** `SameSite=Lax` cookies already block cross-site POST/PUT/DELETE. For extra protection, have NGINX reject state-changing `/api/` calls that lack a custom header such as `X-Requested-With`, and have the SPA always send it.
- **Defense in depth:** have the API validate the `Authorization` JWT (issuer, audience, expiry, against Okta's public keys). Then it doesn't depend on network trust alone.
- **Scripts and other services calling the API:** set `skip_jwt_bearer_tokens = true` in oauth2-proxy. It will then also accept Okta-issued bearer tokens (e.g. from the client-credentials flow) in addition to browser cookies.
- **High availability:** run two or more oauth2-proxy replicas behind the NGINX `upstream`; Redis holds the shared sessions (use Redis with replication or a managed Redis). NGINX itself scales out the usual way.
- **Load from auth checks:** each asset request triggers one auth check. Normally this is negligible. If needed, cache the `/oauth2/auth` responses for a few seconds with `proxy_cache`, keyed on the cookie.
- **Kubernetes:** the same pattern works through an ingress controller's external-auth feature, e.g. ingress-nginx's `auth-url` / `auth-signin` annotations.

---

## 5. Alternatives

| Option | When to choose it |
|---|---|
| **NGINX OSS + oauth2-proxy** (above) | Recommended. Free, widely used, keeps your existing NGINX. |
| **NGINX Plus, built-in OIDC** | You already pay for NGINX Plus and want one component instead of two. |
| **Pomerium** | You want one product that does both the proxy and the login, with per-route policies by group or claim, a built-in "who am I" endpoint, and audit logs. Good if you'll protect many internal apps. |
| **Traefik / Caddy + oauth2-proxy** | Same pattern as above, with a different proxy. |
| **Envoy / Istio (built-in OAuth2 + external-auth)** | You're already on a service mesh. |
| **Cloud-managed login at the load balancer** (AWS ALB OIDC, Google IAP, Azure Front Door, Cloudflare Access) | Your app runs on that cloud and you'd rather not operate the login component yourself. |
