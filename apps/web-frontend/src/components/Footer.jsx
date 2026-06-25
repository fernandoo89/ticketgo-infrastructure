import React from 'react';
import { Instagram } from 'lucide-react';

const Footer = () => {
  return (
    <>
      <footer className="footer">
        <div className="footer-benefits">
          <div className="benefit-item">
            <h4>Garantía del 100% al comprador.</h4>
            <p>Experiencia segura y sin preocupaciones.</p>
          </div>
          <div className="benefit-item">
            <h4>Tus datos, siempre protegidos.</h4>
            <p>Tenemos los más altos estándares de seguridad.</p>
          </div>
          <div className="benefit-item">
            <h4>Atención al cliente integral</h4>
            <p>Desde el primer clic hasta que finalices tu compra.</p>
          </div>
        </div>

        <div className="footer-newsletter">
          <div className="newsletter-text">
            <h4>Entérate antes que nadie.</h4>
            <p>Únete a nuestro <strong>Newsletter</strong> y sé el primero en enterarte de ofertas exclusivas, lo mejor en eventos en vivo y mucho más.</p>
          </div>
          <div className="newsletter-form">
            <input type="email" placeholder="Email" />
            <button>Suscribirme</button>
          </div>
        </div>
      </footer>
      
      <div className="sub-footer">
        <div className="sub-footer-top">
          <span className="sub-footer-logo">ticketgo</span>
          <a href="#" className="social-link"><Instagram size={20} /></a>
        </div>
        <div className="sub-footer-bottom">
          <a href="#">Sobre Nosotros</a>
          <a href="#">Condiciones Legales</a>
          <a href="#">Contacto</a>
        </div>
      </div>
    </>
  );
};

export default Footer;
