export function rc4(keyBytes, dataBytes) {
  const S = new Uint8Array(256);
  for (let i = 0; i < 256; i++) S[i] = i;
  let j = 0;
  const kl = keyBytes.length;
  for (let i = 0; i < 256; i++) {
    j = (j + S[i] + keyBytes[i % kl]) & 0xff;
    const t = S[i];
    S[i] = S[j];
    S[j] = t;
  }
  const out = new Uint8Array(dataBytes.length);
  let i = 0;
  j = 0;
  for (let k = 0; k < dataBytes.length; k++) {
    i = (i + 1) & 0xff;
    j = (j + S[i]) & 0xff;
    const t = S[i];
    S[i] = S[j];
    S[j] = t;
    out[k] = dataBytes[k] ^ S[(S[i] + S[j]) & 0xff];
  }
  return out;
}

export function hexToBytes(hex) {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(hex.substr(i * 2, 2), 16);
  }
  return out;
}

export function xorBytes(data, mask) {
  const out = new Uint8Array(data.length);
  for (let i = 0; i < data.length; i++) {
    out[i] = data[i] ^ mask[i % mask.length];
  }
  return out;
}

export function chunkKey(masterBytes, chunkName) {
  const name = Buffer.from(chunkName, "ascii");
  const key = new Uint8Array(masterBytes.length + name.length);
  key.set(masterBytes, 0);
  key.set(name, masterBytes.length);
  return key;
}