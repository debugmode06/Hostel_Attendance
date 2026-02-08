#!/usr/bin/env pwsh

# Change to the project directory
cd "C:\Users\mrmoh\OneDrive\Desktop\host"

# Configure git
git config --global user.email "debugmode06@github.com"
git config --global user.name "debugmode06"

# Check if git is initialized
if (-not (Test-Path ".git")) {
    Write-Host "Initializing git repository..." -ForegroundColor Green
    git init
}

# Check if remote exists
$remoteUrl = git config --get remote.origin.url 2>$null
if (-not $remoteUrl) {
    Write-Host "Adding remote origin..." -ForegroundColor Green
    git remote add origin https://github.com/debugmode06/Hostel_Attendance.git
} else {
    Write-Host "Remote origin already exists: $remoteUrl" -ForegroundColor Yellow
}

# Add all files
Write-Host "Staging all files..." -ForegroundColor Green
git add -A

# Show status
Write-Host "`nGit status:" -ForegroundColor Cyan
git status

# Commit
Write-Host "`nCreating commit..." -ForegroundColor Green
git commit -m "Initial commit: Hostel Face Attendance System - Backend and Frontend with image preprocessing and optimized matching"

# Push to GitHub
Write-Host "`nPushing to GitHub..." -ForegroundColor Green
git branch -M main 2>$null
git push -u origin main --force

Write-Host "`n✓ Push complete!" -ForegroundColor Green
