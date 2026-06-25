import React from 'react';
import { Link } from 'react-router-dom';

const Navbar = () => {
  return (
    <nav className="navbar">
      <div className="nav-left" style={{ display: 'flex', alignItems: 'center', gap: '3rem' }}>
        <Link to="/" className="logo">ticketgo</Link>
        <div className="nav-links">
          <Link to="/" className="active">Todos</Link>
          <Link to="/deportes">Deportes</Link>
          <Link to="/shows">Shows</Link>
          <Link to="/teatro">Teatro</Link>
          <Link to="/festivales">Festivales</Link>
          <Link to="/contacto">Contacto</Link>
        </div>
      </div>
      <div className="nav-actions">
        <button>Iniciar sesión</button>
      </div>
    </nav>
  );
};

export default Navbar;
