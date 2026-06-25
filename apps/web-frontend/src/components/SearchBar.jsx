import React from 'react';
import { Search } from 'lucide-react';

const SearchBar = () => {
  return (
    <div className="search-container">
      <div className="search-input-wrapper">
        <input 
          type="text" 
          placeholder="Buscar espectáculos, intérpretes, tours" 
        />
        <Search size={20} />
      </div>
    </div>
  );
};

export default SearchBar;
