import type { Feed, Article, FeedCreate, FeedUpdate, ArticleUpdate } from '../types';

const BASE = import.meta.env.VITE_API_BASE_URL || '/api';

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...init,
  });
  if (!res.ok) {
    const detail = await res.text();
    throw new Error(`${res.status}: ${detail}`);
  }
  if (res.status === 204) return undefined as T;
  return res.json();
}

export function getFeeds() {
  return request<Feed[]>('/feeds');
}

export function createFeed(data: FeedCreate) {
  return request<Feed>('/feeds', { method: 'POST', body: JSON.stringify(data) });
}

export function updateFeed(id: string, data: FeedUpdate) {
  return request<Feed>(`/feeds/${id}`, { method: 'PATCH', body: JSON.stringify(data) });
}

export function deleteFeed(id: string) {
  return request<void>(`/feeds/${id}`, { method: 'DELETE' });
}

export function getArticles(params?: { feed_id?: string; limit?: number; offset?: number }) {
  const sp = new URLSearchParams();
  if (params?.feed_id) sp.set('feed_id', params.feed_id);
  if (params?.limit) sp.set('limit', String(params.limit));
  if (params?.offset) sp.set('offset', String(params.offset));
  const qs = sp.toString();
  return request<Article[]>(`/articles${qs ? `?${qs}` : ''}`);
}

export function getArticle(id: string) {
  return request<Article>(`/articles/${id}`);
}

export function updateArticle(id: string, data: ArticleUpdate) {
  return request<Article>(`/articles/${id}`, { method: 'PATCH', body: JSON.stringify(data) });
}
