/**
 * Integration test to verify URL handling works correctly with both
 * absolute and relative base URLs
 */

import { describe, test, expect, beforeEach } from "vitest";
import { parseUrl, toWebSocketUrl } from "./url";

describe("URL Integration Tests - Absolute URLs", () => {
  beforeEach(() => {
    // Simulate deployed environment with HTTPS
    Object.defineProperty(window, "location", {
      value: {
        origin: "https://app.example.com",
      },
      writable: true,
    });
  });

  test("absolute API base URL works", () => {
    const apiBaseUrl = "https://api.example.com/api/v1";
    const url = parseUrl(apiBaseUrl);
    const pathname = url.pathname.replace("/api", "");
    const apiSansApiV1BaseUrl = `${url.origin}${pathname}`;

    expect(apiSansApiV1BaseUrl).toBe("https://api.example.com/v1");
  });

  test("absolute WSS base URL works", () => {
    const wssBaseUrl = "wss://api.example.com/api/v1";
    const wsUrl = toWebSocketUrl(wssBaseUrl);
    const url = parseUrl(wsUrl);

    if (url.pathname.startsWith("/api")) {
      url.pathname = url.pathname.replace(/^\/api/, "");
    }
    const newWssBaseUrl = url.toString();

    expect(newWssBaseUrl).toBe("wss://api.example.com/v1");
  });

  test("absolute HTTP converts to WS", () => {
    const wssBaseUrl = "http://localhost:8000/api/v1";
    const wsUrl = toWebSocketUrl(wssBaseUrl);
    const url = parseUrl(wsUrl);

    if (url.pathname.startsWith("/api")) {
      url.pathname = url.pathname.replace(/^\/api/, "");
    }
    const newWssBaseUrl = url.toString();

    expect(newWssBaseUrl).toBe("ws://localhost:8000/v1");
  });
});

describe("URL Integration Tests - Relative URLs", () => {
  beforeEach(() => {
    // Simulate deployed environment behind nginx with relative URLs
    Object.defineProperty(window, "location", {
      value: {
        origin: "https://app.example.com",
      },
      writable: true,
    });
  });

  test("relative API base URL works", () => {
    const apiBaseUrl = "/api/v1";
    const url = parseUrl(apiBaseUrl);
    const pathname = url.pathname.replace("/api", "");
    const apiSansApiV1BaseUrl = `${url.origin}${pathname}`;

    expect(apiSansApiV1BaseUrl).toBe("https://app.example.com/v1");
  });

  test("relative WSS base URL converts to WSS", () => {
    const wssBaseUrl = "/api/v1";
    const wsUrl = toWebSocketUrl(wssBaseUrl);
    const url = parseUrl(wsUrl);

    if (url.pathname.startsWith("/api")) {
      url.pathname = url.pathname.replace(/^\/api/, "");
    }
    const newWssBaseUrl = url.toString();

    expect(newWssBaseUrl).toBe("wss://app.example.com/v1");
  });

  test("runsApiBaseUrl computation works with relative URL", () => {
    const apiBaseUrl = "/api/v1";
    const url = parseUrl(apiBaseUrl);

    if (url.pathname.startsWith("/api")) {
      url.pathname = url.pathname.replace(/^\/api/, "");
    }
    const runsApiBaseUrl = `${url.origin}${url.pathname}`;

    expect(runsApiBaseUrl).toBe("https://app.example.com/v1");
  });
});

describe("URL Integration Tests - HTTP to WS conversion", () => {
  test("HTTP origin converts relative URL to WS", () => {
    Object.defineProperty(window, "location", {
      value: {
        origin: "http://localhost:3000",
      },
      writable: true,
    });

    const wssBaseUrl = "/api/v1";
    const wsUrl = toWebSocketUrl(wssBaseUrl);
    const url = parseUrl(wsUrl);

    if (url.pathname.startsWith("/api")) {
      url.pathname = url.pathname.replace(/^\/api/, "");
    }
    const newWssBaseUrl = url.toString();

    expect(newWssBaseUrl).toBe("ws://localhost:3000/v1");
  });

  test("HTTPS origin converts relative URL to WSS", () => {
    Object.defineProperty(window, "location", {
      value: {
        origin: "https://secure.example.com",
      },
      writable: true,
    });

    const wssBaseUrl = "/api/v1";
    const wsUrl = toWebSocketUrl(wssBaseUrl);
    const url = parseUrl(wsUrl);

    if (url.pathname.startsWith("/api")) {
      url.pathname = url.pathname.replace(/^\/api/, "");
    }
    const newWssBaseUrl = url.toString();

    expect(newWssBaseUrl).toBe("wss://secure.example.com/v1");
  });
});
