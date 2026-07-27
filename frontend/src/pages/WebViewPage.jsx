import React, { useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { ArrowLeft, RotateCw, ExternalLink } from 'lucide-react';
import LoadingSpinner from '../components/LoadingSpinner';

export default function WebViewPage() {
  const location = useLocation();
  const navigate = useNavigate();
  const [loading, setLoading] = useState(true);

  const targetUrl = location.state?.url || 'https://titc.or.id';
  const pageTitle = location.state?.title || 'Halaman WordPress TITC';

  const handleReload = () => {
    setLoading(true);
    const iframe = document.getElementById('titc-webview-iframe');
    if (iframe) {
      iframe.src = targetUrl;
    }
  };

  return (
    <div className="page-container webview-page">
      {/* Top Navigation Bar for WebView */}
      <header className="webview-header">
        <button className="icon-btn" onClick={() => navigate(-1)} title="Kembali">
          <ArrowLeft size={20} />
        </button>
        <h2 className="webview-title">{pageTitle}</h2>
        <div className="webview-actions">
          <button className="icon-btn" onClick={handleReload} title="Muat Ulang">
            <RotateCw size={18} />
          </button>
          <a
            href={targetUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="icon-btn"
            title="Buka di Browser"
          >
            <ExternalLink size={18} />
          </a>
        </div>
      </header>

      {/* Loading Overlay */}
      {loading && (
        <div className="webview-loading">
          <LoadingSpinner message="Membuka Halaman WordPress..." />
        </div>
      )}

      {/* Iframe Container */}
      <div className="iframe-wrapper">
        <iframe
          id="titc-webview-iframe"
          src={targetUrl}
          title={pageTitle}
          className="webview-iframe"
          onLoad={() => setLoading(false)}
        />
      </div>
    </div>
  );
}
