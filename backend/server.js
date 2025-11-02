const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(express.json());

// Initialize database
const dbPath = path.join(__dirname, 'memory_game.db');
const db = new sqlite3.Database(dbPath, (err) => {
  if (err) {
    console.error('Error opening database:', err.message);
  } else {
    console.log('Connected to SQLite database');
    // Create tables if they don't exist
    db.run(`CREATE TABLE IF NOT EXISTS game_results (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      player_name TEXT,
      score INTEGER,
      tries INTEGER,
      matches INTEGER,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )`, (err) => {
      if (err) {
        console.error('Error creating table:', err.message);
      } else {
        console.log('Database tables initialized');
      }
    });
  }
});

// Get all game results
app.get('/api/results', (req, res) => {
  db.all('SELECT * FROM game_results ORDER BY created_at DESC LIMIT 50', (err, rows) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    res.json(rows);
  });
});

// Save game result
app.post('/api/results', (req, res) => {
  const { player_name, score, tries, matches } = req.body;
  
  if (!player_name || score === undefined || tries === undefined || matches === undefined) {
    res.status(400).json({ error: 'Missing required fields' });
    return;
  }

  db.run(
    'INSERT INTO game_results (player_name, score, tries, matches) VALUES (?, ?, ?, ?)',
    [player_name || 'Anonymous', score, tries, matches],
    function(err) {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      res.json({
        id: this.lastID,
        player_name: player_name || 'Anonymous',
        score,
        tries,
        matches,
        message: 'Result saved successfully'
      });
    }
  );
});

// Get leaderboard (top scores)
app.get('/api/leaderboard', (req, res) => {
  db.all(
    'SELECT * FROM game_results ORDER BY score DESC, tries ASC LIMIT 10',
    (err, rows) => {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }
      res.json(rows);
    }
  );
});

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});

