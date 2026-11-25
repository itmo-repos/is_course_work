const backend = (process.env.BACKEND_URL || 'http://127.0.0.1:8080').replace(/\/$/, '');

const config = {
  experimental: {
    // Match Spring's multipart request limit, including overhead around the scan.
    proxyClientMaxBodySize: 17 * 1024 * 1024,
  },
  async rewrites() {
    return [{ source: '/api/:path*', destination: backend + '/api/:path*' }];
  },
};

export default config;
