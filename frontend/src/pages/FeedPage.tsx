import { useCallback, useEffect, useState } from 'react';
import type { Feed, FeedCreate } from '../types';
import { getFeeds, createFeed, updateFeed, deleteFeed } from '../api/client';
import FeedForm from '../components/FeedForm';

export default function FeedPage() {
  const [feeds, setFeeds] = useState<Feed[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [editingFeed, setEditingFeed] = useState<Feed | undefined>();
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      setFeeds(await getFeeds());
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const handleCreate = async (data: FeedCreate) => {
    await createFeed(data);
    setShowForm(false);
    load();
  };

  const handleUpdate = async (data: FeedCreate) => {
    if (!editingFeed) return;
    await updateFeed(editingFeed.id, {
      title: data.title,
      fetch_interval_minutes: data.fetch_interval_minutes,
    });
    setEditingFeed(undefined);
    load();
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Delete this feed and all its articles?')) return;
    await deleteFeed(id);
    load();
  };

  const handleToggleActive = async (feed: Feed) => {
    await updateFeed(feed.id, { is_active: !feed.is_active });
    load();
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-lg font-semibold text-gray-900">Feeds</h1>
        {!showForm && !editingFeed && (
          <button
            onClick={() => setShowForm(true)}
            className="px-4 py-2 bg-blue-600 text-white text-sm rounded-md hover:bg-blue-700"
          >
            Add Feed
          </button>
        )}
      </div>

      {showForm && (
        <FeedForm onSubmit={handleCreate} onCancel={() => setShowForm(false)} />
      )}

      {editingFeed && (
        <FeedForm
          feed={editingFeed}
          onSubmit={handleUpdate}
          onCancel={() => setEditingFeed(undefined)}
        />
      )}

      {loading && <p className="text-sm text-gray-500">Loading...</p>}

      <div className="space-y-2">
        {feeds.map((feed) => (
          <div
            key={feed.id}
            className="flex items-center gap-4 p-4 bg-white rounded-lg border border-gray-200"
          >
            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-2">
                <h3 className="text-sm font-medium text-gray-900 truncate">
                  {feed.title || feed.url}
                </h3>
                <span
                  className={`text-xs px-2 py-0.5 rounded-full ${
                    feed.is_active
                      ? 'bg-green-100 text-green-700'
                      : 'bg-gray-100 text-gray-500'
                  }`}
                >
                  {feed.is_active ? 'Active' : 'Paused'}
                </span>
                {feed.feed_type && (
                  <span className="text-xs text-gray-400">{feed.feed_type}</span>
                )}
              </div>
              <p className="text-xs text-gray-500 truncate mt-0.5">{feed.url}</p>
              <p className="text-xs text-gray-400 mt-0.5">
                Last fetched:{' '}
                {feed.last_fetched_at
                  ? new Date(feed.last_fetched_at).toLocaleString()
                  : 'Never'}
              </p>
            </div>
            <div className="flex items-center gap-2 shrink-0">
              <button
                onClick={() => handleToggleActive(feed)}
                className="text-xs px-2 py-1 rounded border border-gray-300 text-gray-600 hover:bg-gray-50"
              >
                {feed.is_active ? 'Pause' : 'Resume'}
              </button>
              <button
                onClick={() => setEditingFeed(feed)}
                className="text-xs px-2 py-1 rounded border border-gray-300 text-gray-600 hover:bg-gray-50"
              >
                Edit
              </button>
              <button
                onClick={() => handleDelete(feed.id)}
                className="text-xs px-2 py-1 rounded border border-red-300 text-red-600 hover:bg-red-50"
              >
                Delete
              </button>
            </div>
          </div>
        ))}
      </div>

      {!loading && feeds.length === 0 && (
        <p className="text-sm text-gray-500 text-center py-8">No feeds yet. Add one to get started.</p>
      )}
    </div>
  );
}
