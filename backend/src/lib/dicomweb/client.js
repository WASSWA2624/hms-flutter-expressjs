const {
  PACS_DICOMWEB_BASE_URL,
  PACS_AUTH_MODE,
  PACS_USERNAME,
  PACS_PASSWORD,
  PACS_BEARER_TOKEN,
  PACS_TIMEOUT_MS,
} = require('@config/env');

const normalizeUrl = (value) => String(value || '').trim().replace(/\/+$/, '');

const buildAuthHeader = () => {
  const mode = String(PACS_AUTH_MODE || 'none').trim().toLowerCase();
  if (mode === 'basic') {
    const username = String(PACS_USERNAME || '').trim();
    const password = String(PACS_PASSWORD || '');
    if (!username || !password) return null;
    const token = Buffer.from(`${username}:${password}`).toString('base64');
    return `Basic ${token}`;
  }

  if (mode === 'bearer') {
    const token = String(PACS_BEARER_TOKEN || '').trim();
    if (!token) return null;
    return `Bearer ${token}`;
  }

  return null;
};

const requestDicomWeb = async (path, options = {}) => {
  const baseUrl = normalizeUrl(PACS_DICOMWEB_BASE_URL);
  if (!baseUrl) {
    throw new Error('PACS_DICOMWEB_BASE_URL is not configured');
  }

  const timeoutMs = Number(PACS_TIMEOUT_MS || 10000);
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const headers = {
      Accept: 'application/dicom+json, application/json;q=0.9, */*;q=0.8',
      ...(options.headers || {}),
    };
    const authHeader = buildAuthHeader();
    if (authHeader) {
      headers.Authorization = authHeader;
    }

    const response = await fetch(`${baseUrl}${path}`, {
      method: options.method || 'GET',
      headers,
      body: options.body,
      signal: controller.signal,
    });

    const textPayload = await response.text();
    let payload = null;
    try {
      payload = textPayload ? JSON.parse(textPayload) : null;
    } catch (_error) {
      payload = textPayload || null;
    }

    if (!response.ok) {
      throw new Error(
        `DICOMweb ${response.status}: ${typeof payload === 'string' ? payload : JSON.stringify(payload)}`
      );
    }

    return {
      status: response.status,
      headers: Object.fromEntries(response.headers.entries()),
      data: payload,
    };
  } finally {
    clearTimeout(timer);
  }
};

const dicomWebClient = {
  isConfigured() {
    return Boolean(normalizeUrl(PACS_DICOMWEB_BASE_URL));
  },

  buildStudyUrl(studyUid) {
    const baseUrl = normalizeUrl(PACS_DICOMWEB_BASE_URL);
    const safeUid = encodeURIComponent(String(studyUid || '').trim());
    return `${baseUrl}/studies/${safeUid}`;
  },

  async searchStudies(query = {}) {
    const params = new URLSearchParams();
    Object.entries(query || {}).forEach(([key, value]) => {
      if (value == null || value === '') return;
      params.set(key, String(value));
    });
    const qs = params.toString();
    return requestDicomWeb(`/studies${qs ? `?${qs}` : ''}`);
  },

  async searchSeries(studyUid) {
    const safeStudyUid = encodeURIComponent(String(studyUid || '').trim());
    return requestDicomWeb(`/studies/${safeStudyUid}/series`);
  },

  async searchInstances(studyUid, seriesUid) {
    const safeStudyUid = encodeURIComponent(String(studyUid || '').trim());
    const safeSeriesUid = encodeURIComponent(String(seriesUid || '').trim());
    return requestDicomWeb(`/studies/${safeStudyUid}/series/${safeSeriesUid}/instances`);
  },

  async getInstanceMetadata(studyUid, seriesUid, instanceUid) {
    const safeStudyUid = encodeURIComponent(String(studyUid || '').trim());
    const safeSeriesUid = encodeURIComponent(String(seriesUid || '').trim());
    const safeInstanceUid = encodeURIComponent(String(instanceUid || '').trim());
    return requestDicomWeb(
      `/studies/${safeStudyUid}/series/${safeSeriesUid}/instances/${safeInstanceUid}/metadata`
    );
  },

  async stowStudy({ studyUid = null, metadata = [], instances = [] } = {}) {
    const hasInstances = Array.isArray(instances) && instances.length > 0;
    const hasMetadata = Array.isArray(metadata) && metadata.length > 0;
    const requestPath = '/studies';

    if (hasInstances) {
      const body = JSON.stringify(instances);
      const response = await requestDicomWeb(requestPath, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/dicom+json',
        },
        body,
      });
      return {
        studyUid: studyUid || null,
        mode: 'instances',
        response: response.data,
      };
    }

    if (hasMetadata) {
      const body = JSON.stringify(metadata);
      const response = await requestDicomWeb(requestPath, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/dicom+json',
        },
        body,
      });
      return {
        studyUid: studyUid || null,
        mode: 'metadata',
        response: response.data,
      };
    }

    return {
      studyUid: studyUid || null,
      mode: 'noop',
      response: null,
    };
  },
};

module.exports = dicomWebClient;
