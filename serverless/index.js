'use strict';

/**
 * 以越之名 · 双人同步云函数（腾讯云 SCF + COS）
 *
 * 提供 REST 风格接口，供 Flutter 端 ScfSyncClient 调用：
 *  - /rooms       房间（情侣码）
 *  - /pairdata    统一数据文档（7 种业务类型）
 *  - /photos      照片文件（COS 存储，上传/下载/删除）
 *
 * 数据全部存于 COS 对象：
 *  - sync/rooms/{code}.json
 *  - sync/pairdata/{roomId}/{cloudId}.json
 *  - sync/photos/{roomId}/{name}
 *
 * 鉴权：请求头 X-Sync-Secret 必须等于环境变量 SYNC_SECRET（防陌生人访问）。
 */

const COS = require('cos-nodejs-sdk-v5');
const crypto = require('crypto');

let cos;
const BUCKET = process.env.COS_BUCKET || '';
const REGION = process.env.COS_REGION || '';
const SECRET = process.env.SYNC_SECRET || '';
const ROOM_CODE_RE = /^[A-HJKMNPQRSTUVWXYZ2-9]{6}$/;
const SAFE_ID_RE = /^[A-Za-z0-9._-]{1,160}$/;

function getCos() {
  if (cos) return cos;
  cos = new COS({
    // SCF 运行环境自动注入临时密钥
    SecretId: process.env.TENCENTCLOUD_SECRETID,
    SecretKey: process.env.TENCENTCLOUD_SECRETKEY,
    SecurityToken: process.env.TENCENTCLOUD_SESSIONTOKEN,
  });
  return cos;
}

function unauthorized() {
  return {
    isBase64Encoded: false,
    statusCode: 401,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ error: 'unauthorized' }),
  };
}

function hasValidSecret(headers) {
  if (!SECRET) return false; // 未配置时关闭服务，避免意外公开全部数据
  const supplied = headers['x-sync-secret'];
  if (typeof supplied !== 'string') return false;
  const expectedBytes = Buffer.from(SECRET);
  const suppliedBytes = Buffer.from(supplied);
  return expectedBytes.length === suppliedBytes.length &&
    crypto.timingSafeEqual(expectedBytes, suppliedBytes);
}

function normalizeHeaders(raw) {
  const normalized = {};
  for (const [key, value] of Object.entries(raw || {})) {
    normalized[String(key).toLowerCase()] = value;
  }
  return normalized;
}

function normalizeQuery(event) {
  const parameters = event.queryStringParameters;
  if (parameters && typeof parameters === 'object' && Object.keys(parameters).length > 0) {
    return parameters;
  }
  const queryString = event.queryString;
  if (queryString && typeof queryString === 'object') return queryString;
  if (typeof queryString === 'string') {
    return Object.fromEntries(new URLSearchParams(queryString));
  }
  return {};
}

function okJson(data, statusCode = 200) {
  return {
    isBase64Encoded: false,
    statusCode,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  };
}

function fail(msg, statusCode = 500) {
  return okJson({ error: msg }, statusCode);
}

function readJson(key) {
  return new Promise((resolve, reject) => {
    getCos().getObject(
      { Bucket: BUCKET, Region: REGION, Key: key },
      (err, res) => {
        if (err) {
          if (err.statusCode === 404) return resolve(null);
          return reject(err);
        }
        try {
          resolve(JSON.parse(res.Body.toString('utf8')));
        } catch (e) {
          reject(e);
        }
      },
    );
  });
}

function writeJson(key, data) {
  return new Promise((resolve, reject) => {
    getCos().putObject(
      {
        Bucket: BUCKET,
        Region: REGION,
        Key: key,
        Body: JSON.stringify(data),
        ContentType: 'application/json',
      },
      (err) => (err ? reject(err) : resolve()),
    );
  });
}

function deleteObject(key) {
  return new Promise((resolve, reject) => {
    getCos().deleteObject(
      { Bucket: BUCKET, Region: REGION, Key: key },
      (err) => (err ? reject(err) : resolve()),
    );
  });
}

async function listObjects(prefix) {
  const keys = [];
  let marker;
  do {
    const data = await new Promise((resolve, reject) => {
      getCos().getBucket(
        {
          Bucket: BUCKET,
          Region: REGION,
          Prefix: prefix,
          ...(marker ? { Marker: marker } : {}),
        },
        (err, result) => (err ? reject(err) : resolve(result || {})),
      );
    });
    keys.push(...(data.Contents || []).map((c) => c.Key));
    marker = data.IsTruncated === 'true' || data.IsTruncated === true
      ? data.NextMarker
      : undefined;
  } while (marker);
  return keys;
}

function genId() {
  return crypto.randomUUID();
}

// ──────── 房间 ────────

async function getRoom(code) {
  return readJson(`sync/rooms/${code}.json`);
}

async function handleRooms(method, query, body) {
  const code = query.code;
  if (method === 'GET') {
    if (!ROOM_CODE_RE.test(code || '')) return fail('invalid room code', 400);
    const room = await getRoom(code);
    return okJson({ room: room || null });
  }
  if (method === 'POST') {
    if (!body || !ROOM_CODE_RE.test(body.code || '') ||
        !Array.isArray(body.members) || body.members.length !== 1 ||
        typeof body.members[0] !== 'string' || !body.members[0]) {
      return fail('invalid room', 400);
    }
    if (await getRoom(body.code)) return fail('room already exists', 409);
    await writeJson(`sync/rooms/${body.code}.json`, {
      code: body.code,
      members: body.members,
      createdAt: new Date().toISOString(),
    });
    return okJson({ ok: true });
  }
  return fail('method not allowed', 405);
}

async function handleRoomUpdate(code, body) {
  if (!ROOM_CODE_RE.test(code || '')) return fail('invalid room code', 400);
  const room = await getRoom(code);
  if (!room) return fail('room not found', 404);
  if (!body || !Array.isArray(body.members) || body.members.length !== 1 ||
      typeof body.members[0] !== 'string' || !body.members[0]) {
    return fail('invalid member', 400);
  }
  const members = [...new Set([...(room.members || []), body.members[0]])];
  if (members.length > 2) return fail('room is full', 409);
  room.members = members;
  await writeJson(`sync/rooms/${code}.json`, room);
  return okJson(room);
}

// ──────── 统一数据文档 ────────

async function handlePairData(method, cloudId, query, body) {
  if (method === 'GET') {
    const roomId = query.roomId;
    if (!ROOM_CODE_RE.test(roomId || '')) return fail('invalid roomId', 400);
    if (!await getRoom(roomId)) return fail('room not found', 404);
    const keys = await listObjects(`sync/pairdata/${roomId}/`);
    const docs = [];
    // 避免数百个 COS 读取完全串行，也避免一次发起过多请求。
    for (let start = 0; start < keys.length; start += 20) {
      const batch = await Promise.all(keys.slice(start, start + 20).map(readJson));
      docs.push(...batch.filter(Boolean));
    }
    // 按 updatedAt 排序（服务器与客户端时间一致；客户端会再做 LWW）
    docs.sort((a, b) => (a.updatedAt || '') < (b.updatedAt || '') ? -1 : 1);
    return okJson({ docs });
  }
  if (method === 'POST') {
    if (!body || !ROOM_CODE_RE.test(body.roomId || '') ||
        typeof body.type !== 'string' || typeof body.ownerId !== 'string' ||
        !body.data || typeof body.data !== 'object') {
      return fail('invalid doc', 400);
    }
    if (!await getRoom(body.roomId)) return fail('room not found', 404);
    const id = genId();
    const doc = { ...body, cloudId: id, deleted: false };
    await writeJson(`sync/pairdata/${body.roomId}/${id}.json`, doc);
    return okJson({ cloudId: id }, 201);
  }
  if (method === 'PUT' && cloudId) {
    const roomId = body && body.roomId;
    if (!ROOM_CODE_RE.test(roomId || '') || !SAFE_ID_RE.test(cloudId)) {
      return fail('invalid document key', 400);
    }
    if (!await getRoom(roomId)) return fail('room not found', 404);
    await writeJson(`sync/pairdata/${roomId}/${cloudId}.json`, {
      ...body,
      cloudId,
      deleted: false,
    });
    return okJson({ ok: true });
  }
  if (method === 'DELETE' && cloudId) {
    const roomId = query.roomId;
    if (!ROOM_CODE_RE.test(roomId || '') || !SAFE_ID_RE.test(cloudId)) {
      return fail('invalid document key', 400);
    }
    const key = `sync/pairdata/${roomId}/${cloudId}.json`;
    const existing = await readJson(key);
    if (existing) {
      // 保留删除墓碑，另一台离线设备恢复后才能得知该记录已删除。
      await writeJson(key, {
        ...existing,
        cloudId,
        deleted: true,
        updatedAt: new Date().toISOString(),
      });
    }
    return okJson({ ok: true });
  }
  return fail('method not allowed', 405);
}

// ──────── 照片文件 ────────

function putObjectBytes(key, bytes, contentType) {
  return new Promise((resolve, reject) => {
    getCos().putObject(
      {
        Bucket: BUCKET,
        Region: REGION,
        Key: key,
        Body: bytes,
        ContentType: contentType || 'application/octet-stream',
      },
      (err) => (err ? reject(err) : resolve()),
    );
  });
}

function getSignedUrl(key, expires) {
  return new Promise((resolve, reject) => {
    getCos().getObjectUrl(
      {
        Bucket: BUCKET,
        Region: REGION,
        Key: key,
        Sign: true,
        Expires: expires || 3600,
      },
      (err, data) => (err ? reject(err) : resolve(data.Url)),
    );
  });
}

async function handlePhotos(method, query, body, isBase64) {
  const name = query.name;
  if (!SAFE_ID_RE.test(name || '')) return fail('invalid name', 400);
  // 文件名形如 {roomId}-{cloudId}.jpg，前缀即房间码
  const roomId = name.split('-')[0];
  if (!ROOM_CODE_RE.test(roomId) || !await getRoom(roomId)) {
    return fail('room not found', 404);
  }
  const key = `sync/photos/${roomId}/${name}`;

  if (method === 'POST') {
    let bytes = body;
    if (typeof body === 'string') {
      // 客户端上传时显式标记 enc=base64（函数 URL 不提供 isBase64Encoded 标记）
      const isB64 = query.enc === 'base64';
      bytes = isB64 ? Buffer.from(body, 'base64') : Buffer.from(body, 'utf8');
    }
    if (!Buffer.isBuffer(bytes)) bytes = Buffer.from(bytes);
    await putObjectBytes(key, bytes, query.contentType || 'image/jpeg');
    // 元数据只保存稳定对象名；需要下载时再通过 GET 获取新签名 URL。
    return okJson({ name });
  }
  if (method === 'GET') {
    const url = await getSignedUrl(key, 3600);
    return okJson({ url, name });
  }
  if (method === 'DELETE') {
    await deleteObject(key);
    return okJson({ ok: true });
  }
  return fail('method not allowed', 405);
}

// ──────── 入口 ────────

exports.main_handler = async (event, context) => {
  try {
    const method = String(event.httpMethod ||
      (event.requestContext && event.requestContext.httpMethod) || 'GET').toUpperCase();
    const headers = normalizeHeaders(event.headers);
    const path = event.path || '';
    const query = normalizeQuery(event);
    const bodyRaw = event.body;
    const isBase64 = event.isBase64Encoded === true || (event.requestContext && event.requestContext.isBase64Encoded);

    // 鉴权
    if (!hasValidSecret(headers)) {
      return unauthorized();
    }

    // 解析 body
    let body = bodyRaw;
    if (bodyRaw && typeof bodyRaw === 'string') {
      const bodyEnc = (headers['x-body-encoding'] || '').toLowerCase();
      if (bodyEnc === 'base64' && !path.includes('/photos')) {
        // 客户端显式 base64：先还原字节再按 UTF-8 解码（避免网关转码损坏中文）
        body = JSON.parse(Buffer.from(bodyRaw, 'base64').toString('utf8'));
      } else if (isBase64 && path.includes('/photos')) {
        body = Buffer.from(bodyRaw, 'base64');
      } else {
        try {
          body = JSON.parse(bodyRaw);
        } catch (e) {
          body = bodyRaw;
        }
      }
    }

    // 路由
    if (path.endsWith('/rooms')) {
      return await handleRooms(method, query, body);
    }
    const roomMatch = path.match(/\/rooms\/([^/]+)$/);
    if (roomMatch) {
      return await handleRoomUpdate(roomMatch[1], body);
    }
    if (path.includes('/pairdata')) {
      const idMatch = path.match(/\/pairdata\/([^/]+)$/);
      return await handlePairData(method, idMatch ? idMatch[1] : null, query, body);
    }
    if (path.includes('/photos')) {
      return await handlePhotos(method, query, body, isBase64);
    }
    return okJson({ ok: true, service: 'love-space-sync' });
  } catch (e) {
    console.error('sync error', e);
    return fail(e.message || 'internal error', 500);
  }
};

// 仅供本地单元测试注入内存 COS；生产入口不会调用。
exports.setCosForTest = (client) => {
  cos = client;
};
