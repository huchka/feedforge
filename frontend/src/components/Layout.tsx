import { NavLink, Outlet } from 'react-router-dom';

const navLinks = [
  { to: '/', label: 'Articles' },
  { to: '/feeds', label: 'Feeds' },
];

export default function Layout() {
  return (
    <div className="min-h-screen bg-gray-50">
      <nav className="bg-white border-b border-gray-200">
        <div className="max-w-5xl mx-auto px-4 flex items-center h-14 gap-6">
          <span className="text-lg font-semibold text-gray-900">FeedForge</span>
          <div className="flex gap-4">
            {navLinks.map((link) => (
              <NavLink
                key={link.to}
                to={link.to}
                className={({ isActive }) =>
                  `text-sm font-medium px-2 py-1 rounded ${
                    isActive
                      ? 'text-blue-600 bg-blue-50'
                      : 'text-gray-600 hover:text-gray-900'
                  }`
                }
                end={link.to === '/'}
              >
                {link.label}
              </NavLink>
            ))}
          </div>
        </div>
      </nav>
      <main className="max-w-5xl mx-auto px-4 py-6">
        <Outlet />
      </main>
    </div>
  );
}
