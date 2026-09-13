/**
 * Styled Components Registry
 *
 * Enables SSR style collection for styled-components in the Next.js App Router.
 * @file src/lib/registry.js
 */
'use client';

import React, { useState } from 'react';
import { useServerInsertedHTML } from 'next/navigation';
import { ServerStyleSheet, StyleSheetManager } from 'styled-components';

/**
 * Wrap the app so server-rendered styled-components styles are inserted into HTML.
 * @param {Object} props
 * @param {React.ReactNode} props.children - App tree
 * @returns {JSX.Element}
 */
export default function StyledComponentsRegistry({ children }) {
  const [styledComponentsStyleSheet] = useState(() => new ServerStyleSheet());

  useServerInsertedHTML(() => {
    const styles = styledComponentsStyleSheet.getStyleElement();
    styledComponentsStyleSheet.instance.clearTag();
    return <>{styles}</>;
  });

  if (typeof window !== 'undefined') {
    return <>{children}</>;
  }

  return (
    <StyleSheetManager sheet={styledComponentsStyleSheet.instance}>
      {children}
    </StyleSheetManager>
  );
}
