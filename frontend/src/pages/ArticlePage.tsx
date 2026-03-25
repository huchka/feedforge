import { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import type { Article } from '../types';
import { getArticle, updateArticle } from '../api/client';

export default function ArticlePage() {
  const { id } = useParams<{ id: string }>();
  const [article, setArticle] = useState<Article | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!id) return;
    getArticle(id).then(setArticle).catch((e) => setError(e.message));
  }, [id]);

  useEffect(() => {
    if (!article || article.is_read) return;
    updateArticle(article.id, { is_read: true }).then(setArticle).catch(console.error);
  }, [article?.id]); // eslint-disable-line react-hooks/exhaustive-deps

  const toggleFavorite = async () => {
    if (!article) return;
    const updated = await updateArticle(article.id, { is_favorite: !article.is_favorite });
    setArticle(updated);
  };

  if (error) return <p className="text-red-600">{error}</p>;
  if (!article) return <p className="text-gray-500">Loading...</p>;

  return (
    <div className="space-y-4">
      <Link to="/" className="text-sm text-blue-600 hover:text-blue-800">&larr; Back</Link>
      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <div className="flex items-start justify-between gap-4">
          <h1 className="text-xl font-semibold text-gray-900">{article.title}</h1>
          <button
            onClick={toggleFavorite}
            className="text-2xl shrink-0 hover:scale-110 transition-transform"
          >
            {article.is_favorite ? '\u2605' : '\u2606'}
          </button>
        </div>
        <div className="flex items-center gap-3 mt-2 text-sm text-gray-500">
          {article.author && <span>by {article.author}</span>}
          {article.published_at && (
            <span>{new Date(article.published_at).toLocaleDateString()}</span>
          )}
          <a
            href={article.url}
            target="_blank"
            rel="noopener noreferrer"
            className="text-blue-600 hover:underline"
          >
            Original
          </a>
        </div>
      </div>

      {article.summary && (
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <h2 className="text-sm font-semibold text-blue-800 mb-2">AI Summary</h2>
          <p className="text-sm text-blue-900 whitespace-pre-wrap">{article.summary}</p>
        </div>
      )}

      {article.content && (
        <div className="bg-white rounded-lg border border-gray-200 p-6">
          <p className="text-sm text-gray-700 whitespace-pre-wrap">{article.content}</p>
        </div>
      )}
    </div>
  );
}
