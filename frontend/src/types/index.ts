export interface Feed {
  id: string;
  url: string;
  title: string | null;
  site_url: string | null;
  feed_type: string | null;
  fetch_interval_minutes: number;
  last_fetched_at: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface Article {
  id: string;
  feed_id: string;
  url: string;
  title: string;
  author: string | null;
  content: string | null;
  summary: string | null;
  published_at: string | null;
  fetched_at: string | null;
  is_read: boolean;
  is_favorite: boolean;
  created_at: string;
}

export interface FeedCreate {
  url: string;
  title?: string;
  fetch_interval_minutes?: number;
}

export interface FeedUpdate {
  title?: string;
  is_active?: boolean;
  fetch_interval_minutes?: number;
}

export interface ArticleUpdate {
  is_read?: boolean;
  is_favorite?: boolean;
}
