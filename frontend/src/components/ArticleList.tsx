import type { Article, Feed } from '../types';
import ArticleCard from './ArticleCard';

interface Props {
  articles: Article[];
  feeds: Feed[];
  onArticleUpdate: (updated: Article) => void;
  onLoadMore?: () => void;
  hasMore: boolean;
  loading: boolean;
}

export default function ArticleList({
  articles,
  feeds,
  onArticleUpdate,
  onLoadMore,
  hasMore,
  loading,
}: Props) {
  const feedMap = new Map(feeds.map((f) => [f.id, f.title || f.url]));

  if (!loading && articles.length === 0) {
    return <p className="text-sm text-gray-500 text-center py-8">No articles yet.</p>;
  }

  return (
    <div className="space-y-3">
      {articles.map((article) => (
        <ArticleCard
          key={article.id}
          article={article}
          feedTitle={feedMap.get(article.feed_id) || undefined}
          onUpdate={onArticleUpdate}
        />
      ))}
      {loading && <p className="text-sm text-gray-500 text-center py-4">Loading...</p>}
      {hasMore && !loading && (
        <button
          onClick={onLoadMore}
          className="w-full py-2 text-sm text-blue-600 hover:text-blue-800 font-medium"
        >
          Load more
        </button>
      )}
    </div>
  );
}
