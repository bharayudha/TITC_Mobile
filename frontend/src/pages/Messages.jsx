import React, { useEffect, useState } from 'react';
import { messagesService } from '../services/messagesService';
import LoadingSpinner from '../components/LoadingSpinner';
import { Mail, Edit3 } from 'lucide-react';

export default function Messages() {
  const [messages, setMessages] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadMessages() {
      try {
        const data = await messagesService.getMessages();
        setMessages(data);
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    }
    loadMessages();
  }, []);

  return (
    <div className="page-container messages-page">
      <header className="page-header header-with-action">
        <div>
          <h1>Pesan Pribadi</h1>
          <p className="page-subtitle">Kotak Masuk Diskusi & Notifikasi</p>
        </div>
        <button className="icon-btn-circle primary-circle" title="Tulis Pesan Baru">
          <Edit3 size={18} />
        </button>
      </header>

      {loading ? (
        <LoadingSpinner message="Memuat Pesan..." />
      ) : (
        <div className="messages-list">
          {messages.map((msg) => (
            <div key={msg.id} className={`message-card ${msg.unread ? 'unread' : ''}`}>
              <img src={msg.sender_avatar} alt={msg.sender_name} className="message-avatar" />
              <div className="message-body">
                <div className="message-header-row">
                  <span className="sender-name">{msg.sender_name}</span>
                  <span className="message-date">{msg.date}</span>
                </div>
                <h4 className="message-subject">{msg.subject}</h4>
                <p className="message-snippet">{msg.last_message}</p>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
