import React from 'react';

export default function LoadingSpinner({ message = 'Memuat data...' }) {
  return (
    <div className="loading-spinner-container">
      <div className="spinner-ring"></div>
      <p className="loading-text">{message}</p>
    </div>
  );
}
