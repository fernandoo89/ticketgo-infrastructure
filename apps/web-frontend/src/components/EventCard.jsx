import React from 'react';
import { Heart, Calendar, MapPin } from 'lucide-react';

const EventCard = ({ image, title, date, location }) => {
  return (
    <div className="event-card">
      <div className="card-image-wrapper">
        <img src={image} alt={title} className="card-image" />
        <button className="favorite-btn">
          <Heart size={18} />
        </button>
      </div>
      <div className="card-content">
        <h3 className="card-title">{title}</h3>
        <div className="card-detail">
          <Calendar size={14} />
          <span>{date}</span>
        </div>
        <div className="card-detail">
          <MapPin size={14} />
          <span>{location}</span>
        </div>
      </div>
    </div>
  );
};

export default EventCard;
