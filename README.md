<<<<<<< HEAD
# CampusLearn LMS — Flask + MySQL Connector

A simple DBMS project built using Python Flask, `mysql-connector-python`, HTML and CSS. It uses the schema from the provided LMS database ZIP (`database/setup.sql`).

## Features
- Student and instructor registration/login
- Password hashing
- Browse and search courses
- Student course enrollment
- Instructor creates courses and assignments
- Students submit assignment links
- Instructors grade submissions and provide feedback
- Admin overview page
- MySQL joins and basic SQL queries

## Requirements
- Python 3.10+
- MySQL 8.0+
- MySQL Workbench recommended

## Setup on Windows PowerShell
1. Extract the ZIP and open the folder in VS Code.
2. In MySQL Workbench, open `database/setup.sql` and execute it. It creates `lms_db` and sample data.
3. Create a virtual environment:
   ```powershell
   py -m venv .venv
   .\.venv\Scripts\Activate.ps1
   pip install -r requirements.txt
   ```
4. Copy the environment file:
   ```powershell
   Copy-Item .env.example .env
   ```
5. Edit `.env` with your MySQL username and password. Keep `DB_NAME=lms_db`.
6. Run:
   ```powershell
   python app.py
   ```
7. Open `http://127.0.0.1:5000`.

## Notes
- The sample users in `setup.sql` have placeholder password hashes, so they cannot log in. Register new accounts from the website.
- For real deployment, add CSRF protection, HTTPS, and disable Flask debug mode.
- Course material links are stored in the database; this starter app does not upload files.
- SQL operations use `%s` parameters with MySQL Connector.
=======
# LMS-dbms-project
>>>>>>> 60dec76fd989f17baceec324ca3b6b3892fbbb7e
