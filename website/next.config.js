/** @type {import('next').NextConfig} */
const nextConfig = {
  // Self-contained server bundle for cPanel/Passenger hosting: produces
  // .next/standalone with only the dependencies actually used at runtime.
  output: 'standalone',
  compiler: {
    styledComponents: true,
  },
  images: {
    // Served as-is rather than optimised at request time. The site ships a
    // handful of small PNGs already exported at the sizes it uses, and this
    // keeps the deployment free of the native `sharp` binary, which would
    // otherwise have to match the host's platform.
    unoptimized: true,
    localPatterns: [
      {
        pathname: '/logos/**',
      },
      {
        pathname: '/images/**',
      },
    ],
  },
};

module.exports = nextConfig;
