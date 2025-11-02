#!/bin/bash

# Start script for Pokemon Memory Game

echo "Starting Pokemon Memory Game..."
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is not installed. Please install Node.js first."
    exit 1
fi

# Start backend
echo "Starting backend server..."
cd backend
if [ ! -d "node_modules" ]; then
    echo "Installing backend dependencies..."
    npm install
fi

# Start backend in background
npm start &
BACKEND_PID=$!
echo "Backend started (PID: $BACKEND_PID)"
cd ..

# Wait a moment for backend to start
sleep 2

# Start frontend
echo ""
echo "Starting frontend..."
cd frontend
if [ ! -d "node_modules" ]; then
    echo "Installing frontend dependencies..."
    npm install
fi

echo ""
echo "Frontend will open in your browser at http://localhost:3000"
echo "Backend API is running at http://localhost:5000"
echo ""
echo "Press Ctrl+C to stop both servers"
echo ""

# Start frontend
npm start

# Cleanup on exit
trap "kill $BACKEND_PID 2> /dev/null" EXIT

