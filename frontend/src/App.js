import React, { useState, useEffect } from 'react';
import './App.css';
import axios from 'axios';

// API base URL - use relative path to work with nginx proxy
const API_BASE_URL = '';

// Gen 1 Pokemon IDs (first 8 for 4x4 grid = 16 cards, 8 pairs)
const POKEMON_IDS = [1, 4, 7, 25, 39, 52, 54, 133]; // Bulbasaur, Charmander, Squirtle, Pikachu, Jigglypuff, Meowth, Psyduck, Eevee

function App() {
  const [cards, setCards] = useState([]);
  const [flippedCards, setFlippedCards] = useState([]);
  const [matchedPairs, setMatchedPairs] = useState([]);
  const [score, setScore] = useState(0);
  const [tries, setTries] = useState(0);
  const [gameOver, setGameOver] = useState(false);
  const [playerName, setPlayerName] = useState('');
  const [showNameInput, setShowNameInput] = useState(false);
  const [leaderboard, setLeaderboard] = useState([]);
  const [showLeaderboard, setShowLeaderboard] = useState(false);

  // Initialize game
  useEffect(() => {
    initializeGame();
    fetchLeaderboard();
  }, []);

  const initializeGame = () => {
    // Create pairs of Pokemon cards
    const pokemonPairs = [...POKEMON_IDS, ...POKEMON_IDS];
    
    // Shuffle cards
    const shuffled = pokemonPairs
      .map((pokemon, index) => ({
        id: index,
        pokemonId: pokemon,
        image: `https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/${pokemon}.png`,
        isFlipped: false,
        isMatched: false,
      }))
      .sort(() => Math.random() - 0.5);

    setCards(shuffled);
    setFlippedCards([]);
    setMatchedPairs([]);
    setScore(0);
    setTries(0);
    setGameOver(false);
    setShowNameInput(false);
  };

  const fetchLeaderboard = async () => {
    try {
      const response = await axios.get(`${API_BASE_URL}/api/leaderboard`);
      setLeaderboard(response.data);
    } catch (error) {
      console.error('Error fetching leaderboard:', error);
    }
  };

  const handleCardClick = (cardId) => {
    const card = cards.find(c => c.id === cardId);
    
    // Ignore if card is already flipped, matched, or if 2 cards are already flipped
    if (
      card.isFlipped ||
      card.isMatched ||
      flippedCards.length === 2 ||
      matchedPairs.includes(card.pokemonId)
    ) {
      return;
    }

    const newFlippedCards = [...flippedCards, cardId];
    setFlippedCards(newFlippedCards);

    const updatedCards = cards.map(c =>
      c.id === cardId ? { ...c, isFlipped: true } : c
    );
    setCards(updatedCards);

    // Check for match when 2 cards are flipped
    if (newFlippedCards.length === 2) {
      const [firstCardId, secondCardId] = newFlippedCards;
      const firstCard = cards.find(c => c.id === firstCardId);
      const secondCard = updatedCards.find(c => c.id === secondCardId);

      setTries(tries + 1);

      if (firstCard.pokemonId === secondCard.pokemonId) {
        // Match found!
        const newMatchedPairs = [...matchedPairs, firstCard.pokemonId];
        setMatchedPairs(newMatchedPairs);
        setScore(score + 10);
        
        // Mark cards as matched
        setTimeout(() => {
          const matchedCards = updatedCards.map(c =>
            c.pokemonId === firstCard.pokemonId
              ? { ...c, isMatched: true, isFlipped: true }
              : c
          );
          setCards(matchedCards);
          setFlippedCards([]);
          
          // Check if game is over (all pairs matched)
          if (newMatchedPairs.length === POKEMON_IDS.length) {
            setGameOver(true);
            setShowNameInput(true);
          }
        }, 500);
      } else {
        // No match - flip cards back
        setTimeout(() => {
          const resetCards = updatedCards.map(c =>
            newFlippedCards.includes(c.id)
              ? { ...c, isFlipped: false }
              : c
          );
          setCards(resetCards);
          setFlippedCards([]);
        }, 1000);
      }
    }
  };

  const saveResult = async () => {
    if (!playerName.trim()) {
      alert('Please enter your name');
      return;
    }

    try {
      await axios.post(`${API_BASE_URL}/api/results`, {
        player_name: playerName,
        score,
        tries,
        matches: matchedPairs.length + 1,
      });
      alert('Result saved successfully!');
      setShowNameInput(false);
      fetchLeaderboard();
    } catch (error) {
      console.error('Error saving result:', error);
      alert('Error saving result. Please try again.');
    }
  };

  return (
    <div className="App">
      <div className="container">
        <h1>Pokemon Memory Game</h1>
        
        <div className="game-info">
          <div className="stat">
            <span className="stat-label">Score:</span>
            <span className="stat-value">{score}</span>
          </div>
          <div className="stat">
            <span className="stat-label">Tries:</span>
            <span className="stat-value">{tries}</span>
          </div>
          <div className="stat">
            <span className="stat-label">Matches:</span>
            <span className="stat-value">{matchedPairs.length}/{POKEMON_IDS.length}</span>
          </div>
        </div>

        {gameOver && (
          <div className="game-over">
            <h2>Congratulations! 🎉</h2>
            <p>You completed the game in {tries} tries!</p>
            {showNameInput && (
              <div className="name-input-container">
                <input
                  type="text"
                  placeholder="Enter your name"
                  value={playerName}
                  onChange={(e) => setPlayerName(e.target.value)}
                  className="name-input"
                  onKeyPress={(e) => e.key === 'Enter' && saveResult()}
                />
                <button onClick={saveResult} className="save-button">
                  Save Score
                </button>
              </div>
            )}
          </div>
        )}

        <div className="controls">
          <button onClick={initializeGame} className="btn btn-primary">
            New Game
          </button>
          <button
            onClick={() => setShowLeaderboard(!showLeaderboard)}
            className="btn btn-secondary"
          >
            {showLeaderboard ? 'Hide' : 'Show'} Leaderboard
          </button>
        </div>

        {showLeaderboard && (
          <div className="leaderboard">
            <h2>Top 10 Scores</h2>
            <table>
              <thead>
                <tr>
                  <th>Rank</th>
                  <th>Player</th>
                  <th>Score</th>
                  <th>Tries</th>
                  <th>Matches</th>
                </tr>
              </thead>
              <tbody>
                {leaderboard.length === 0 ? (
                  <tr>
                    <td colSpan="5">No scores yet</td>
                  </tr>
                ) : (
                  leaderboard.map((entry, index) => (
                    <tr key={entry.id}>
                      <td>{index + 1}</td>
                      <td>{entry.player_name}</td>
                      <td>{entry.score}</td>
                      <td>{entry.tries}</td>
                      <td>{entry.matches}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        )}

        <div className="game-board">
          {cards.map((card) => (
            <div
              key={card.id}
              className={`card ${card.isFlipped ? 'flipped' : ''} ${
                card.isMatched ? 'matched' : ''
              }`}
              onClick={() => handleCardClick(card.id)}
            >
              <div className="card-inner">
                <div className="card-front">
                  <div className="pokeball">⚪</div>
                </div>
                <div className="card-back">
                  <img src={card.image} alt={`Pokemon ${card.pokemonId}`} />
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

export default App;

