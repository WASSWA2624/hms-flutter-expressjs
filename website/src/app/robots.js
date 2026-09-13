/**
 * Robots.txt Generator
 * 
 * Generates robots.txt to control search engine crawling
 * @file src/app/robots.js
 */

import { APP_URL } from '@/lib/constants';

export default function robots() {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: ['/api/'],
      },
    ],
    sitemap: `${APP_URL}/sitemap.xml`,
  };
}

