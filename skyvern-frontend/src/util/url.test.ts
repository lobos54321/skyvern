import { describe, test, expect, beforeEach } from "vitest";
import { toAbsoluteUrl, parseUrl, isAbsoluteUrl, toWebSocketUrl } from "./url";

describe("toAbsoluteUrl", () => {
  beforeEach(() => {
    // Mock window.location.origin for tests
    Object.defineProperty(window, "location", {
      value: {
        origin: "https://example.com",
      },
      writable: true,
    });
  });

  test("handles absolute HTTP URL", () => {
    const result = toAbsoluteUrl("https://api.example.com/api/v1");
    expect(result).toBe("https://api.example.com/api/v1");
  });

  test("handles absolute HTTP URL with port", () => {
    const result = toAbsoluteUrl("http://localhost:8000/api/v1");
    expect(result).toBe("http://localhost:8000/api/v1");
  });

  test("handles relative URL with browser context", () => {
    const result = toAbsoluteUrl("/api/v1");
    expect(result).toBe("https://example.com/api/v1");
  });

  test("handles relative URL with custom base", () => {
    const result = toAbsoluteUrl("/api/v1", "https://custom.com");
    expect(result).toBe("https://custom.com/api/v1");
  });

  test("handles relative URL with custom base with port", () => {
    const result = toAbsoluteUrl("/api/v1", "http://localhost:8000");
    expect(result).toBe("http://localhost:8000/api/v1");
  });

  test("handles absolute WSS URL", () => {
    const result = toAbsoluteUrl("wss://api.example.com/api/v1");
    expect(result).toBe("wss://api.example.com/api/v1");
  });

  test("handles absolute WS URL", () => {
    const result = toAbsoluteUrl("ws://localhost:8000/api/v1");
    expect(result).toBe("ws://localhost:8000/api/v1");
  });

  test("handles nested paths", () => {
    const result = toAbsoluteUrl("/api/v1/workflows/run");
    expect(result).toBe("https://example.com/api/v1/workflows/run");
  });

  test("preserves query parameters in absolute URL", () => {
    const result = toAbsoluteUrl("https://api.example.com/api/v1?key=value");
    expect(result).toBe("https://api.example.com/api/v1?key=value");
  });

  test("preserves query parameters in relative URL", () => {
    const result = toAbsoluteUrl("/api/v1?key=value");
    expect(result).toBe("https://example.com/api/v1?key=value");
  });
});

describe("parseUrl", () => {
  beforeEach(() => {
    Object.defineProperty(window, "location", {
      value: {
        origin: "https://example.com",
      },
      writable: true,
    });
  });

  test("parses absolute URL", () => {
    const result = parseUrl("https://api.example.com/api/v1");
    expect(result.origin).toBe("https://api.example.com");
    expect(result.pathname).toBe("/api/v1");
  });

  test("parses relative URL with browser context", () => {
    const result = parseUrl("/api/v1");
    expect(result.origin).toBe("https://example.com");
    expect(result.pathname).toBe("/api/v1");
  });

  test("parses relative URL with custom base", () => {
    const result = parseUrl("/api/v1", "http://localhost:8000");
    expect(result.origin).toBe("http://localhost:8000");
    expect(result.pathname).toBe("/api/v1");
  });

  test("allows pathname manipulation", () => {
    const result = parseUrl("/api/v1");
    expect(result.pathname).toBe("/api/v1");

    // Test that we can manipulate the pathname
    const modified = result.pathname.replace("/api", "");
    expect(modified).toBe("/v1");
  });
});

describe("isAbsoluteUrl", () => {
  test("returns true for absolute HTTP URL", () => {
    expect(isAbsoluteUrl("https://example.com/api/v1")).toBe(true);
  });

  test("returns true for absolute HTTP URL with port", () => {
    expect(isAbsoluteUrl("http://localhost:8000/api/v1")).toBe(true);
  });

  test("returns true for absolute WSS URL", () => {
    expect(isAbsoluteUrl("wss://example.com/api/v1")).toBe(true);
  });

  test("returns true for absolute WS URL", () => {
    expect(isAbsoluteUrl("ws://localhost:8000/api/v1")).toBe(true);
  });

  test("returns false for relative URL", () => {
    expect(isAbsoluteUrl("/api/v1")).toBe(false);
  });

  test("returns false for path without leading slash", () => {
    expect(isAbsoluteUrl("api/v1")).toBe(false);
  });
});

describe("toWebSocketUrl", () => {
  beforeEach(() => {
    Object.defineProperty(window, "location", {
      value: {
        origin: "https://example.com",
      },
      writable: true,
    });
  });

  test("converts HTTPS to WSS", () => {
    const result = toWebSocketUrl("https://api.example.com/api/v1");
    expect(result).toBe("wss://api.example.com/api/v1");
  });

  test("converts HTTP to WS", () => {
    const result = toWebSocketUrl("http://localhost:8000/api/v1");
    expect(result).toBe("ws://localhost:8000/api/v1");
  });

  test("preserves WSS protocol", () => {
    const result = toWebSocketUrl("wss://api.example.com/api/v1");
    expect(result).toBe("wss://api.example.com/api/v1");
  });

  test("preserves WS protocol", () => {
    const result = toWebSocketUrl("ws://localhost:8000/api/v1");
    expect(result).toBe("ws://localhost:8000/api/v1");
  });

  test("converts relative URL to WSS when base is HTTPS", () => {
    // window.location.origin is https://example.com
    const result = toWebSocketUrl("/api/v1");
    expect(result).toBe("wss://example.com/api/v1");
  });

  test("converts relative URL to WS when base is HTTP", () => {
    const result = toWebSocketUrl("/api/v1", "http://localhost:8000");
    expect(result).toBe("ws://localhost:8000/api/v1");
  });

  test("converts relative URL to WSS with custom HTTPS base", () => {
    const result = toWebSocketUrl("/api/v1", "https://custom.com");
    expect(result).toBe("wss://custom.com/api/v1");
  });

  test("preserves pathname in conversion", () => {
    const result = toWebSocketUrl("https://api.example.com/api/v1/stream");
    expect(result).toBe("wss://api.example.com/api/v1/stream");
  });

  test("preserves query parameters in conversion", () => {
    const result = toWebSocketUrl("https://api.example.com/api/v1?key=value");
    expect(result).toBe("wss://api.example.com/api/v1?key=value");
  });
});
