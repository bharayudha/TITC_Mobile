import React from 'react';
import { BrowserRouter as Router, Routes, Route, useLocation } from 'react-router-dom';
import Home from './pages/Home';
import WebViewPage from './pages/WebViewPage';
import Feed from './pages/Feed';
import Groups from './pages/Groups';
import Members from './pages/Members';
import Messages from './pages/Messages';
import Login from './pages/Login';
import BottomNav from './components/BottomNav';

function AppLayout() {
  const location = useLocation();
  const hideBottomNavPages = ['/login', '/webview'];
  const showBottomNav = !hideBottomNavPages.includes(location.pathname);

  return (
    <div className="app-shell">
      <main className="app-main-content">
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/webview" element={<WebViewPage />} />
          <Route path="/feed" element={<Feed />} />
          <Route path="/groups" element={<Groups />} />
          <Route path="/members" element={<Members />} />
          <Route path="/messages" element={<Messages />} />
          <Route path="/login" element={<Login />} />
        </Routes>
      </main>

      {showBottomNav && <BottomNav />}
    </div>
  );
}

export default function App() {
  return (
    <Router>
      <AppLayout />
    </Router>
  );
}
