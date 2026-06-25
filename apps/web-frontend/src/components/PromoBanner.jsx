import React from 'react';

const PromoBanner = () => {
  return (
    <div className="promo-container">
      <div className="promo-banner">
        <div className="promo-content">
          <h2 className="promo-logo">ticketgo</h2>
          <h1 className="promo-title">Compra segura,<br/>fácil, rápido y confiable.</h1>
          
          <div className="promo-features">
            <div className="feature">
              <div className="feature-icon">✓</div>
              <span>Compra<br/>segura</span>
            </div>
            <div className="feature">
              <div className="feature-icon">👤</div>
              <span>Fácil, rápido<br/>y confiable</span>
            </div>
          </div>
        </div>
        <div className="promo-image-wrapper">
           <img src="https://images.unsplash.com/photo-1540039155732-d6749b932231?q=80&w=2000&auto=format&fit=crop" alt="Concert Crowd" className="promo-image" />
        </div>
      </div>
    </div>
  );
};

export default PromoBanner;
