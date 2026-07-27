import React, { useEffect, useState } from 'react';
import { membersService } from '../services/membersService';
import LoadingSpinner from '../components/LoadingSpinner';
import { Search, UserPlus, MessageCircle } from 'lucide-react';

export default function Members() {
  const [members, setMembers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');

  useEffect(() => {
    async function loadMembers() {
      try {
        const data = await membersService.getMembers(1, 10, search);
        setMembers(data);
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    }
    loadMembers();
  }, [search]);

  return (
    <div className="page-container members-page">
      <header className="page-header">
        <h1>Direktori Anggota</h1>
        <p className="page-subtitle">Cari & Terhubung dengan Anggota TITC</p>
      </header>

      {/* Search Input Bar */}
      <div className="search-bar">
        <Search size={18} className="search-icon" />
        <input
          type="text"
          placeholder="Cari nama anggota atau username..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="search-input"
        />
      </div>

      {loading ? (
        <LoadingSpinner message="Memuat Anggota..." />
      ) : (
        <div className="members-list">
          {members.map((member) => (
            <div key={member.id} className="member-card">
              <img src={member.avatar} alt={member.name} className="member-avatar" />
              <div className="member-details">
                <h4 className="member-name">{member.name}</h4>
                <span className="member-handle">{member.mention_name}</span>
                <span className="member-role">{member.role}</span>
              </div>
              <div className="member-actions">
                <button className="icon-btn-circle" title="Tambah Teman">
                  <UserPlus size={18} />
                </button>
                <button className="icon-btn-circle" title="Kirim Pesan">
                  <MessageCircle size={18} />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
