-- LMS DBMS PROJECT: Compact Basic + Advanced SQL Demo
-- Target: MySQL 8.4 (also suitable for recent MySQL 8.0 releases)
-- Run the whole file in MySQL Workbench.
-- It creates a separate database and does not modify the old lms_db.

CREATE DATABASE IF NOT EXISTS lms_complete_db;
USE lms_complete_db;

-- 1. TABLES: data types, primary keys, foreign keys, constraints
CREATE TABLE IF NOT EXISTS Users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    role ENUM('student', 'instructor', 'admin') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS Students (
    student_id INT PRIMARY KEY,
    department VARCHAR(80) NOT NULL,
    year_of_study TINYINT NOT NULL,
    CONSTRAINT chk_student_year CHECK (year_of_study BETWEEN 1 AND 4),
    CONSTRAINT fk_student_user FOREIGN KEY (student_id)
        REFERENCES Users(user_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Instructors (
    instructor_id INT PRIMARY KEY,
    department VARCHAR(80) NOT NULL,
    CONSTRAINT fk_instructor_user FOREIGN KEY (instructor_id)
        REFERENCES Users(user_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Courses (
    course_id INT AUTO_INCREMENT PRIMARY KEY,
    course_name VARCHAR(120) NOT NULL,
    course_code VARCHAR(15) NOT NULL UNIQUE,
    instructor_id INT NULL,
    credits TINYINT NOT NULL DEFAULT 3,
    CONSTRAINT chk_course_credits CHECK (credits BETWEEN 1 AND 6),
    CONSTRAINT fk_course_instructor FOREIGN KEY (instructor_id)
        REFERENCES Instructors(instructor_id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS Enrollments (
    enrollment_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    course_id INT NOT NULL,
    status ENUM('enrolled', 'completed', 'dropped') NOT NULL DEFAULT 'enrolled',
    grade DECIMAL(5,2) NULL,
    CONSTRAINT chk_enrollment_grade CHECK (grade IS NULL OR grade BETWEEN 0 AND 100),
    CONSTRAINT uq_student_course UNIQUE (student_id, course_id),
    CONSTRAINT fk_enrollment_student FOREIGN KEY (student_id)
        REFERENCES Students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_enrollment_course FOREIGN KEY (course_id)
        REFERENCES Courses(course_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Assignments (
    assignment_id INT AUTO_INCREMENT PRIMARY KEY,
    course_id INT NOT NULL,
    title VARCHAR(150) NOT NULL,
    max_marks DECIMAL(6,2) NOT NULL DEFAULT 100,
    due_date DATE NOT NULL,
    CONSTRAINT chk_assignment_marks CHECK (max_marks > 0),
    CONSTRAINT fk_assignment_course FOREIGN KEY (course_id)
        REFERENCES Courses(course_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS Submissions (
    submission_id INT AUTO_INCREMENT PRIMARY KEY,
    assignment_id INT NOT NULL,
    student_id INT NOT NULL,
    marks_obtained DECIMAL(6,2) NULL,
    submitted_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    feedback VARCHAR(300),
    CONSTRAINT uq_assignment_student UNIQUE (assignment_id, student_id),
    CONSTRAINT chk_submission_marks CHECK (marks_obtained IS NULL OR marks_obtained >= 0),
    CONSTRAINT fk_submission_assignment FOREIGN KEY (assignment_id)
        REFERENCES Assignments(assignment_id) ON DELETE CASCADE,
    CONSTRAINT fk_submission_student FOREIGN KEY (student_id)
        REFERENCES Students(student_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS LearningMaterials (
    material_id INT AUTO_INCREMENT PRIMARY KEY,
    course_id INT NOT NULL,
    title VARCHAR(150) NOT NULL,
    material_type ENUM('PDF', 'VIDEO', 'LINK', 'NOTES') NOT NULL,
    material_url VARCHAR(300),
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_material_course FOREIGN KEY (course_id)
        REFERENCES Courses(course_id) ON DELETE CASCADE
);

-- 2. SAMPLE DATA
-- Explicit column lists avoid column-count errors if a table has extra columns.
INSERT IGNORE INTO Users (user_id, full_name, email, role) VALUES
(1, 'Aarav Shah', 'aarav@example.com', 'student'),
(2, 'Diya Patil', 'diya@example.com', 'student'),
(3, 'Meera Kulkarni', 'meera@example.com', 'instructor'),
(4, 'LMS Admin', 'admin@example.com', 'admin');

INSERT IGNORE INTO Students (student_id, department, year_of_study) VALUES
(1, 'Computer Science', 2),
(2, 'Computer Science', 3);

INSERT IGNORE INTO Instructors (instructor_id, department) VALUES
(3, 'Computer Science');

INSERT IGNORE INTO Courses (course_id, course_name, course_code, instructor_id, credits) VALUES
(1, 'Database Management Systems', 'CS201', 3, 4),
(2, 'Data Structures', 'CS202', 3, 3);

INSERT IGNORE INTO Enrollments (enrollment_id, student_id, course_id, status, grade) VALUES
(1, 1, 1, 'completed', 88),
(2, 1, 2, 'enrolled', NULL),
(3, 2, 1, 'completed', 76);

INSERT IGNORE INTO Assignments (assignment_id, course_id, title, max_marks, due_date) VALUES
(1, 1, 'SQL Basics', 100, '2026-11-05'),
(2, 2, 'Data Structures Exercise', 50, '2026-11-10');

INSERT IGNORE INTO Submissions (submission_id, assignment_id, student_id, marks_obtained, feedback) VALUES
(1, 1, 1, 92, 'Good work'),
(2, 1, 2, 81, 'Well done');

INSERT IGNORE INTO LearningMaterials
    (material_id, course_id, title, material_type, material_url) VALUES
(1, 1, 'SQL Notes', 'PDF', 'https://example.com/sql-notes'),
(2, 2, 'DSA Video', 'VIDEO', 'https://example.com/dsa-video');

-- 3. BASIC QUERIES: WHERE, DISTINCT, LIKE, BETWEEN, ORDER BY, aliases
SELECT full_name AS student_name
FROM Users
WHERE role = 'student'
ORDER BY full_name;

SELECT DISTINCT department FROM Students;
SELECT course_name, credits FROM Courses WHERE credits BETWEEN 3 AND 4;
SELECT title FROM LearningMaterials WHERE title LIKE '%Notes%';
SELECT course_name, credits, credits * 2 AS credit_points FROM Courses;
SELECT course_name FROM Courses WHERE credits >= 3 AND course_code LIKE 'CS%';

-- 4. AGGREGATE FUNCTIONS, GROUP BY, HAVING and NULL handling
SELECT COUNT(*) AS course_count FROM Courses;

SELECT AVG(grade) AS average_grade, MIN(grade) AS lowest_grade, MAX(grade) AS highest_grade
FROM Enrollments
WHERE grade IS NOT NULL;

SELECT c.course_name, COUNT(e.student_id) AS enrolled_count, AVG(e.grade) AS average_grade
FROM Courses c
LEFT JOIN Enrollments e ON c.course_id = e.course_id
GROUP BY c.course_id, c.course_name
HAVING COUNT(e.student_id) > 0;

SELECT status, COUNT(*) AS total FROM Enrollments GROUP BY status;
SELECT student_id, course_id FROM Enrollments WHERE grade IS NULL;
SELECT COALESCE(AVG(grade), 0) AS average_or_zero FROM Enrollments;

-- 5. JOINS: matching records and retaining unmatched courses
SELECT u.full_name, c.course_name, e.status, e.grade
FROM Enrollments e
JOIN Students s ON e.student_id = s.student_id
JOIN Users u ON s.student_id = u.user_id
JOIN Courses c ON e.course_id = c.course_id;

SELECT c.course_name, u.full_name AS instructor_name
FROM Courses c
LEFT JOIN Instructors i ON c.instructor_id = i.instructor_id
LEFT JOIN Users u ON i.instructor_id = u.user_id;

-- 6. SUBQUERIES: IN, EXISTS, NOT EXISTS and scalar subquery
SELECT course_name
FROM Courses c
WHERE EXISTS (
    SELECT 1 FROM Enrollments e WHERE e.course_id = c.course_id
);

SELECT u.full_name
FROM Users u
JOIN Students s ON u.user_id = s.student_id
WHERE NOT EXISTS (
    SELECT 1 FROM Submissions sub WHERE sub.student_id = s.student_id
);

SELECT full_name
FROM Users
WHERE user_id IN (SELECT student_id FROM Enrollments WHERE grade >= 80);

SELECT course_name, credits
FROM Courses
WHERE credits > (SELECT AVG(credits) FROM Courses);

-- 7. SET OPERATIONS (INTERSECT and EXCEPT require MySQL 8.0.31+)
SELECT user_id FROM Users WHERE role = 'student'
UNION
SELECT user_id FROM Users WHERE role = 'instructor';

SELECT student_id FROM Enrollments
INTERSECT
SELECT student_id FROM Submissions;

SELECT student_id FROM Enrollments
EXCEPT
SELECT student_id FROM Submissions;

-- 8. VIEW: a saved SELECT query
CREATE OR REPLACE VIEW StudentCourseDetails AS
SELECT u.full_name, c.course_name, e.status, e.grade
FROM Users u
JOIN Students s ON u.user_id = s.student_id
JOIN Enrollments e ON s.student_id = e.student_id
JOIN Courses c ON e.course_id = c.course_id;

SELECT * FROM StudentCourseDetails;
SELECT full_name, course_name
FROM StudentCourseDetails
WHERE status = 'completed';

-- 9. TRANSACTIONS and data modification
START TRANSACTION;
UPDATE Enrollments SET grade = 99 WHERE enrollment_id = 1;
ROLLBACK;

-- Temporary CRUD example; transaction is rolled back, leaving no extra user.
START TRANSACTION;
INSERT INTO Users (full_name, email, role)
VALUES ('Temporary Demo User', 'temporary.demo@example.com', 'student');
SET @temp_user_id = LAST_INSERT_ID();
UPDATE Users SET full_name = 'Updated Demo User' WHERE user_id = @temp_user_id;
DELETE FROM Users WHERE user_id = @temp_user_id;
ROLLBACK;

-- 10. STORED PROCEDURE: reusable query with an input parameter
DROP PROCEDURE IF EXISTS GetStudentCourses;
DELIMITER //
CREATE PROCEDURE GetStudentCourses(IN p_student_id INT)
BEGIN
    SELECT c.course_name, e.status, e.grade
    FROM Enrollments e
    JOIN Courses c ON e.course_id = c.course_id
    WHERE e.student_id = p_student_id;
END //
DELIMITER ;

CALL GetStudentCourses(1);

-- 11. TRIGGER: prevent marks exceeding the assignment maximum
DROP TRIGGER IF EXISTS CheckSubmissionMarks;
DELIMITER //
CREATE TRIGGER CheckSubmissionMarks
BEFORE INSERT ON Submissions
FOR EACH ROW
BEGIN
    DECLARE v_max_marks DECIMAL(6,2);
    SELECT max_marks INTO v_max_marks
    FROM Assignments
    WHERE assignment_id = NEW.assignment_id;

    IF NEW.marks_obtained IS NOT NULL AND NEW.marks_obtained > v_max_marks THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Marks exceed assignment maximum';
    END IF;
END //
DELIMITER ;

-- 12. RECURSIVE CTE, CASE, string and date functions
WITH RECURSIVE Numbers(n) AS (
    SELECT 1
    UNION ALL
    SELECT n + 1 FROM Numbers WHERE n < 5
)
SELECT n FROM Numbers;

SELECT student_id, course_id, grade,
    CASE
        WHEN grade IS NULL THEN 'Not graded'
        WHEN grade >= 85 THEN 'Excellent'
        WHEN grade >= 60 THEN 'Pass'
        ELSE 'Needs improvement'
    END AS grade_status
FROM Enrollments;

SELECT UPPER(course_name) AS course_name_upper, CHAR_LENGTH(course_name) AS name_length
FROM Courses;

SELECT title, due_date, DATEDIFF(due_date, CURRENT_DATE) AS days_until_due
FROM Assignments
ORDER BY due_date;

-- 13. FINAL VERIFICATION
SHOW TABLES;

SELECT 'Users' AS table_name, COUNT(*) AS row_count FROM Users
UNION ALL SELECT 'Students', COUNT(*) FROM Students
UNION ALL SELECT 'Instructors', COUNT(*) FROM Instructors
UNION ALL SELECT 'Courses', COUNT(*) FROM Courses
UNION ALL SELECT 'Enrollments', COUNT(*) FROM Enrollments
UNION ALL SELECT 'Assignments', COUNT(*) FROM Assignments
UNION ALL SELECT 'Submissions', COUNT(*) FROM Submissions
UNION ALL SELECT 'LearningMaterials', COUNT(*) FROM LearningMaterials;