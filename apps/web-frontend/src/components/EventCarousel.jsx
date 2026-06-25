import React from 'react';
import { ChevronRight } from 'lucide-react';
import EventCard from './EventCard';

const EventCarousel = ({ title, events, showViewMore }) => {
  return (
    <section className="carousel-section">
      <div className="carousel-header">
        <h2 className="carousel-title">{title}</h2>
        {showViewMore && <button className="btn-outline">Ver más</button>}
      </div>
      
      <div className="carousel-container">
        <div className="carousel-track">
          {events.map((event, index) => (
            <EventCard 
              key={index}
              image={event.image}
              title={event.title}
              date={event.date}
              location={event.location}
            />
          ))}
        </div>
        <button className="carousel-arrow right-arrow">
          <ChevronRight size={24} />
        </button>
      </div>
    </section>
  );
};

export default EventCarousel;
