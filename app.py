import os
from functools import wraps
from datetime import datetime
import mysql.connector
from mysql.connector import Error
from dotenv import load_dotenv
from flask import Flask, render_template, request, redirect, url_for, session, flash, abort
from werkzeug.security import generate_password_hash, check_password_hash

load_dotenv()
app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY", "development-key-change-me")


def get_db():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        database=os.getenv("DB_NAME", "lms_db")
    )


def fetch_all(sql, params=()):
    conn = get_db()
    cur = conn.cursor(dictionary=True)
    try:
        cur.execute(sql, params)
        return cur.fetchall()
    finally:
        cur.close()
        conn.close()


def fetch_one(sql, params=()):
    rows = fetch_all(sql, params)
    return rows[0] if rows else None


def execute(sql, params=()):
    conn = get_db()
    cur = conn.cursor()
    try:
        cur.execute(sql, params)
        conn.commit()
        return cur.lastrowid
    finally:
        cur.close()
        conn.close()


def login_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        if not session.get("user_id"):
            flash("Please log in to continue.", "warning")
            return redirect(url_for("login"))
        return fn(*args, **kwargs)
    return wrapper


def roles_required(*roles):
    def decorator(fn):
        @wraps(fn)
        @login_required
        def wrapper(*args, **kwargs):
            if session.get("role") not in roles:
                abort(403)
            return fn(*args, **kwargs)
        return wrapper
    return decorator


def instructor_owns(course_id):
    return fetch_one(
        "SELECT course_id FROM Courses WHERE course_id=%s AND instructor_id=%s",
        (course_id, session["user_id"])
    ) is not None


@app.route("/")
def home():
    courses = fetch_all("""
        SELECT c.course_id,c.course_code,c.title,c.description,c.credits,
               u.full_name AS instructor_name
        FROM Courses c
        LEFT JOIN Instructors i ON c.instructor_id=i.instructor_id
        LEFT JOIN Users u ON i.instructor_id=u.user_id
        ORDER BY c.course_id DESC
    """)
    return render_template("home.html", courses=courses)


@app.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "POST":
        name=request.form.get("full_name","").strip()
        email=request.form.get("email","").strip().lower()
        password=request.form.get("password","")
        role=request.form.get("role","student")
        department=request.form.get("department","Computer Science").strip() or "Computer Science"
        if role not in ("student","instructor"):
            role="student"
        if not name or not email or len(password)<8:
            flash("Enter your name, email, and a password of at least 8 characters.", "error")
            return render_template("register.html")
        conn=get_db()
        cur=conn.cursor()
        try:
            cur.execute("INSERT INTO Users (full_name,email,password_hash,role) VALUES (%s,%s,%s,%s)",
                        (name,email,generate_password_hash(password),role))
            uid=cur.lastrowid
            if role=="student":
                roll="STU"+str(uid).zfill(5)
                cur.execute("INSERT INTO Students (student_id,roll_no,department,semester) VALUES (%s,%s,%s,%s)",
                            (uid,roll,department,1))
            else:
                cur.execute("INSERT INTO Instructors (instructor_id,department,designation) VALUES (%s,%s,%s)",
                            (uid,department,"Instructor"))
            conn.commit()
            flash("Account created. Please log in.", "success")
            return redirect(url_for("login"))
        except Error as e:
            conn.rollback()
            if getattr(e,"errno",None)==1062:
                flash("This email is already registered.", "error")
            else:
                app.logger.exception("Registration error")
                flash("Could not create account. Check your database setup.", "error")
        finally:
            cur.close()
            conn.close()
    return render_template("register.html")


@app.route("/login", methods=["GET","POST"])
def login():
    if request.method=="POST":
        email=request.form.get("email","").strip().lower()
        password=request.form.get("password","")
        user=fetch_one("SELECT * FROM Users WHERE email=%s",(email,))
        if user and check_password_hash(user["password_hash"],password):
            session.clear()
            session["user_id"]=user["user_id"]
            session["name"]=user["full_name"]
            session["role"]=user["role"]
            return redirect(url_for("dashboard"))
        flash("Incorrect email or password.", "error")
    return render_template("login.html")


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("home"))


@app.route("/dashboard")
@login_required
def dashboard():
    role=session["role"]
    uid=session["user_id"]
    if role=="student":
        courses=fetch_all("""
            SELECT c.course_id,c.course_code,c.title,e.status,e.grade,u.full_name AS instructor_name
            FROM Enrollments e JOIN Courses c ON e.course_id=c.course_id
            LEFT JOIN Instructors i ON c.instructor_id=i.instructor_id
            LEFT JOIN Users u ON i.instructor_id=u.user_id
            WHERE e.student_id=%s ORDER BY c.title
        """,(uid,))
        assignments=fetch_all("""
            SELECT a.assignment_id,a.title,a.due_date,a.max_marks,c.title AS course_title,
                   s.status AS submission_status,s.marks_obtained
            FROM Assignments a JOIN Courses c ON a.course_id=c.course_id
            JOIN Enrollments e ON e.course_id=c.course_id AND e.student_id=%s
            LEFT JOIN Submissions s ON s.assignment_id=a.assignment_id AND s.student_id=%s
            ORDER BY a.due_date
        """,(uid,uid))
        return render_template("student_dashboard.html",courses=courses,assignments=assignments)
    if role=="instructor":
        courses=fetch_all("""
            SELECT c.course_id,c.course_code,c.title,c.credits,
                   (SELECT COUNT(*) FROM Enrollments e WHERE e.course_id=c.course_id) AS student_count
            FROM Courses c WHERE c.instructor_id=%s ORDER BY c.title
        """,(uid,))
        return render_template("instructor_dashboard.html",courses=courses)
    return render_template("admin_dashboard.html",
        users=fetch_all("SELECT user_id,full_name,email,role FROM Users ORDER BY user_id"),
        course_count=fetch_one("SELECT COUNT(*) AS n FROM Courses")["n"])


@app.route("/courses")
@login_required
def courses():
    search=request.args.get("q","").strip()
    pattern="%"+search+"%"
    rows=fetch_all("""
        SELECT c.course_id,c.course_code,c.title,c.description,c.credits,
               u.full_name AS instructor_name
        FROM Courses c
        LEFT JOIN Instructors i ON c.instructor_id=i.instructor_id
        LEFT JOIN Users u ON i.instructor_id=u.user_id
        WHERE c.title LIKE %s OR c.course_code LIKE %s
        ORDER BY c.title
    """,(pattern,pattern))
    enrolled=set()
    if session["role"]=="student":
        enrolled={r["course_id"] for r in fetch_all(
            "SELECT course_id FROM Enrollments WHERE student_id=%s",(session["user_id"],))}
    return render_template("courses.html",courses=rows,enrolled=enrolled,search=search)


@app.route("/courses/new",methods=["GET","POST"])
@roles_required("instructor","admin")
def new_course():
    if request.method=="POST":
        code=request.form.get("course_code","").strip().upper()
        title=request.form.get("title","").strip()
        description=request.form.get("description","").strip()
        try: credits=int(request.form.get("credits","3"))
        except ValueError: credits=0
        if not code or not title or not 1<=credits<=6:
            flash("Enter a course code, title, and credits from 1 to 6.","error")
        else:
            instructor_id=session["user_id"] if session["role"]=="instructor" else None
            if instructor_id is None:
                flash("Admin course creation is disabled in this simple version. Log in as an instructor.","warning")
            else:
                try:
                    execute("INSERT INTO Courses (course_code,title,description,instructor_id,credits) VALUES (%s,%s,%s,%s,%s)",
                            (code,title,description,instructor_id,credits))
                    flash("Course created successfully.","success")
                    return redirect(url_for("dashboard"))
                except Error as e:
                    flash("Could not create course. Check that the course code is unique.","error")
    return render_template("course_form.html")


@app.route("/courses/<int:course_id>/enroll",methods=["POST"])
@roles_required("student")
def enroll(course_id):
    try:
        execute("INSERT INTO Enrollments (student_id,course_id,enrolled_on,status) VALUES (%s,%s,%s,'active')",
                (session["user_id"],course_id,datetime.now().date()))
        flash("You have enrolled in the course.","success")
    except Error as e:
        if getattr(e,"errno",None)==1062:
            flash("You are already enrolled in this course.","warning")
        else:
            flash("Could not enroll. The course may not exist.","error")
    return redirect(url_for("courses"))


@app.route("/courses/<int:course_id>")
@login_required
def course_detail(course_id):
    course=fetch_one("""
        SELECT c.*,u.full_name AS instructor_name FROM Courses c
        LEFT JOIN Instructors i ON c.instructor_id=i.instructor_id
        LEFT JOIN Users u ON i.instructor_id=u.user_id WHERE c.course_id=%s
    """,(course_id,))
    if not course: abort(404)
    assignments=fetch_all("SELECT * FROM Assignments WHERE course_id=%s ORDER BY due_date",(course_id,))
    materials=fetch_all("SELECT * FROM LearningMaterials WHERE course_id=%s ORDER BY title",(course_id,))
    is_enrolled=False
    if session["role"]=="student":
        is_enrolled=fetch_one("SELECT enrollment_id FROM Enrollments WHERE student_id=%s AND course_id=%s",
                              (session["user_id"],course_id)) is not None
    can_manage=session["role"]=="admin" or (session["role"]=="instructor" and course["instructor_id"]==session["user_id"])
    return render_template("course_detail.html",course=course,assignments=assignments,materials=materials,
                           is_enrolled=is_enrolled,can_manage=can_manage)


@app.route("/courses/<int:course_id>/assignments/new",methods=["POST"])
@roles_required("instructor")
def new_assignment(course_id):
    if not instructor_owns(course_id): abort(403)
    title=request.form.get("title","").strip()
    due=request.form.get("due_date","")
    description=request.form.get("description","").strip()
    try: max_marks=float(request.form.get("max_marks","100"))
    except ValueError: max_marks=0
    if not title or not due or max_marks<=0:
        flash("Enter a title, due date, and positive maximum marks.","error")
    else:
        try:
            execute("INSERT INTO Assignments (course_id,title,description,due_date,max_marks) VALUES (%s,%s,%s,%s,%s)",
                    (course_id,title,description,due,max_marks))
            flash("Assignment added.","success")
        except Error:
            flash("Could not add assignment.","error")
    return redirect(url_for("course_detail",course_id=course_id))


@app.route("/assignments/<int:assignment_id>",methods=["GET","POST"])
@roles_required("student","instructor","admin")
def assignment_detail(assignment_id):
    a=fetch_one("""
        SELECT a.*,c.title AS course_title,c.instructor_id
        FROM Assignments a JOIN Courses c ON a.course_id=c.course_id
        WHERE a.assignment_id=%s
    """,(assignment_id,))
    if not a: abort(404)
    role=session["role"]; uid=session["user_id"]
    can_manage=role=="admin" or (role=="instructor" and a["instructor_id"]==uid)
    if role=="instructor" and not can_manage: abort(403)
    if role=="student":
        enrolled=fetch_one("SELECT enrollment_id FROM Enrollments WHERE student_id=%s AND course_id=(SELECT course_id FROM Assignments WHERE assignment_id=%s)",
                           (uid,assignment_id))
        if not enrolled: abort(403)
    if request.method=="POST" and role=="student":
        file_url=request.form.get("file_url","").strip()
        remarks=request.form.get("remarks","").strip()
        if not file_url:
            flash("Enter a submission link or file path.","error")
        else:
            try:
                execute("""INSERT INTO Submissions (assignment_id,student_id,file_url,remarks,status)
                    VALUES (%s,%s,%s,%s,'submitted')
                    ON DUPLICATE KEY UPDATE file_url=VALUES(file_url),remarks=VALUES(remarks),
                    submitted_at=CURRENT_TIMESTAMP,status='submitted'""",
                    (assignment_id,uid,file_url,remarks))
                flash("Submission saved.","success")
                return redirect(url_for("assignment_detail",assignment_id=assignment_id))
            except Error:
                flash("Could not submit assignment.","error")
    if can_manage:
        submissions=fetch_all("""
            SELECT s.*,u.full_name FROM Submissions s
            JOIN Users u ON u.user_id=s.student_id
            WHERE s.assignment_id=%s ORDER BY s.submitted_at DESC
        """,(assignment_id,))
        own=None
    else:
        submissions=[]
        own=fetch_one("SELECT * FROM Submissions WHERE assignment_id=%s AND student_id=%s",(assignment_id,uid))
    return render_template("assignment_detail.html",assignment=a,can_manage=can_manage,
                           submissions=submissions,own=own)


@app.route("/submissions/<int:submission_id>/grade",methods=["POST"])
@roles_required("instructor")
def grade_submission(submission_id):
    s=fetch_one("""SELECT s.submission_id,s.assignment_id,a.max_marks,c.instructor_id
        FROM Submissions s JOIN Assignments a ON s.assignment_id=a.assignment_id
        JOIN Courses c ON a.course_id=c.course_id WHERE s.submission_id=%s""",(submission_id,))
    if not s: abort(404)
    if s["instructor_id"]!=session["user_id"]: abort(403)
    try: marks=float(request.form.get("marks",""))
    except ValueError: marks=-1
    if marks<0 or marks>float(s["max_marks"]):
        flash("Marks must be between 0 and the assignment maximum.","error")
    else:
        feedback=request.form.get("feedback","").strip()
        execute("UPDATE Submissions SET marks_obtained=%s,remarks=%s,status='graded' WHERE submission_id=%s",
                (marks,feedback,submission_id))
        flash("Grade saved.","success")
    return redirect(url_for("assignment_detail",assignment_id=s["assignment_id"]))


@app.errorhandler(403)
def forbidden(_): return render_template("error.html",code=403,message="You do not have permission to view this page."),403

@app.errorhandler(404)
def missing(_): return render_template("error.html",code=404,message="The requested page was not found."),404


if __name__=="__main__":
    app.run(debug=True)
