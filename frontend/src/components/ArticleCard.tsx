import { Link } from 'react-router-dom';
import type { Article } from '../types';
import { updateArticle } from '../api/client';

function timeAgo(dateStr: string | null): string {
  if (!dateStr) return '';
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  const days = Math.floor(hrs / 24);
  return `${days}d ago`;
}

interface Props {
  article: Article;
  feedTitle?: string;
  onUpdate: (updated: Article) => void;
}

export default function ArticleCard({ article, feedTitle, onUpdate }: Props) {
  const toggleFavorite = async (e: React.MouseEvent) => {
    e.preventDefault();
    const updated = await updateArticle(article.id, { is_favorite: !article.is_favorite });
    onUpdate(updated);
  };

  return (
    <Link
      to={`/articles/${article.id}`}
      className={`block p-4 bg-white rounded-lg border border-gray-200 hover:border-gray-300 transition-colors ${
        article.is_read ? 'opacity-60' : ''
      }`}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0 flex-1">
          <h3 className="text-sm font-medium text-gray-900 truncate">{article.title}</h3>
          <div className="flex items-center gap-2 mt-1 text-xs text-gray-500">
            {feedTitle && <span>{feedTitle}</span>}
            {article.author && <span>by {article.author}</span>}
            <span>{timeAgo(article.published_at || article.created_at)}</span>
          </div>
          {article.summary && (
            <p className="mt-2 text-xs text-gray-600 line-clamp-2">{article.summary}</p>
          )}
        </div>
        <button
          onClick={toggleFavorite}
          className="shrink-0 text-lg hover:scale-110 transition-transform"
          title={article.is_favorite ? 'Unfavorite' : 'Favorite'}
        >
          {article.is_favorite ? '\u2605' : '\u2606'}
        </button>
      </div>
    </Link>
  );
}
