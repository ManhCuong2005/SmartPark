// One foreground controller owns all three local development servers.
// Uses only Node built-ins; never terminates a process it did not start.
const fs = require('node:fs');
const path = require('node:path');
const net = require('node:net');
const { spawn, spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const logDir = path.join(root, '.smartpark', 'logs');
const noOpen = process.argv.includes('--no-open');
const checkOnly = process.argv.includes('--check');
const allowed = new Set(['--no-open', '--check']);
const children = new Set();
let stopping = false;

const services = [
  { name: 'Customer', port: 8081, cwd: root,
    command: 'flutter.bat run -d web-server --web-hostname 127.0.0.1 --web-port 8081 -t lib/main.dart' },
  { name: 'Staff', port: 8082, cwd: root,
    command: 'flutter.bat run -d web-server --web-hostname 127.0.0.1 --web-port 8082 -t lib/main_staff.dart' },
  { name: 'Admin', port: 5173, cwd: path.join(root, 'admin-web'),
    command: 'npm.cmd run dev -- --host 127.0.0.1 --port 5173 --strictPort' },
];

function shell(command, cwd) {
  return spawn(process.env.ComSpec || 'cmd.exe', ['/d', '/s', '/c', command], {
    cwd, windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'],
  });
}

function hasCommand(name) {
  return spawnSync('where.exe', [name], { windowsHide: true, stdio: 'ignore' }).status === 0;
}

function portAvailable(port) {
  return new Promise((resolve, reject) => {
    const probe = net.createServer();
    probe.once('error', error => reject(new Error(
      `Port ${port} is unavailable (${error.code}). Close the existing server or choose another port in tools/run-smartpark.cjs. No existing process was stopped.`
    )));
    probe.listen(port, '127.0.0.1', () => probe.close(resolve));
  });
}

function newer(input, output) {
  return !fs.existsSync(output) || fs.statSync(input).mtimeMs > fs.statSync(output).mtimeMs;
}

function launch(name, command, cwd, server = false) {
  const logfile = path.join(logDir, name.toLowerCase() + '.log');
  const output = fs.createWriteStream(logfile, { flags: 'w' });
  const child = shell(command, cwd);
  children.add(child);
  let tail = '';
  function record(chunk) {
    output.write(chunk);
    tail = (tail + chunk.toString()).slice(-6000);
  }
  child.stdout.on('data', record);
  child.stderr.on('data', record);
  child.on('close', () => { children.delete(child); output.end(); });
  child.on('error', error => { if (!stopping) fail(new Error(`${name}: ${error.message}`)); });
  if (server) child.on('exit', code => {
    if (!stopping) fail(new Error(`${name} exited unexpectedly (${code}).\n${tail}\nLog: ${logfile}`));
  });
  return { child, tail: () => tail, logfile };
}

function prepare(name, command, cwd) {
  console.log(`Preparing ${name}...`);
  const run = launch(name, command, cwd);
  return new Promise((resolve, reject) => {
    run.child.once('error', reject);
    run.child.once('exit', code => code === 0 ? resolve() : reject(new Error(
      `${name} failed (${code}).\n${run.tail()}\nLog: ${run.logfile}`
    )));
  });
}

function delay(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }

async function waitForServer(service, run) {
  const url = `http://127.0.0.1:${service.port}`;
  const deadline = Date.now() + 300000;
  while (!stopping && Date.now() < deadline) {
    try {
      // Flutter binds its HTTP port before compilation finishes. Wait for its
      // actual ready message, not just the early bootstrap HTML response.
      if (service.name !== 'Admin' && !run.tail().includes('is being served at')) {
        await delay(1000);
        continue;
      }
      const response = await fetch(url, { signal: AbortSignal.timeout(2500) });
      if (response.ok && (await response.text()).includes('<html')) {
        console.log(`[READY] ${service.name.padEnd(8)} ${url}`);
        return;
      }
    } catch { /* Flutter may still be compiling its first web bundle. */ }
    await delay(1000);
  }
  if (!stopping) throw new Error(`${service.name} did not become ready within 5 minutes. See ${logDir}.`);
}

async function shutdown(code = 0) {
  if (stopping) return;
  stopping = true;
  console.log('\nStopping the SmartPark servers started by this launcher...');
  await Promise.all([...children].map(child => new Promise(resolve => {
    if (!child.pid) return resolve();
    const killer = spawn('taskkill.exe', ['/pid', String(child.pid), '/t', '/f'], {
      windowsHide: true, stdio: 'ignore',
    });
    killer.once('error', resolve);
    killer.once('close', resolve);
  })));
  process.exit(code);
}

function fail(error) {
  if (stopping) return;
  console.error(`\n[ERROR] ${error.message}`);
  void shutdown(1);
}

process.on('SIGINT', () => void shutdown());
process.on('SIGTERM', () => void shutdown());
process.on('SIGHUP', () => void shutdown());
process.on('uncaughtException', fail);
process.on('unhandledRejection', fail);

async function main() {
  if (process.platform !== 'win32') throw new Error('This launcher is for Windows.');
  const unknown = process.argv.slice(2).filter(arg => !allowed.has(arg));
  if (unknown.length) throw new Error(`Unknown option: ${unknown.join(', ')}. Available: --no-open, --check.`);
  for (const name of ['flutter.bat', 'node.exe', 'npm.cmd']) {
    if (!hasCommand(name)) throw new Error(`${name} was not found in PATH.`);
  }
  console.log('SmartPark - Customer / Staff / Admin\n');
  for (const service of services) {
    await portAvailable(service.port);
    console.log(`${service.name.padEnd(8)} http://127.0.0.1:${service.port}`);
  }
  if (checkOnly) {
    console.log('\nPreflight passed. No servers or browsers were started.');
    return;
  }
  fs.mkdirSync(logDir, { recursive: true });
  const config = path.join(root, '.dart_tool', 'package_config.json');
  if (newer(path.join(root, 'pubspec.yaml'), config)) await prepare('Flutter-packages', 'flutter.bat pub get', root);
  if (!fs.existsSync(path.join(root, 'web', 'sqlite3.wasm')) ||
      !fs.existsSync(path.join(root, 'web', 'drift_worker.dart.js')) ||
      newer(path.join(root, 'pubspec.lock'), path.join(root, 'web', 'drift_worker.dart.js'))) {
    await prepare('Offline-web-assets', 'dart.bat run tools/prepare_web.dart', root);
  }
  const admin = path.join(root, 'admin-web');
  if (!fs.existsSync(path.join(admin, 'node_modules', 'vite', 'bin', 'vite.js')) ||
      newer(path.join(admin, 'package-lock.json'), path.join(admin, 'node_modules', '.package-lock.json'))) {
    await prepare('Admin-packages', 'npm.cmd install', admin);
  }
  console.log('\nStarting servers. The first Flutter compilation can take a few minutes.');
  console.log('Keep this window open. Press Ctrl+C to stop all three.');
  console.log(`Logs: ${logDir}\n`);
  // Both Flutter entrypoints share build/flutter_assets. Serialize their
  // initial compilation so shader and asset writes cannot collide on Windows.
  for (const service of [services[2], services[0], services[1]]) {
    if (stopping) return;
    const run = launch(service.name, service.command, service.cwd, true);
    await waitForServer(service, run);
  }
  if (!stopping && !noOpen) for (const service of services) {
    const url = `http://127.0.0.1:${service.port}`;
    const browser = spawn(process.env.ComSpec || 'cmd.exe', ['/d', '/s', '/c', `start "" "${url}"`], {
      windowsHide: true, stdio: 'ignore',
    });
    browser.on('error', () => console.log(`Open ${url} manually in your browser.`));
    browser.unref();
  }
  if (!stopping) console.log(`\nAll three are ready.${noOpen ? ' Browser opening is disabled.' : ' Opened in your default browser.'}\nThe localhost links remain usable while this window is running.`);
}

void main().catch(fail);
