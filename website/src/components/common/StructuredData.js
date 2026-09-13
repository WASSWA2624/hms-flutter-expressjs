/**
 * StructuredData - JSON-LD structured data component
 * 
 * Renders structured data (JSON-LD) for SEO purposes
 * @component
 * @param {Object} props
 * @param {Object} props.data - Structured data object (schema.org format)
 * @returns {JSX.Element} Script tag with JSON-LD structured data
 */
import React from 'react';

export const StructuredData = React.memo(({ data }) => {
  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(data) }}
    />
  );
});

StructuredData.displayName = 'StructuredData';

