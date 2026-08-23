'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.SYNC_SECRET = 'test-secret';
process.env.COS_BUCKET = 'test-bucket';
process.env.COS_REGION = 'ap-test';

const service = require('./index');

class MemoryCos {
  constructor() {
    this.objects = new Map();
  }

  getObject({ Key }, callback) {
    if (!this.objects.has(Key)) {
      callback({ statusCode: 404 });
      return;
    }
    callback(null, { Body: Buffer.from(this.objects.get(Key)) });
  }

  putObject({ Key, Body }, callback) {
    this.objects.set(Key, Buffer.isBuffer(Body) ? Body : Buffer.from(Body));
    callback(null, {});
  }

  deleteObject({ Key }, callback) {
    this.objects.delete(Key);
    callback(null, {});
  }

  getBucket({ Prefix }, callback) {
    const Contents = [...this.objects.keys()]
      .filter((key) => key.startsWith(Prefix))
      .sort()
      .map((Key) => ({ Key }));
    callback(null, { Contents, IsTruncated: 'false' });
  }

  getObjectUrl({ Key }, callback) {
    callback(null, { Url: `https://cos.test/${encodeURIComponent(Key)}?signature=fresh` });
  }
}

const cos = new MemoryCos();
service.setCosForTest(cos);

function jsonBody(value) {
  return Buffer.from(JSON.stringify(value), 'utf8').toString('base64');
}

async function invoke(method, path, { query = {}, body, secret = 'test-secret' } = {}) {
  const response = await service.main_handler({
    httpMethod: method,
    path,
    queryStringParameters: query,
    headers: {
      'X-Sync-Secret': secret,
      ...(body === undefined ? {} : { 'X-Body-Encoding': 'base64' }),
    },
    body: body === undefined ? undefined : jsonBody(body),
  });
  return {
    statusCode: response.statusCode,
    body: JSON.parse(response.body),
  };
}

test('拒绝错误密钥，并兼容大小写请求头', async () => {
  const rejected = await invoke('GET', '/', { secret: 'wrong' });
  assert.equal(rejected.statusCode, 401);

  const accepted = await invoke('GET', '/');
  assert.equal(accepted.statusCode, 200);
});

test('房间创建、查询与加入保留双方成员，第三人被拒绝', async () => {
  const created = await invoke('POST', '/rooms', {
    body: { code: 'ABC234', members: ['owner'] },
  });
  assert.equal(created.statusCode, 200);

  const joined = await invoke('PUT', '/rooms/ABC234', {
    body: { members: ['partner'] },
  });
  assert.deepEqual(joined.body.members, ['owner', 'partner']);

  const third = await invoke('PUT', '/rooms/ABC234', {
    body: { members: ['intruder'] },
  });
  assert.equal(third.statusCode, 409);

  const queried = await invoke('GET', '/rooms', {
    query: { code: 'ABC234' },
  });
  assert.deepEqual(queried.body.room.members, ['owner', 'partner']);
});

test('文档更新保留 cloudId，删除写入墓碑防止离线副本复活', async () => {
  const created = await invoke('POST', '/pairdata', {
    body: {
      roomId: 'ABC234',
      type: 'wish',
      ownerId: 'owner',
      data: { title: '一起看海' },
      updatedAt: '2026-08-23T00:00:00.000Z',
    },
  });
  const cloudId = created.body.cloudId;
  assert.ok(cloudId);

  const updated = await invoke('PUT', `/pairdata/${cloudId}`, {
    body: {
      roomId: 'ABC234',
      type: 'wish',
      ownerId: 'owner',
      data: { title: '一起看海和日出' },
      updatedAt: '2026-08-23T01:00:00.000Z',
    },
  });
  assert.equal(updated.statusCode, 200);

  await invoke('DELETE', `/pairdata/${cloudId}`, {
    query: { roomId: 'ABC234' },
  });
  const pulled = await invoke('GET', '/pairdata', {
    query: { roomId: 'ABC234' },
  });
  assert.equal(pulled.body.docs.length, 1);
  assert.equal(pulled.body.docs[0].cloudId, cloudId);
  assert.equal(pulled.body.docs[0].deleted, true);
});

test('照片元数据保存稳定对象名，下载时生成新签名 URL', async () => {
  const name = 'ABC234-12345678-1234-4123-8123-123456789abc.jpg';
  const uploaded = await service.main_handler({
    httpMethod: 'POST',
    path: '/photos',
    queryStringParameters: { name, enc: 'base64', contentType: 'image/jpeg' },
    headers: { 'x-sync-secret': 'test-secret' },
    body: Buffer.from('photo-bytes').toString('base64'),
  });
  assert.equal(uploaded.statusCode, 200);
  assert.deepEqual(JSON.parse(uploaded.body), { name });

  const downloaded = await invoke('GET', '/photos', { query: { name } });
  assert.match(downloaded.body.url, /signature=fresh/);
});
