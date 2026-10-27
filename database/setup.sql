
-- =====================================================
-- LMS DBMS PROJECT
-- File: database/setup.sql
-- Purpose: Create LMS tables and sample data
-- =====================================================

CREATE DATABASE IF NOT EXISTS lms_db;
USE lms_db;

-- 1. USERS
CREATE TABLE IF NOT EXISTS Users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('student', 'instructor', 'admin') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. STUDENTS
CREATE TABLE IF NOT EXISTS Students (
    student_id INT PRIMARY KEY,
    roll_no VARCHAR(30) NOT NULL UNIQUE,
    department VARCHAR(100),
    semester TINYINT,
    FOREIGN KEY (student_id)
        REFERENCES Users(user_id)
        ON DELETE CASCADE
);

-- 3. INSTRUCTORS
CREATE TABLE IF NOT EXISTS Instructors (
    instructor_id INT PRIMARY KEY,
    department VARCHAR(100),
    designation VARCHAR(100),
    FOREIGN KEY (instructor_id)
        REFERENCES Users(user_id)
        ON DELETE CASCADE
);

-- 4. COURSES
CREATE TABLE IF NOT EXISTS Courses (
    course_id INT AUTO_INCREMENT PRIMARY KEY,
    course_code VARCHAR(20) NOT NULL UNIQUE,
    title VARCHAR(150) NOT NULL,
    description TEXT,
    instructor_id INT NOT NULL,
    credits TINYINT NOT NULL DEFAULT 3,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (instructor_id)
        REFERENCES Instructors(instructor_id)
);

-- 5. ENROLLMENTS
CREATE TABLE IF NOT EXISTS Enrollments (
    enrollment_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    course_id INT NOT NULL,
    enrolled_on DATE NOT NULL,
    status ENUM('active', 'completed', 'dropped')
        NOT NULL DEFAULT 'active',
    UNIQUE (student_id, course_id),
    FOREIGN KEY (student_id)
        REFERENCES Students(student_id),
    FOREIGN KEY (course_id)
        REFERENCES Courses(course_id)
);

-- 6. ASSIGNMENTS
CREATE TABLE IF NOT EXISTS Assignments (
    assignment_id INT AUTO_INCREMENT PRIMARY KEY,
    course_id INT NOT NULL,
    title VARCHAR(150) NOT NULL,
    description TEXT,
    due_date DATETIME,
    max_marks DECIMAL(6,2) NOT NULL DEFAULT 100,
    FOREIGN KEY (course_id)
        REFERENCES Courses(course_id)
);

-- 7. SUBMISSIONS
CREATE TABLE IF NOT EXISTS Submissions (
    submission_id INT AUTO_INCREMENT PRIMARY KEY,
    assignment_id INT NOT NULL,
    student_id INT NOT NULL,
    submitted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    file_url VARCHAR(500),
    remarks TEXT,
    marks_obtained DECIMAL(6,2),
    status ENUM('submitted', 'graded', 'late')
        NOT NULL DEFAULT 'submitted',
    UNIQUE (assignment_id, student_id),
    FOREIGN KEY (assignment_id)
        REFERENCES Assignments(assignment_id),
    FOREIGN KEY (student_id)
        REFERENCES Students(student_id)
);

-- 8. LEARNING MATERIALS
CREATE TABLE IF NOT EXISTS LearningMaterials (
    material_id INT AUTO_INCREMENT PRIMARY KEY,
    course_id INT NOT NULL,
    title VARCHAR(150) NOT NULL,
    material_type ENUM('pdf', 'video', 'link', 'document', 'other')
        NOT NULL DEFAULT 'other',
    file_url VARCHAR(500) NOT NULL,
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    uploaded_by INT NOT NULL,
    FOREIGN KEY (course_id)
        REFERENCES Courses(course_id),
    FOREIGN KEY (uploaded_by)
        REFERENCES Instructors(instructor_id)
);

-- =====================================================
-- SAMPLE DATA
-- These accounts are for database testing only.
-- Replace placeholder password hashes before authentication.
-- =====================================================

INSERT IGNORE INTO Users
    (user_id, full_name, email, password_hash, role)
VALUES
    (1, 'Aarav Sharma', 'aarav@example.com',
     'REPLACE_WITH_REAL_PASSWORD_HASH', 'student'),
    (2, 'Priya Patil', 'priya@example.com',
     'REPLACE_WITH_REAL_PASSWORD_HASH', 'student'),
    (3, 'Dr. Meera Shah', 'meera@example.com',
     'REPLACE_WITH_REAL_PASSWORD_HASH', 'instructor'),
    (4, 'Prof. Rahul Desai', 'rahul@example.com',
     'REPLACE_WITH_REAL_PASSWORD_HASH', 'instructor');

INSERT IGNORE INTO Students
    (student_id, roll_no, department, semester)
VALUES
    (1, 'CSE24001', 'Computer Science', 5),
    (2, 'CSE24002', 'Computer Science', 5);

INSERT IGNORE INTO Instructors
    (instructor_id, department, designation)
VALUES
    (3, 'Computer Science', 'Associate Professor'),
    (4, 'Computer Science', 'Assistant Professor');

INSERT IGNORE INTO Courses
    (course_id, course_code, title, description, instructor_id, credits)
VALUES
    (1, 'DBMS301', 'Database Management Systems',
     'Relational databases, SQL and database design.', 3, 4),
    (2, 'PY101', 'Python Programming',
     'Programming fundamentals using Python.', 4, 3);

INSERT IGNORE INTO Enrollments
    (enrollment_id, student_id, course_id, enrolled_on, status)
VALUES
    (1, 1, 1, '2026-08-01', 'active'),
    (2, 1, 2, '2026-08-01', 'active'),
    (3, 2, 1, '2026-08-02', 'active');

INSERT IGNORE INTO Assignments
    (assignment_id, course_id, title, description, due_date, max_marks)
VALUES
    (1, 1, 'ER Diagram Assignment',
     'Design an ER diagram for a library system.',
     '2026-11-15 23:59:00', 100),
    (2, 2, 'Python Basics',
     'Write programs using functions and lists.',
     '2026-11-20 23:59:00', 50);

INSERT IGNORE INTO Submissions
    (submission_id, assignment_id, student_id, file_url,
     remarks, marks_obtained, status)
VALUES
    (1, 1, 1, 'uploads/er_diagram.pdf',
     'Initial sample submission', NULL, 'submitted'),
    (2, 2, 2, 'uploads/python_basics.py',
     'Sample graded submission', 42, 'graded');

INSERT IGNORE INTO LearningMaterials
    (material_id, course_id, title, material_type, file_url, uploaded_by)
VALUES
    (1, 1, 'Introduction to DBMS', 'pdf',
     'materials/dbms_intro.pdf', 3),
    (2, 2, 'Python Getting Started', 'link',
     'https://docs.python.org/3/tutorial/', 4);

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

SHOW TABLES;

SELECT * FROM Users;
SELECT * FROM Students;
SELECT * FROM Instructors;
SELECT * FROM Courses;
SELECT * FROM Enrollments;
SELECT * FROM Assignments;
SELECT * FROM Submissions;
SELECT * FROM LearningMaterials;
