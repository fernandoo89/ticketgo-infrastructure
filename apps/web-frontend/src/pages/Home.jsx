import React from 'react';
import TopBanner from '../components/TopBanner';
import Navbar from '../components/Navbar';
import SearchBar from '../components/SearchBar';
import HeroBanner from '../components/HeroBanner';
import EventCarousel from '../components/EventCarousel';
import PromoBanner from '../components/PromoBanner';
import Footer from '../components/Footer';

const sampleEvents1 = [
  { image: 'https://images.unsplash.com/photo-1545128485-c400e7702796?q=80&w=600&auto=format&fit=crop', title: 'BTS', date: '21 - 24 octubre', location: 'Estadio Unico de la Plata' },
  { image: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?q=80&w=600&auto=format&fit=crop', title: 'Fito Paez', date: '29 junio 2026 - 19:00 hs', location: 'Movistar Arena' },
  { image: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?q=80&w=600&auto=format&fit=crop', title: 'Soda Stereo', date: '10 - 15 agosto', location: 'Movistar Arena' },
  { image: 'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?q=80&w=600&auto=format&fit=crop', title: 'Sin Bandera', date: '27 febrero 2027 - 21:00 hs', location: 'Movistar Arena' },
];

const Home = () => {
  return (
    <>
      <TopBanner />
      <Navbar />
      <SearchBar />
      <HeroBanner />
      <EventCarousel title="Lo más vendido" events={sampleEvents1} showViewMore={false} />
      <PromoBanner />
      <EventCarousel title="Próximos Shows" events={sampleEvents1} showViewMore={false} />
      <EventCarousel title="Todos los Eventos" events={sampleEvents1} showViewMore={true} />
      <Footer />
    </>
  );
};

export default Home;
