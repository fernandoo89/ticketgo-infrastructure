import React from 'react';

const HeroBanner = () => {
  return (
    <div className="hero-container">
      <div className="hero-banner">
        <div className="hero-content">
          <h1>BTS</h1>
          <button className="btn-outline-white">Ver tickets</button>
        </div>
        <div className="hero-image-wrapper">
          <img 
            src="https://images.unsplash.com/photo-1493225457124-a1a2a5f5f9af?q=80&w=2070&auto=format&fit=crop" 
            alt="BTS Concert" 
            className="hero-image"
          />
        </div>
      </div>
    </div>
  );
};

export default HeroBanner;
