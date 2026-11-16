// Small original chime; no external sound asset or license is needed.
const fs = require('node:fs');
const path = require('node:path');
const rate = 22050, count = Math.floor(rate * .38);
const buffer = Buffer.alloc(44 + count * 2);
buffer.write('RIFF', 0); buffer.writeUInt32LE(36 + count * 2, 4); buffer.write('WAVEfmt ', 8);
buffer.writeUInt32LE(16, 16); buffer.writeUInt16LE(1, 20); buffer.writeUInt16LE(1, 22);
buffer.writeUInt32LE(rate, 24); buffer.writeUInt32LE(rate * 2, 28);
buffer.writeUInt16LE(2, 32); buffer.writeUInt16LE(16, 34);
buffer.write('data', 36); buffer.writeUInt32LE(count * 2, 40);
for (let i = 0; i < count; i++) {
 const t = i / rate, envelope = Math.min(1, t / .008) * Math.exp(-t * 11);
 const value = .55 * envelope * (Math.sin(2 * Math.PI * 1600 * t) + .3 * Math.sin(2 * Math.PI * 2400 * t));
 buffer.writeInt16LE(Math.round(32767 * value), 44 + i * 2);
}
const directory = path.resolve(__dirname, '../assets/audio');
fs.mkdirSync(directory, {recursive: true});
fs.writeFileSync(path.join(directory, 'scan_success.wav'), buffer);
