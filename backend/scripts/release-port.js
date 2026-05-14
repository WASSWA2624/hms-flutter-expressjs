const { execFile } = require('child_process');
const net = require('net');

const DEFAULT_PORT = 3000;
const WAIT_TIMEOUT_MS = 5000;
const WAIT_INTERVAL_MS = 150;

const portArg = Number(process.argv[2] || process.env.PORT || DEFAULT_PORT);
const port = Number.isInteger(portArg) && portArg > 0 && portArg <= 65535 ? portArg : DEFAULT_PORT;

const execFileAsync = (file, args) =>
  new Promise((resolve) => {
    execFile(file, args, { windowsHide: true }, (error, stdout, stderr) => {
      resolve({ error, stdout: stdout || '', stderr: stderr || '' });
    });
  });

const isOwnPid = (pid) => Number(pid) === process.pid || Number(pid) === process.ppid;

const uniquePids = (pids) =>
  Array.from(
    new Set(
      pids
        .map((pid) => String(pid || '').trim())
        .filter((pid) => /^\d+$/.test(pid) && !isOwnPid(pid))
    )
  );

const getWindowsListeningPids = async () => {
  const { stdout } = await execFileAsync('netstat.exe', ['-ano', '-p', 'TCP']);
  const pids = [];
  const portSuffix = `:${port}`;

  for (const line of stdout.split(/\r?\n/)) {
    const columns = line.trim().split(/\s+/);
    if (columns.length < 5 || columns[0] !== 'TCP') continue;

    const localAddress = columns[1] || '';
    const state = columns[3] || '';
    const pid = columns[4] || '';

    if (state !== 'LISTENING') continue;
    if (!localAddress.endsWith(portSuffix)) continue;

    pids.push(pid);
  }

  return uniquePids(pids);
};

const getUnixListeningPids = async () => {
  const lsofResult = await execFileAsync('lsof', ['-ti', `tcp:${port}`, '-sTCP:LISTEN']);
  if (!lsofResult.error && lsofResult.stdout.trim()) {
    return uniquePids(lsofResult.stdout.split(/\s+/));
  }

  const ssResult = await execFileAsync('ss', ['-ltnp']);
  if (ssResult.error || !ssResult.stdout.trim()) return [];

  const pids = [];
  const pidPattern = /pid=(\d+)/g;
  const portPattern = new RegExp(`:${port}\\b`);

  for (const line of ssResult.stdout.split(/\r?\n/)) {
    if (!portPattern.test(line)) continue;
    let match;
    while ((match = pidPattern.exec(line)) !== null) {
      pids.push(match[1]);
    }
  }

  return uniquePids(pids);
};

const getListeningPids = async () => {
  if (process.platform === 'win32') {
    return getWindowsListeningPids();
  }

  return getUnixListeningPids();
};

const killProcessTree = async (pid) => {
  if (process.platform === 'win32') {
    return execFileAsync('taskkill.exe', ['/PID', pid, '/T', '/F']);
  }

  return execFileAsync('kill', ['-TERM', pid]);
};

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const canBindPort = () =>
  new Promise((resolve) => {
    const server = net.createServer();

    server.once('error', () => resolve(false));
    server.once('listening', () => {
      server.close(() => resolve(true));
    });

    server.listen(port, '0.0.0.0');
  });

const waitUntilReleased = async () => {
  const startedAt = Date.now();

  while (Date.now() - startedAt < WAIT_TIMEOUT_MS) {
    if (await canBindPort()) return true;
    await sleep(WAIT_INTERVAL_MS);
  }

  return false;
};

const releasePort = async () => {
  const pids = await getListeningPids();

  if (pids.length === 0) {
    console.log(`[startup] Port ${port} is free.`);
    return;
  }

  console.log(`[startup] Releasing port ${port}; stopping PID(s): ${pids.join(', ')}`);

  for (const pid of pids) {
    const result = await killProcessTree(pid);
    if (result.error) {
      throw new Error(`Failed to stop PID ${pid}: ${result.stderr || result.error.message}`);
    }
  }

  if (!(await waitUntilReleased())) {
    throw new Error(`Port ${port} is still in use after stopping PID(s): ${pids.join(', ')}`);
  }

  console.log(`[startup] Port ${port} released.`);
};

releasePort().catch((error) => {
  console.error(`[startup] Failed to release port ${port}: ${error.message}`);
  process.exit(1);
});
