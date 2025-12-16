import { parseUrl, toWebSocketUrl } from "./url";

const apiBaseUrl = import.meta.env.VITE_API_BASE_URL as string;

if (!apiBaseUrl) {
  console.warn("apiBaseUrl environment variable was not set");
}

const environment = import.meta.env.VITE_ENVIRONMENT as string;

if (!environment) {
  console.warn("environment environment variable was not set");
}

const buildTimeApiKey: string | null =
  typeof import.meta.env.VITE_SKYVERN_API_KEY === "string"
    ? import.meta.env.VITE_SKYVERN_API_KEY
    : null;

const artifactApiBaseUrl = import.meta.env.VITE_ARTIFACT_API_BASE_URL;

if (!artifactApiBaseUrl) {
  console.warn("artifactApiBaseUrl environment variable was not set");
}

const apiPathPrefix = import.meta.env.VITE_API_PATH_PREFIX ?? "";

const API_KEY_STORAGE_KEY = "skyvern.apiKey";

const lsKeys = {
  browserSessionId: "skyvern.browserSessionId",
  apiKey: API_KEY_STORAGE_KEY,
};

const wssBaseUrl = import.meta.env.VITE_WSS_BASE_URL;

// Convert WSS URL (which may be relative) and strip /api prefix if present
const newWssBaseUrl = (() => {
  const wsUrl = toWebSocketUrl(wssBaseUrl);
  const url = parseUrl(wsUrl);
  if (url.pathname.startsWith("/api")) {
    url.pathname = url.pathname.replace(/^\/api/, "");
  }
  return url.toString();
})();

// Base URL for the Runs API (strip a leading `/api` segment: /api/v1 -> /v1)
const runsApiBaseUrl = (() => {
  const url = parseUrl(apiBaseUrl);
  if (url.pathname.startsWith("/api")) {
    url.pathname = url.pathname.replace(/^\/api/, "");
  }
  return `${url.origin}${url.pathname}`;
})();

let runtimeApiKey: string | null | undefined;

function readPersistedApiKey(): string | null {
  if (typeof window === "undefined") {
    return null;
  }

  return window.sessionStorage.getItem(API_KEY_STORAGE_KEY);
}

function getRuntimeApiKey(): string | null {
  if (runtimeApiKey !== undefined) {
    return runtimeApiKey;
  }

  const persisted = readPersistedApiKey();
  const candidate = persisted ?? buildTimeApiKey;

  // Treat YOUR_API_KEY as missing. We may inherit this from .env.example
  // in some cases of misconfiguration.
  runtimeApiKey = candidate === "YOUR_API_KEY" ? null : candidate;
  return runtimeApiKey;
}

function persistRuntimeApiKey(value: string): void {
  runtimeApiKey = value;
  if (typeof window !== "undefined") {
    window.sessionStorage.setItem(API_KEY_STORAGE_KEY, value);
  }
}

function clearRuntimeApiKey(): void {
  runtimeApiKey = null;
  if (typeof window !== "undefined") {
    window.sessionStorage.removeItem(API_KEY_STORAGE_KEY);
  }
}

const useNewRunsUrl = true as const;

export {
  apiBaseUrl,
  runsApiBaseUrl,
  environment,
  artifactApiBaseUrl,
  apiPathPrefix,
  lsKeys,
  wssBaseUrl,
  newWssBaseUrl,
  getRuntimeApiKey,
  persistRuntimeApiKey,
  clearRuntimeApiKey,
  useNewRunsUrl,
};
