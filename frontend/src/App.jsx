import React, { useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, useLocation, useNavigate } from 'react-router-dom';
import { App as CapApp } from '@capacitor/app';
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
  const navigate = useNavigate();
  const hideBottomNavPages = ['/login', '/webview'];
  const showBottomNav = !hideBottomNavPages.includes(location.pathname);

  // Penanganan Tombol Back HP Native Android (Hardware Back Button)
  useEffect(() => {
    let backListener;
    async function setupBackListener() {
      backListener = await CapApp.addListener('backButton', () => {
        if (location.pathname !== '/') {
          // Jika berada di sub-halaman (WebView/Feed/Grup/dll), kembali ke halaman sebelumnya
          navigate(-1);
        } else {
          // Jika di halaman Home utama, keluar aplikasi
          CapApp.exitApp();
        }
      });
    }

    setupBackListener();

    return () => {
      if (backListener && typeof backListener.remove === 'function') {
        backListener.remove();
      }
    };
  }, [location.pathname, navigate]);

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
