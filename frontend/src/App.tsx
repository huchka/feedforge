import { BrowserRouter, Routes, Route } from 'react-router-dom';
import Layout from './components/Layout';
import HomePage from './pages/HomePage';
import ArticlePage from './pages/ArticlePage';
import FeedPage from './pages/FeedPage';

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<HomePage />} />
          <Route path="articles/:id" element={<ArticlePage />} />
          <Route path="feeds" element={<FeedPage />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
