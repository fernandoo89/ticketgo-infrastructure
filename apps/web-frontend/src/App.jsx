import React from 'react';
import './index.css';

function App() {
  const events = [
    { id: 1, title: 'Neon Nights Festival', date: 'Oct 24, 2026', price: '$85.00' },
    { id: 2, title: 'Tech Innovation Summit', date: 'Nov 12, 2026', price: '$150.00' },
    { id: 3, title: 'Symphony Under Stars', date: 'Dec 05, 2026', price: '$45.00' }
  ];

  return (
    <>
      <nav className="navbar">
        <div className="logo">TicketGo</div>
        <button className="btn-primary" style={{ padding: '0.5rem 1.5rem', fontSize: '0.9rem' }}>
          Sign In
        </button>
      </nav>

      <main>
        <section className="hero">
          <h1>Experience The <br/>Extraordinary</h1>
          <p>Discover and book tickets for the most exclusive concerts, festivals, and tech events happening around the globe.</p>
          <button className="btn-primary">Explore Events</button>
        </section>

        <section className="events-section">
          <h2 className="section-title">Trending Now</h2>
          <div className="events-grid">
            {events.map(event => (
              <div key={event.id} className="event-card">
                <div className="event-date">{event.date}</div>
                <h3 className="event-title">{event.title}</h3>
                <div className="event-price">From {event.price}</div>
              </div>
            ))}
          </div>
        </section>
      </main>
    </>
  );
}

export default App;
