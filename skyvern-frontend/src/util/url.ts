/**
 * Converts a URL string (absolute or relative) to an absolute URL.
 *
 * @param urlString - The URL string to convert (can be absolute like "https://example.com/api/v1" or relative like "/api/v1")
 * @param base - Optional base URL to use for relative URLs. Defaults to window.location.origin in browser, or "http://localhost" in Node/SSR
 * @returns An absolute URL string
 *
 * @example
 * // Absolute URL - returns as-is
 * toAbsoluteUrl("https://example.com/api/v1") // "https://example.com/api/v1"
 *
 * // Relative URL in browser
 * toAbsoluteUrl("/api/v1") // "https://current-domain.com/api/v1"
 *
 * // Relative URL with custom base
 * toAbsoluteUrl("/api/v1", "https://example.com") // "https://example.com/api/v1"
 */
export function toAbsoluteUrl(urlString: string, base?: string): string {
  // If no base is provided, use window.location.origin in browser, or fallback to localhost
  const defaultBase =
    typeof window !== "undefined" ? window.location.origin : "http://localhost";

  const baseUrl = base ?? defaultBase;

  try {
    // Try to parse as absolute URL first
    const url = new URL(urlString);
    return url.toString();
  } catch {
    // If it fails, it's likely a relative URL - parse with base
    try {
      const url = new URL(urlString, baseUrl);
      return url.toString();
    } catch (error) {
      // If both fail, return the original string
      console.warn(`Failed to parse URL: ${urlString}`, error);
      return urlString;
    }
  }
}

/**
 * Parses a URL string (absolute or relative) and returns a URL object.
 *
 * @param urlString - The URL string to parse
 * @param base - Optional base URL to use for relative URLs
 * @returns A URL object
 */
export function parseUrl(urlString: string, base?: string): URL {
  const defaultBase =
    typeof window !== "undefined" ? window.location.origin : "http://localhost";

  const baseUrl = base ?? defaultBase;

  try {
    // Try to parse as absolute URL first
    return new URL(urlString);
  } catch {
    // If it fails, it's likely a relative URL - parse with base
    return new URL(urlString, baseUrl);
  }
}

/**
 * Checks if a URL string is absolute (has protocol).
 *
 * @param urlString - The URL string to check
 * @returns true if the URL is absolute, false otherwise
 */
export function isAbsoluteUrl(urlString: string): boolean {
  try {
    new URL(urlString);
    return true;
  } catch {
    return false;
  }
}

/**
 * Converts a relative or absolute URL to use the appropriate WebSocket protocol.
 * - http:// becomes ws://
 * - https:// becomes wss://
 * - Relative URLs are resolved first, then converted
 *
 * @param urlString - The URL string to convert
 * @param base - Optional base URL for relative URLs
 * @returns A URL string with ws:// or wss:// protocol
 */
export function toWebSocketUrl(urlString: string, base?: string): string {
  const absoluteUrl = toAbsoluteUrl(urlString, base);

  try {
    const url = new URL(absoluteUrl);

    if (url.protocol === "https:") {
      url.protocol = "wss:";
    } else if (url.protocol === "http:") {
      url.protocol = "ws:";
    }
    // If already ws: or wss:, leave as-is

    return url.toString();
  } catch (error) {
    console.warn(`Failed to convert to WebSocket URL: ${urlString}`, error);
    return urlString;
  }
}
