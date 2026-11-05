import { BadRequestException, Body, ConflictException, Controller, Get, Inject, Injectable, Post, Query, Req, UseGuards } from '@nestjs/common';
import { Type } from 'class-transformer';
import { ArrayMaxSize, IsArray, IsBoolean, IsIn, IsInt, IsOptional, IsString, Length, Matches, Max, Min, ValidateNested } from 'class-validator';
import { createHash } from 'node:crypto';
import { PoolClient } from 'pg';
import { Store } from './store';
import { AuthGuard, AuthRequest } from './http';

export class ProductData {
  @IsString() @Matches(/^[a-zA-Z0-9_-]{1,100}$/) id!: string;
  @IsString() @Length(1, 100) @Matches(/\S/) name!: string;
  @IsString() @Length(1, 40) @Matches(/\S/) quantity!: string;
  @IsIn(['Buzdolabı', 'Kiler', 'Dondurucu']) location!: string;
  @IsString() @Matches(/^\d{4}-\d{2}-\d{2}$/) purchased_at!: string;
  @IsOptional() @IsString() @Matches(/^\d{4}-\d{2}-\d{2}$/) expires_at?: string | null;
  @IsOptional() @IsIn(['label', 'estimated', 'unknown']) expiry_source?: string | null;
  @IsOptional() @IsIn(['fresh_milk_v1', 'shell_eggs_v1', 'raw_ground_meat_v1', 'raw_poultry_v1', 'raw_fish_v1', 'raw_meat_v1']) shelf_life_profile_id?: string | null;
  @IsOptional() @IsString() @Matches(/^\d{4}-\d{2}-\d{2}$/) opened_at?: string | null;
  @IsOptional() @IsInt() @Min(1) @Max(3650) after_opening_days?: number | null;
  @IsIn(['active', 'consumed']) status!: string;
  @IsOptional() @IsIn(['milk_uht_v1', 'milk_pasteurized_v1']) opening_profile_id?: string | null;
  @IsInt() @IsIn([0, 1]) cold_storage_confirmed!: number;
}
export class ProductMutation {
  @IsString() @Matches(/^[a-zA-Z0-9_-]{16,100}$/) mutationId!: string;
  @IsString() @Matches(/^[a-zA-Z0-9_-]{1,100}$/) productId!: string;
  @IsInt() @Min(0) @Max(2147483646) baseVersion!: number;
  @IsBoolean() deleted!: boolean;
  @IsOptional() @ValidateNested() @Type(() => ProductData) product?: ProductData | null;
}
class PushDto {
  @IsArray() @ArrayMaxSize(50) @ValidateNested({ each: true }) @Type(() => ProductMutation) mutations!: ProductMutation[];
}
interface ProductRow { id: string; version: number; cursor: number; deleted: boolean; data: ProductData | null; }
export interface RemoteProduct { id: string; version: number; cursor: number; deleted: boolean; product: ProductData | null; }
interface MutationResult { mutationId: string; outcome: 'applied' | 'conflict'; remote: RemoteProduct | null; }
function remote(row: ProductRow): RemoteProduct {
  return { id: row.id, version: Number(row.version), cursor: Number(row.cursor), deleted: row.deleted, product: row.deleted ? null : row.data };
}
function canonicalProduct(p: ProductData): ProductData {
  return { id: p.id, name: p.name.trim(), quantity: p.quantity.trim(), location: p.location,
    purchased_at: p.purchased_at, expires_at: p.expires_at, opened_at: p.opened_at ?? null,
    after_opening_days: p.after_opening_days ?? null, status: p.status,
    opening_profile_id: p.opening_profile_id ?? null, cold_storage_confirmed: p.cold_storage_confirmed,
    ...(p.expiry_source == null ? {} : { expiry_source: p.expiry_source }),
    ...(p.shelf_life_profile_id == null ? {} : { shelf_life_profile_id: p.shelf_life_profile_id }) };
}
function validateMutation(m: ProductMutation) {
  if (m.deleted) { if (m.product != null) throw new BadRequestException('Silme işleminde ürün gövdesi olmamalı.'); return; }
  if (!m.product || m.product.id !== m.productId) throw new BadRequestException('Ürün bilgisi veya kimliği geçersiz.');
  const p = m.product;
  if (p.expiry_source === 'estimated' && (!p.expires_at || !p.shelf_life_profile_id)) throw new BadRequestException('Tahmin kaynağı ve tarih gerekli.');
  if ((p.expiry_source === 'label' && !p.expires_at) || (p.expiry_source === 'unknown' && p.expires_at)) throw new BadRequestException('Tarih kaynağı uyumsuz.');
  for (const value of [p.purchased_at, p.expires_at, p.opened_at].filter(Boolean) as string[]) {
    const date = new Date(value + 'T00:00:00Z');
    if (!Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== value || value < '2000-01-01' || value > '2100-12-31') {
      throw new BadRequestException('Geçersiz ürün tarihi.');
    }
  }
  if (p.opened_at && p.opened_at < p.purchased_at) throw new BadRequestException('Açılma tarihi alış tarihinden önce olamaz.');
}

@Injectable()
export class ProductsService {
  constructor(@Inject(Store) private readonly store: Store) {}
  async push(userId: string, mutations: ProductMutation[]) {
    const ids = new Set<string>();
    for (const m of mutations) {
      validateMutation(m);
      if (ids.has(m.mutationId)) throw new BadRequestException('Aynı işlem kimliği bir pakette tekrarlanamaz.');
      ids.add(m.mutationId);
    }
    const tx = await this.store.db.connect();
    try {
      await tx.query('BEGIN');
      await tx.query('INSERT INTO product_sync_heads(user_id,cursor) VALUES($1,0) ON CONFLICT DO NOTHING', [userId]);
      // One account lock serializes version checks and revision allocation.
      await tx.query('SELECT cursor FROM product_sync_heads WHERE user_id=$1 FOR UPDATE', [userId]);
      const results: MutationResult[] = [];
      for (const m of mutations) results.push(await this.apply(tx, userId, m));
      await tx.query('COMMIT');
      return { results };
    } catch (error) { await tx.query('ROLLBACK'); throw error; }
    finally { tx.release(); }
  }
  private async apply(tx: PoolClient, userId: string, m: ProductMutation): Promise<MutationResult> {
    const product = m.deleted ? null : canonicalProduct(m.product!);
    const hash = createHash('sha256').update(JSON.stringify({ productId: m.productId, baseVersion: m.baseVersion, deleted: m.deleted, product })).digest('hex');
    const previous = (await tx.query('SELECT request_hash,result FROM product_mutations WHERE user_id=$1 AND mutation_id=$2', [userId, m.mutationId])).rows[0];
    if (previous) {
      if (previous.request_hash !== hash) throw new ConflictException('Bu işlem kimliği farklı bir içerikle kullanılmış.');
      return previous.result as MutationResult;
    }
    const existing = (await tx.query<ProductRow>('SELECT * FROM user_products WHERE user_id=$1 AND id=$2', [userId, m.productId])).rows[0];
    let result: MutationResult;
    if ((existing?.version ?? 0) !== m.baseVersion) {
      result = { mutationId: m.mutationId, outcome: 'conflict', remote: existing ? remote(existing) : null };
    } else {
      const head = (await tx.query('UPDATE product_sync_heads SET cursor=cursor+1 WHERE user_id=$1 RETURNING cursor', [userId])).rows[0];
      const version = (existing?.version ?? 0) + 1;
      const row = (await tx.query<ProductRow>(`INSERT INTO user_products(user_id,id,version,cursor,deleted,data)
        VALUES($1,$2,$3,$4,$5,$6::jsonb) ON CONFLICT(user_id,id) DO UPDATE
        SET version=EXCLUDED.version,cursor=EXCLUDED.cursor,deleted=EXCLUDED.deleted,data=EXCLUDED.data RETURNING *`,
        [userId, m.productId, version, head.cursor, m.deleted, product == null ? null : JSON.stringify(product)])).rows[0];
      result = { mutationId: m.mutationId, outcome: 'applied', remote: remote(row) };
    }
    await tx.query('INSERT INTO product_mutations(user_id,mutation_id,request_hash,result) VALUES($1,$2,$3,$4::jsonb)',
      [userId, m.mutationId, hash, JSON.stringify(result)]);
    return result;
  }
  async changes(userId: string, afterRaw: string | undefined, limitRaw: string | undefined) {
    const after = afterRaw ?? '0', limit = limitRaw ?? '200';
    if (!/^\d{1,10}$/.test(after) || !/^\d{1,3}$/.test(limit) || Number(after) > 2147483646 || Number(limit) < 1 || Number(limit) > 200) {
      throw new BadRequestException('Geçersiz eşitleme sayfası.');
    }
    const head = Number((await this.store.db.query('SELECT cursor FROM product_sync_heads WHERE user_id=$1', [userId])).rows[0]?.cursor ?? 0);
    if (Number(after) > head) throw new ConflictException('Sunucu eşitleme geçmişi geride. Cihaz kayıtlarını koruyarak sunucu yedeğini kontrol edin.');
    const rows = (await this.store.db.query<ProductRow>('SELECT * FROM user_products WHERE user_id=$1 AND cursor>$2 AND cursor<=$3 ORDER BY cursor LIMIT $4',
      [userId, Number(after), head, Number(limit)])).rows;
    const cursor = rows.length === Number(limit) ? Number(rows[rows.length - 1].cursor) : head;
    return { changes: rows.map(remote), cursor, hasMore: cursor < head };
  }
}

@Controller('products') @UseGuards(AuthGuard)
export class ProductsController {
  constructor(@Inject(ProductsService) private readonly products: ProductsService) {}
  @Post('sync') push(@Req() req: AuthRequest, @Body() body: PushDto) { return this.products.push(req.identity.userId, body.mutations); }
  @Get('changes') changes(@Req() req: AuthRequest, @Query('after') after?: string, @Query('limit') limit?: string) {
    return this.products.changes(req.identity.userId, after, limit);
  }
}
