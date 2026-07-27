import React, { useEffect, useState } from 'react';
import { groupsService } from '../services/groupsService';
import LoadingSpinner from '../components/LoadingSpinner';
import { Users, Lock, Globe } from 'lucide-react';

export default function Groups() {
  const [groups, setGroups] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadGroups() {
      try {
        const data = await groupsService.getGroups();
        setGroups(data);
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    }
    loadGroups();
  }, []);

  return (
    <div className="page-container groups-page">
      <header className="page-header">
        <h1>Grup Komunitas</h1>
        <p className="page-subtitle">Temukan & Bergabung dengan Grup TITC</p>
      </header>

      {loading ? (
        <LoadingSpinner message="Memuat Daftar Grup..." />
      ) : (
        <div className="groups-grid">
          {groups.map((group) => (
            <div key={group.id} className="group-card">
              <div className="group-avatar-wrapper">
                <img src={group.avatar} alt={group.name} className="group-avatar" />
              </div>
              <div className="group-info">
                <div className="group-header">
                  <h3 className="group-title">{group.name}</h3>
                  <span className="privacy-badge">
                    {group.privacy.includes('Private') ? (
                      <>
                        <Lock size={12} style={{ marginRight: 4 }} /> Private
                      </>
                    ) : (
                      <>
                        <Globe size={12} style={{ marginRight: 4 }} /> Publik
                      </>
                    )}
                  </span>
                </div>
                <p className="group-desc">{group.description}</p>
                <div className="group-footer">
                  <span className="members-count">
                    <Users size={14} style={{ marginRight: 4 }} />
                    {group.members_count} Anggota
                  </span>
                  <button className="btn-outline btn-sm">Bergabung</button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
