# Pokemon Memory Game

A fun memory card game featuring Gen 1 Pokemon! Match pairs of Pokemon cards to win.

## Features

- 4x4 grid of Pokemon cards (8 pairs)
- Flip cards to reveal Pokemon images
- Track score, tries, and matches
- Save game results to database
- View leaderboard with top scores
- Beautiful, responsive UI

## Tech Stack

- **Frontend**: React
- **Backend**: Node.js with Express
- **Database**: SQLite

## Setup Instructions

### Backend Setup

1. Navigate to the backend directory:
```bash
cd backend
```

2. Install dependencies:
```bash
npm install
```

3. Start the server:
```bash
npm start
```

The backend will run on `http://localhost:5000`

### Frontend Setup

1. Navigate to the frontend directory:
```bash
cd frontend
```

2. Install dependencies:
```bash
npm install
```

3. Start the React app:
```bash
npm start
```

The frontend will run on `http://localhost:3000`

## How to Play

1. Click on any card to flip it and reveal a Pokemon
2. Click on a second card to try and find a match
3. If the Pokemon match, they stay open and you earn points
4. If they don't match, the cards flip back
5. Complete all matches to win!
6. Enter your name and save your score to the leaderboard

## API Endpoints

- `GET /api/results` - Get all game results
- `POST /api/results` - Save a game result
- `GET /api/leaderboard` - Get top 10 scores

## Database Schema

The game results are stored in SQLite with the following schema:

- `id`: Primary key
- `player_name`: Player's name
- `score`: Final score
- `tries`: Number of attempts
- `matches`: Number of matched pairs
- `created_at`: Timestamp

