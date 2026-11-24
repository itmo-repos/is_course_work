const backend = (process.env.BACKEND_URL || 'http://127.0.0.1:8080').replace(/\/$/, '');

const config = {
  async rewrites() {
    return [{ source: '/api/:path*', destination: backend + '/api/:path*' }];
  },
};

export default config;
