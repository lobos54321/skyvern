import { createServer } from "http";
import handler from "serve-handler";
import open from "open";

const port = process.env.LOCAL_SERVER_PORT || 8080;
const url = `http://localhost:${port}`;

const server = createServer((request, response) => {
  // You pass two more arguments for config and middleware
  // More details here: https://github.com/vercel/serve-handler#options
  return handler(request, response, {
    public: "dist",
    rewrites: [
      {
        source: "**",
        destination: "/index.html",
      },
    ],
  });
});

server.listen(port, async () => {
  console.log(`Running at ${url}`);
  // Only open browser in development mode, not in Docker container
  if (process.env.NODE_ENV !== 'production') {
    await open(url);
  }
});
