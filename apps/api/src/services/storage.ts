import { randomUUID } from 'node:crypto';
import { mkdir, writeFile, unlink } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import sharp from 'sharp';
import type { Config } from '../config.js';
import { AppError } from '../lib/errors.js';

export interface StoredImage { url: string; thumbUrl: string }

/**
 * Validate an uploaded image by decoding it (never trust the filename or Content-Type), strip metadata,
 * and re-encode to WebP at a sane size. Anything that is not a real JPEG/PNG/WebP is rejected.
 */
export async function processImage(buf: Buffer): Promise<{ main: Buffer; thumb: Buffer }> {
  let meta;
  try { meta = await sharp(buf, { failOn: 'error', limitInputPixels: 40_000_000 }).metadata(); } catch { throw new AppError(400, 'INVALID_IMAGE', 'This file is not a valid image. Please upload a JPG, PNG or WebP photo.'); }
  if (!meta.format || !['jpeg', 'png', 'webp'].includes(meta.format)) throw new AppError(400, 'INVALID_IMAGE', 'Only JPG, PNG or WebP images are allowed.');
  if (!meta.width || !meta.height || meta.width < 100 || meta.height < 100) throw new AppError(400, 'IMAGE_TOO_SMALL', 'Image is too small. Use a photo at least 100 × 100 pixels (600 × 600 or more is best).');
  const base = () => sharp(buf, { failOn: 'error', limitInputPixels: 40_000_000 }).rotate();
  const main = await base().resize({ width: 1200, height: 1200, fit: 'inside', withoutEnlargement: true }).flatten({ background: '#ffffff' }).webp({ quality: 82 }).toBuffer();
  const thumb = await base().resize({ width: 400, height: 400, fit: 'inside', withoutEnlargement: true }).flatten({ background: '#ffffff' }).webp({ quality: 78 }).toBuffer();
  return { main, thumb };
}

export class Storage {
  constructor(private c: Config) {}
  private publicBase() { return this.c.STORAGE_DRIVER === 's3' ? this.c.S3_PUBLIC_BASE_URL.replace(/\/$/, '') : `${this.c.PUBLIC_BASE_URL.replace(/\/$/, '')}/uploads`; }

  async saveImage(buf: Buffer, folder: 'products' | 'categories' | 'banners' | 'branding'): Promise<StoredImage> {
    const { main, thumb } = await processImage(buf);
    const id = randomUUID();
    const mainKey = `${folder}/${id}.webp`, thumbKey = `${folder}/${id}_t.webp`;
    await this.put(mainKey, main); await this.put(thumbKey, thumb);
    return { url: `${this.publicBase()}/${mainKey}`, thumbUrl: `${this.publicBase()}/${thumbKey}` };
  }

  private async put(key: string, data: Buffer) {
    if (this.c.STORAGE_DRIVER === 's3') {
      const { S3Client, PutObjectCommand } = await import('@aws-sdk/client-s3');
      const s3 = new S3Client({ region: this.c.S3_REGION || 'auto', endpoint: this.c.S3_ENDPOINT || undefined, forcePathStyle: !!this.c.S3_ENDPOINT, credentials: { accessKeyId: this.c.S3_ACCESS_KEY_ID, secretAccessKey: this.c.S3_SECRET_ACCESS_KEY } });
      await s3.send(new PutObjectCommand({ Bucket: this.c.S3_BUCKET, Key: key, Body: data, ContentType: 'image/webp', CacheControl: 'public, max-age=31536000, immutable' }));
      return;
    }
    const root = resolve(this.c.UPLOAD_DIR);
    const full = resolve(join(root, key));
    if (!full.startsWith(root + '/')) throw new Error('bad path');
    await mkdir(dirname(full), { recursive: true });
    await writeFile(full, data);
  }

  /** Best effort removal of files for a stored URL (never throws). */
  async remove(url: string | null | undefined) {
    if (!url) return;
    try {
      const key = url.startsWith(this.publicBase() + '/') ? url.slice(this.publicBase().length + 1) : null;
      if (!key) return;
      if (this.c.STORAGE_DRIVER === 's3') {
        const { S3Client, DeleteObjectCommand } = await import('@aws-sdk/client-s3');
        const s3 = new S3Client({ region: this.c.S3_REGION || 'auto', endpoint: this.c.S3_ENDPOINT || undefined, forcePathStyle: !!this.c.S3_ENDPOINT, credentials: { accessKeyId: this.c.S3_ACCESS_KEY_ID, secretAccessKey: this.c.S3_SECRET_ACCESS_KEY } });
        await s3.send(new DeleteObjectCommand({ Bucket: this.c.S3_BUCKET, Key: key }));
      } else {
        const root = resolve(this.c.UPLOAD_DIR); const full = resolve(join(root, key));
        if (full.startsWith(root + '/')) await unlink(full);
      }
    } catch { /* ignore */ }
  }
}
