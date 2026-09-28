# -*- coding: utf-8 -*-
#
# Note: Portal micro-frontend paths, shared by the app clients that serve them
#

locals {
  ###
  # The UMCCR portal hosts several independently deployed frontends on one domain, each on its own
  # URL path prefix, all sharing the `orcaui-app-<workspace>` client below so that a single sign-in
  # covers every one of them.
  #
  # Cognito matches `redirect_uri` against `callback_urls` EXACTLY: no prefix or wildcard matching.
  # An app served at https://portal.umccr.org/hub/ therefore needs that precise string registered,
  # or the hosted UI rejects the sign-in with `redirect_mismatch`. Hence this list.
  #
  # Trailing slashes are significant and must match what the apps send. Each app derives its
  # redirect from `window.location.origin` plus its own base path, and those base paths end in a
  # slash (Vite's BASE_URL, Next.js `basePath` + "/").
  #
  # ORDERING: add a path here and apply BEFORE the app starts sending it. The reverse order breaks
  # sign-in for that app.
  #
  # This list mirrors `pathPrefix` in lib/portal/apps.ts of umccr/frontend-infrastructure-pipelines,
  # which owns the buckets and CloudFront behaviours. Keep the two in step: an app can be routed
  # without being able to sign in, and vice versa.
  #
  # "" is the app at the site root (orca-ui).
  ###
  portal_app_paths = [
    "",            # orca-ui
    "/v2/",        # orca-ui-v2
    "/hub/",       # umccr/hub
    "/orcahouse/", # umccr/orcahouse-ui
  ]
}
