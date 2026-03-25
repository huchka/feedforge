import { useCallback, useEffect, useState } from 'react';
import type { Article, Feed } from '../types';
import { getArticles, getFeeds } from '../api/client';
import ArticleList from '../components/ArticleList';
import SearchBar from '../components/SearchBar';

const PAGE_SIZE = 20;

export default function HomePage() {
  const [articles, setArticles] = useState<Article[]>([]);
  const [feeds, setFeeds] = useState<Feed[]>([]);
  const [feedFilter, setFeedFilter] = useState('');
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(true);
  const [hasMore, setHasMore] = useState(false);

  const loadArticles = useCallback(
    async (offset = 0) => {
      setLoading(true);
      try {
        const data = await getArticles({
          feed_id: feedFilter || undefined,
          limit: PAGE_SIZE,
          offset,
        });
        if (offset === 0) {
          setArticles(data);
        } else {
          setArticles((prev) => [...prev, ...data]);
        }
        setHasMore(data.length === PAGE_SIZE);
      } finally {
        setLoading(false);
      }
    },
    [feedFilter],
  );

  useEffect(() => {
    getFeeds().then(setFeeds).catch(console.error);
  }, []);

  useEffect(() => {
    loadArticles(0);
  }, [loadArticles]);

  const handleArticleUpdate = (updated: Article) => {
    setArticles((prev) => prev.map((a) => (a.id === updated.id ? updated : a)));
  };

  const filtered = search
    ? articles.filter((a) => a.title.toLowerCase().includes(search.toLowerCase()))
    : articles;

  return (
    <div className="space-y-4">
      <div className="flex gap-3 items-center">
        <div className="flex-1">
          <SearchBar value={search} onChange={setSearch} />
        </div>
        <select
          value={feedFilter}
          onChange={(e) => setFeedFilter(e.target.value)}
          className="px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">All feeds</option>
          {feeds.map((f) => (
            <option key={f.id} value={f.id}>
              {f.title || f.url}
            </option>
          ))}
        </select>
      </div>
      <ArticleList
        articles={filtered}
        feeds={feeds}
        onArticleUpdate={handleArticleUpdate}
        onLoadMore={() => loadArticles(articles.length)}
        hasMore={hasMore && !search}
        loading={loading}
      />
    </div>
  );
}
